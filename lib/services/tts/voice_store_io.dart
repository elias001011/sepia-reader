import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart' show AccumulatorSink;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'voice_catalog.dart';
import 'voice_store_types.dart';

/// One file in a voice's repository.
@visibleForTesting
class RemoteFile {
  const RemoteFile({required this.path, required this.size, this.sha256});
  final String path;
  final int size;
  final String? sha256;
}

/// Downloads, stores and removes on-device voice models.
///
/// Files are fetched individually and streamed straight to disk, rather than
/// pulling the project's published `.tar.bz2`: decompressing bzip2 in Dart
/// runs at roughly 175 ms per megabyte (measured on a desktop, worse on a
/// phone), and it needs the archive *and* its expansion in memory at once —
/// which for a ~400 MB model is not a slow path, it is an impossible one.
/// Streaming per file costs neither, and it makes an interrupted install
/// resumable for free: anything already on disk at the right size is skipped.
class VoiceStore {
  VoiceStore({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  Directory? _rootCache;

  static const _manifestName = '.sepia-installed.json';
  static const _concurrency = 4;

  /// Neural voices need a real filesystem and native inference, neither of
  /// which the web build has: there the platform voice is the only engine.
  bool get isSupported => true;

  Future<Directory> _root() async {
    final cached = _rootCache;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final root = Directory('${base.path}/tts-voices');
    if (!root.existsSync()) root.createSync(recursive: true);
    _rootCache = root;
    return root;
  }

  String _slug(String repo) => repo.replaceAll('/', '__');

  /// Where a voice's files live. Voices that share a repository share this
  /// directory, so installing Kokoro once serves all of its speakers.
  Future<Directory> packDirectory(VoicePack pack) async =>
      Directory('${(await _root()).path}/${_slug(pack.repo)}');

  Future<bool> isInstalled(VoicePack pack) async {
    final dir = await packDirectory(pack);
    if (!File('${dir.path}/$_manifestName').existsSync()) return false;
    // The model file itself is what must really be there: a manifest left
    // behind by a half-deleted directory should not count as installed.
    final model = File('${dir.path}/${pack.modelFile}');
    return model.existsSync() && model.lengthSync() > 0;
  }

  Future<List<VoicePack>> installedPacks() async {
    final result = <VoicePack>[];
    for (final pack in voicePacks) {
      if (await isInstalled(pack)) result.add(pack);
    }
    return result;
  }

  /// Bytes a voice occupies on disk.
  Future<int> installedSize(VoicePack pack) async {
    final dir = await packDirectory(pack);
    if (!dir.existsSync()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) total += entity.lengthSync();
    }
    return total;
  }

  Future<void> remove(VoicePack pack) async {
    final dir = await packDirectory(pack);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  /// Lists a Hugging Face repository.
  @visibleForTesting
  Future<List<RemoteFile>> listRepository(String repo) async {
    final uri = Uri.parse(
      'https://huggingface.co/api/models/$repo/tree/main?recursive=true',
    );
    final response = await _client.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} listing $repo');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) throw const FormatException('unexpected listing');
    final files = <RemoteFile>[];
    for (final item in decoded) {
      if (item is! Map || item['type'] != 'file') continue;
      final path = item['path'] as String?;
      if (path == null || path.startsWith('.git')) continue;
      final lfs = item['lfs'];
      files.add(
        RemoteFile(
          path: path,
          size: (item['size'] as num?)?.toInt() ?? 0,
          sha256: lfs is Map ? lfs['oid'] as String? : null,
        ),
      );
    }
    return files;
  }

  /// Downloads everything a voice needs.
  ///
  /// [shouldCancel] is polled between files, so somebody who changes their
  /// mind partway through a 400 MB download is not stuck waiting for it.
  Future<void> install(
    VoicePack pack, {
    void Function(VoiceInstallProgress)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    final remote = await listRepository(pack.repo);
    final dir = await packDirectory(pack);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final bytesTotal = remote.fold<int>(0, (sum, file) => sum + file.size);
    var bytesDone = 0;
    var filesDone = 0;

    void report(String? current) => onProgress?.call(
      VoiceInstallProgress(
        filesDone: filesDone,
        filesTotal: remote.length,
        bytesDone: bytesDone,
        bytesTotal: bytesTotal,
        currentFile: current,
      ),
    );

    final pending = <RemoteFile>[];
    for (final file in remote) {
      final target = File('${dir.path}/${file.path}');
      if (target.existsSync() && target.lengthSync() == file.size) {
        bytesDone += file.size;
        filesDone++;
        continue;
      }
      pending.add(file);
    }
    report(null);
    if (shouldCancel?.call() ?? false) throw const VoiceInstallCancelled();

    // A handful in flight keeps the connection busy through the long tail of
    // small dictionary files without opening a dozen sockets at once.
    final queue = List<RemoteFile>.from(pending);
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        if (shouldCancel?.call() ?? false) throw const VoiceInstallCancelled();
        final file = queue.removeAt(0);
        report(file.path);
        await _downloadFile(pack.repo, file, dir);
        bytesDone += file.size;
        filesDone++;
        report(file.path);
      }
    }

    final workers = queue.isEmpty
        ? <Future<void>>[]
        : [
            for (var i = 0; i < _concurrency && i < queue.length; i++)
              worker(),
          ];
    await Future.wait(workers);

    if (shouldCancel?.call() ?? false) throw const VoiceInstallCancelled();
    // The manifest is written last and is what marks the install complete:
    // without it, a directory of half the files is correctly treated as not
    // installed rather than as a voice that mysteriously fails to load.
    File('${dir.path}/$_manifestName').writeAsStringSync(
      jsonEncode({
        'repo': pack.repo,
        'files': remote.length,
        'bytes': bytesTotal,
        'installedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<void> _downloadFile(
    String repo,
    RemoteFile file,
    Directory dir,
  ) async {
    final uri = Uri.parse(
      'https://huggingface.co/$repo/resolve/main/${Uri.encodeFull(file.path)}',
    );
    final target = File('${dir.path}/${file.path}');
    target.parent.createSync(recursive: true);
    // Written to a neighbouring temp name first, so an interrupted download
    // never leaves a short file that the size check would accept next time.
    final temp = File('${target.path}.part');

    final response = await _client
        .send(http.Request('GET', uri))
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} fetching ${file.path}');
    }
    final sink = temp.openWrite();
    final collector = file.sha256 == null ? null : AccumulatorSink<Digest>();
    final hasher = collector == null
        ? null
        : sha256.startChunkedConversion(collector);
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        hasher?.add(chunk);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    void reject(String reason) {
      if (temp.existsSync()) temp.deleteSync();
      throw HttpException(reason);
    }

    if (hasher != null && collector != null) {
      hasher.close();
      final actual = collector.events.single.toString();
      if (actual != file.sha256) {
        reject('checksum mismatch for ${file.path}');
      }
    }
    if (file.size > 0 && temp.lengthSync() != file.size) {
      reject(
        'short read for ${file.path}: '
        '${temp.lengthSync()} of ${file.size} bytes',
      );
    }
    if (target.existsSync()) target.deleteSync();
    temp.renameSync(target.path);
  }
}
