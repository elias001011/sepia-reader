import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'voice_catalog.dart';
import 'voice_store.dart';

enum VoiceDownloadState { queued, running, failed }

/// One pack being fetched.
class VoiceDownloadJob {
  VoiceDownloadJob(this.pack);

  final VoicePack pack;
  VoiceDownloadState state = VoiceDownloadState.queued;
  VoiceInstallProgress? progress;
  String? error;
  bool cancelRequested = false;

  double get fraction => progress?.fraction ?? 0;
}

/// Owns every voice download in the app.
///
/// Lives above the screen that starts a download, for two reasons. Closing
/// the sheet used to take the install with it, which for a 400 MB model is
/// the difference between "leave it running" and "start over"; and starting
/// several at once used to have them race — worse than it sounds for Kokoro,
/// where every voice shares one repository, so two installs would have been
/// writing the same files.
///
/// Downloads run one at a time, in the order they were asked for. The rest
/// of the app watches this object rather than owning any of it.
class VoiceDownloadManager extends ChangeNotifier {
  VoiceDownloadManager({VoiceStore? store}) : store = store ?? VoiceStore();

  final VoiceStore store;
  final Map<String, VoiceDownloadJob> _jobs = {};
  final Queue<String> _queue = Queue();
  final Set<String> _installed = {};
  bool _draining = false;
  bool _loadedInstalled = false;

  bool get isSupported => store.isSupported;

  /// Jobs in flight or waiting, oldest first.
  List<VoiceDownloadJob> get jobs => [
    for (final id in [
      ..._jobs.keys.where((id) => _jobs[id]!.state == VoiceDownloadState.running),
      ..._queue,
      ..._jobs.keys.where((id) => _jobs[id]!.state == VoiceDownloadState.failed),
    ])
      ?_jobs[id],
  ];

  VoiceDownloadJob? jobFor(VoicePack pack) => _jobs[pack.id];

  bool isInstalled(VoicePack pack) => _installed.contains(pack.id);

  /// True once the installed set has actually been read from disk, so the
  /// interface can tell "nothing installed" from "not looked yet".
  bool get hasLoadedInstalled => _loadedInstalled;

  Future<void> refreshInstalled() async {
    if (!store.isSupported) {
      _loadedInstalled = true;
      notifyListeners();
      return;
    }
    final installed = await store.installedPacks();
    _installed
      ..clear()
      ..addAll(installed.map((pack) => pack.id));
    _loadedInstalled = true;
    notifyListeners();
  }

  /// Queues a pack. Asking twice is a no-op rather than a second download.
  void enqueue(VoicePack pack) {
    if (!store.isSupported || _installed.contains(pack.id)) return;
    final existing = _jobs[pack.id];
    if (existing != null && existing.state != VoiceDownloadState.failed) return;
    _jobs[pack.id] = VoiceDownloadJob(pack);
    _queue.addLast(pack.id);
    notifyListeners();
    unawaited(_drain());
  }

  /// Stops a download, whether it has started or is still waiting.
  void cancel(VoicePack pack) {
    final job = _jobs[pack.id];
    if (job == null) return;
    job.cancelRequested = true;
    if (job.state == VoiceDownloadState.queued) {
      _queue.remove(pack.id);
      _jobs.remove(pack.id);
    }
    notifyListeners();
  }

  /// Clears a failed job so its pack can be tried again.
  void dismiss(VoicePack pack) {
    final job = _jobs[pack.id];
    if (job == null || job.state != VoiceDownloadState.failed) return;
    _jobs.remove(pack.id);
    notifyListeners();
  }

  Future<void> remove(VoicePack pack) async {
    await store.remove(pack);
    _installed.remove(pack.id);
    notifyListeners();
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        final id = _queue.removeFirst();
        final job = _jobs[id];
        if (job == null || job.cancelRequested) continue;
        job.state = VoiceDownloadState.running;
        notifyListeners();
        try {
          await store.install(
            job.pack,
            onProgress: (progress) {
              job.progress = progress;
              notifyListeners();
            },
            shouldCancel: () => job.cancelRequested,
          );
          _installed.add(id);
          _jobs.remove(id);
        } on VoiceInstallCancelled {
          // A half-finished install is not a voice; take the files back.
          await store.remove(job.pack);
          _jobs.remove(id);
        } catch (error) {
          debugPrint('sepia: installing ${job.pack.id} failed: $error');
          job
            ..state = VoiceDownloadState.failed
            ..error = '$error';
        }
        notifyListeners();
      }
    } finally {
      _draining = false;
    }
  }
}
