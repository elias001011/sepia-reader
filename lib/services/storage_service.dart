import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/bookmark.dart';
import '../models/library_document.dart';
import '../models/library_folder.dart';
import '../models/syncable.dart';
import 'sync_merge.dart';

/// Locally-stored sync preferences.
///
/// Deliberately kept out of the synced settings payload: if the only copy
/// lived on the server, a settings response could disable a device's sync
/// (locking it out of ever syncing again) or silently repoint it at another
/// host. The local copy is always authoritative.
class SyncConfig {
  const SyncConfig({this.enabled = false, this.serverUrl = ''});
  final bool enabled;
  final String serverUrl;

  Map<String, dynamic> toJson() => {
    'syncEnabled': enabled,
    'syncServerUrl': serverUrl,
  };

  /// Defaults to off: a freshly installed copy of an open-source, local-first
  /// app should not assume a server exists. Devices that already stored a
  /// preference keep it, since the key is present in their saved payload.
  factory SyncConfig.fromJson(Map<String, dynamic> json) => SyncConfig(
    enabled: json['syncEnabled'] as bool? ?? false,
    serverUrl: json['syncServerUrl'] as String? ?? '',
  );
}

/// Outcome of an explicit "test connection" from the settings screen.
typedef SyncTestResult = ({bool ok, int documentCount, String? error});

class StorageService {
  StorageService({http.Client? client}) : _client = client ?? http.Client();

  static const _documentsKey = 'sepia.documents.v1';
  static const _settingsKey = 'sepia.settings.v1';
  static const _foldersKey = 'sepia.folders.v1';
  static const _bookmarksKey = 'sepia.bookmarks.v1';
  static const _syncConfigKey = 'sepia.syncconfig.v1';
  static const _lastSyncKey = 'sepia.lastsync.v1';

  static const _networkTimeout = Duration(seconds: 6);
  static const _mergeHeaders = {
    'Content-Type': 'application/json',
    'X-Sepia-Write-Mode': 'merge',
  };

  final http.Client _client;

  SyncConfig? _cachedSyncConfig;
  Future<void> _pendingPushes = Future.value();

  /// Counts GETs that actually came back from the server. [forcePull] resets
  /// it so a user-triggered sync can report whether the server was reached
  /// at all, instead of the spinner just stopping either way.
  int _serverResponses = 0;

  Future<SyncConfig> loadSyncConfig() async {
    final cached = _cachedSyncConfig;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_syncConfigKey);
    var config = const SyncConfig();
    if (raw != null) {
      try {
        config = SyncConfig.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {
        config = const SyncConfig();
      }
    } else {
      // `sepia.syncconfig.v1` was introduced after the sync preferences had
      // already lived inside `sepia.settings.v1`. Defaulting the new key to
      // off without migrating the old fields silently disabled every
      // existing installation on upgrade. Settings created before the
      // explicit switch do not carry the fields at all; those builds always
      // synced to the current web origin, so preserve that behaviour too.
      final legacyRaw = prefs.getString(_settingsKey);
      if (legacyRaw != null) {
        try {
          final legacy = Map<String, dynamic>.from(
            jsonDecode(legacyRaw) as Map,
          );
          config = SyncConfig(
            enabled: legacy['syncEnabled'] as bool? ?? true,
            serverUrl: legacy['syncServerUrl'] as String? ?? '',
          );
        } catch (_) {
          config = const SyncConfig();
        }
      }
      await prefs.setString(_syncConfigKey, jsonEncode(config.toJson()));
    }
    _cachedSyncConfig = config;
    return config;
  }

  Future<bool> isSyncEnabled() async => (await loadSyncConfig()).enabled;

  Future<void> saveSyncConfig(SyncConfig config) async {
    _cachedSyncConfig = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncConfigKey, jsonEncode(config.toJson()));
  }

  Future<DateTime?> loadLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastSyncKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _markSynced() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  /// Resolves an API path against the configured server, or returns null
  /// when syncing is off (in which case the app runs fully local).
  ///
  /// An empty address means "wherever this app was served from", which only
  /// has a meaning on the web. In an installed app `Uri.base` is a file
  /// location, not an origin, so an empty address there would produce a
  /// request that can never succeed — treat it as "not configured" instead.
  Uri? _resolve(String path, SyncConfig config) {
    if (!config.enabled) return null;
    var base = config.serverUrl.trim();
    if (base.isEmpty) return kIsWeb ? Uri.base.resolve(path) : null;
    // People type addresses like "192.168.2.5:8888", without a scheme.
    // Uri.tryParse rejects that outright — a leading digit isn't a valid
    // scheme character, so it can't tell "host:port" from "scheme:path" and
    // just gives up, returning null — which surfaced as "invalid URL" for a
    // perfectly reachable address. Assume http:// when none is given.
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(base)) {
      base = 'http://$base';
    }
    final normalized = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    return Uri.tryParse('$normalized$path');
  }

  Future<dynamic> _fetchJson(String path) async {
    final uri = _resolve(path, await loadSyncConfig());
    if (uri == null) return null;
    try {
      final response = await _client.get(uri).timeout(_networkTimeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      _serverResponses++;
      await _markSynced();
      return decoded;
    } catch (error) {
      debugPrint('sepia: GET $path failed: $error');
      return null;
    }
  }

  Future<void> _pushJson(String path, Object body) {
    // Keep outgoing snapshots in issue order. The server merges records too,
    // but serialization here also protects settings (a single object) and
    // prevents an older request from finishing after a newer one.
    final queued = _pendingPushes.then((_) async {
      try {
        final uri = _resolve(path, await loadSyncConfig());
        if (uri == null) return;
        final response = await _client
            .put(uri, headers: _mergeHeaders, body: jsonEncode(body))
            .timeout(_networkTimeout);
        if (response.statusCode != 200) {
          debugPrint('sepia: PUT $path returned ${response.statusCode}');
        } else {
          await _markSynced();
        }
      } catch (error) {
        // Never let one failed push poison the queue: the next call chains
        // off this future and would otherwise never run.
        debugPrint('sepia: PUT $path failed: $error');
      }
    });
    _pendingPushes = queued;
    return queued;
  }

  @visibleForTesting
  Future<void> waitForPendingSync() => _pendingPushes;

  /// Explicitly probes a server address, regardless of whether syncing is
  /// currently enabled, so the settings screen can tell the user what is
  /// actually wrong instead of failing silently.
  Future<SyncTestResult> testConnection(String serverUrl) async {
    final uri = _resolve(
      '/api/documents',
      SyncConfig(enabled: true, serverUrl: serverUrl),
    );
    if (uri == null) {
      return (
        ok: false,
        documentCount: 0,
        error: serverUrl.trim().isEmpty
            ? 'Informe o endereço do servidor'
            : 'URL inválida',
      );
    }
    try {
      final response = await _client.get(uri).timeout(_networkTimeout);
      if (response.statusCode != 200) {
        return (
          ok: false,
          documentCount: 0,
          error: 'HTTP ${response.statusCode}',
        );
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) {
        return (ok: false, documentCount: 0, error: 'Resposta inesperada');
      }
      // Live records only. The payload also carries tombstones — the marker
      // a deletion travels to other devices as — and counting those told the
      // user their server held ten documents when it held one.
      final live = decoded
          .whereType<Map>()
          .where((record) => record['deletedAt'] == null)
          .length;
      return (ok: true, documentCount: live, error: null);
    } catch (error) {
      return (ok: false, documentCount: 0, error: '$error');
    }
  }

  /// Reconciles one collection with the server, record by record.
  ///
  /// Replacing the local copy with whichever side was fetched last used to
  /// lose data: a device that had been offline for a week had its edits
  /// overwritten by the server's older copy, and two devices editing
  /// different documents clobbered each other. Merging per record and
  /// pushing the result back makes both sides converge instead.
  Future<List<T>> _loadMerged<T extends SyncableRecord>({
    required String key,
    required String path,
    required List<T> Function(List<dynamic>) decode,
    required Map<String, dynamic> Function(T) encode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final local = _decodeListRaw(prefs.getString(key), decode);
    final remoteRaw = await _fetchJson(path);
    final remote = remoteRaw is List ? _decodeList(remoteRaw, decode) : null;

    final merged = purgeExpiredTombstones(
      remote == null ? local : mergeById(local, remote),
    );
    final encoded = merged.map(encode).toList();
    await prefs.setString(key, jsonEncode(encoded));

    // Only write back when the server's copy actually differs, so a start-up
    // that changed nothing does not cost a needless upload.
    if (remoteRaw is List && jsonEncode(remoteRaw) != jsonEncode(encoded)) {
      await _pushJson(path, encoded);
    }
    return merged;
  }

  List<T> _decodeListRaw<T>(
    String? raw,
    List<T> Function(List<dynamic>) decode,
  ) {
    if (raw == null) return [];
    try {
      return _decodeList(jsonDecode(raw) as List<dynamic>, decode);
    } catch (_) {
      return [];
    }
  }

  List<T> _decodeList<T>(
    List<dynamic> raw,
    List<T> Function(List<dynamic>) decode,
  ) {
    try {
      return decode(raw);
    } catch (error) {
      debugPrint('sepia: could not decode payload: $error');
      return [];
    }
  }

  Future<List<LibraryDocument>> loadDocuments() => _loadMerged(
    key: _documentsKey,
    path: '/api/documents',
    decode: _decodeDocuments,
    encode: (document) => document.toJson(),
  );

  List<LibraryDocument> _decodeDocuments(List<dynamic> raw) => raw
      .map(
        (item) =>
            LibraryDocument.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .toList();

  /// Forces the device's own sync preferences onto a settings object, so a
  /// payload coming from the server can never change them.
  Future<AppSettings> _withLocalSyncConfig(AppSettings settings) async {
    final config = await loadSyncConfig();
    return settings.copyWith(
      syncEnabled: config.enabled,
      syncServerUrl: config.serverUrl,
    );
  }

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final local = _decodeSettings(prefs.getString(_settingsKey));
    final remoteRaw = await _fetchJson('/api/settings');
    final remote = remoteRaw is Map && remoteRaw.isNotEmpty
        ? AppSettings.fromJson(Map<String, dynamic>.from(remoteRaw))
        : null;

    // The server's copy only wins when it is genuinely newer. It used to win
    // unconditionally, so a stale server copy (a push that had not landed yet
    // when the app was killed or restarted for an upgrade) quietly reverted
    // local appearance changes on the next launch.
    if (remote != null && _isNewer(remote.settingsUpdatedAt, local?.settingsUpdatedAt)) {
      await prefs.setString(_settingsKey, jsonEncode(remote.toJson()));
      return _withLocalSyncConfig(remote);
    }

    final resolved = local ?? const AppSettings();
    // Local is at least as new as the server. If it is strictly newer and the
    // server answered at all, push it up so the two converge.
    if (remote != null &&
        _isNewer(resolved.settingsUpdatedAt, remote.settingsUpdatedAt)) {
      final remoteJson = Map<String, dynamic>.from(resolved.toJson())
        ..remove('syncEnabled')
        ..remove('syncServerUrl');
      unawaited(_pushJson('/api/settings', remoteJson));
    }
    return _withLocalSyncConfig(resolved);
  }

  AppSettings? _decodeSettings(String? raw) {
    if (raw == null) return null;
    try {
      return AppSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  /// Whether [a] is strictly after [b], treating a null clock (settings that
  /// predate the merge key) as older than any real timestamp and as equal to
  /// another null — in which case neither side is "newer" and the local copy
  /// is kept.
  static bool _isNewer(DateTime? a, DateTime? b) {
    if (a == null) return false;
    if (b == null) return true;
    return a.isAfter(b);
  }

  Future<List<LibraryFolder>> loadFolders() => _loadMerged(
    key: _foldersKey,
    path: '/api/folders',
    decode: _decodeFolders,
    encode: (folder) => folder.toJson(),
  );

  List<LibraryFolder> _decodeFolders(List<dynamic> raw) => raw
      .map(
        (item) =>
            LibraryFolder.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .toList();

  Future<List<ReadingBookmark>> loadBookmarks() => _loadMerged(
    key: _bookmarksKey,
    path: '/api/bookmarks',
    decode: _decodeBookmarks,
    encode: (bookmark) => bookmark.toJson(),
  );

  // Bookmarks written before the chunk-index redesign carry a
  // `scrollFraction` instead of `chunkIndex` and fail to parse; skip those
  // individually instead of losing the whole list to one old record.
  List<ReadingBookmark> _decodeBookmarks(List<dynamic> raw) => raw
      .map((item) {
        try {
          return ReadingBookmark.fromJson(
            Map<String, dynamic>.from(item as Map),
          );
        } catch (error) {
          debugPrint('sepia: dropping unreadable bookmark: $error');
          return null;
        }
      })
      .whereType<ReadingBookmark>()
      .toList();

  Future<void> saveBookmarks(List<ReadingBookmark> bookmarks) async {
    final json = bookmarks.map((bookmark) => bookmark.toJson()).toList();
    await (await SharedPreferences.getInstance()).setString(
      _bookmarksKey,
      jsonEncode(json),
    );
    unawaited(_pushJson('/api/bookmarks', json));
  }

  Future<void> saveDocuments(List<LibraryDocument> documents) async {
    final json = documents.map((document) => document.toJson()).toList();
    await (await SharedPreferences.getInstance()).setString(
      _documentsKey,
      jsonEncode(json),
    );
    unawaited(_pushJson('/api/documents', json));
  }

  Future<void> saveSettings(AppSettings settings) async {
    final json = settings.toJson();
    await (await SharedPreferences.getInstance()).setString(
      _settingsKey,
      jsonEncode(json),
    );
    // These two values configure this device, not the shared library. Keeping
    // them out of the remote payload avoids leaking a device-only address and
    // matches the local-authoritative contract enforced while loading.
    final remoteJson = Map<String, dynamic>.from(json)
      ..remove('syncEnabled')
      ..remove('syncServerUrl');
    unawaited(_pushJson('/api/settings', remoteJson));
  }

  Future<void> saveFolders(List<LibraryFolder> folders) async {
    final json = folders.map((folder) => folder.toJson()).toList();
    await (await SharedPreferences.getInstance()).setString(
      _foldersKey,
      jsonEncode(json),
    );
    unawaited(_pushJson('/api/folders', json));
  }

  /// Reconciles every collection with the server on demand, behind the
  /// pull-to-refresh gesture.
  ///
  /// This deliberately merges rather than overwriting local state: a
  /// deletion made on another device now travels as a tombstone, so there is
  /// no longer any reason to let a remote copy replace local work wholesale.
  Future<
    ({
      List<LibraryDocument> documents,
      List<LibraryFolder> folders,
      List<ReadingBookmark> bookmarks,
      AppSettings settings,
      bool reachedServer,
    })
  >
  forcePull() async {
    // A pull must not race a save that was already queued by this device.
    // Otherwise the GET can observe the old server snapshot and report a
    // successful sync before the local edit has even arrived.
    await _pendingPushes;
    _serverResponses = 0;
    final documents = await loadDocuments();
    final folders = await loadFolders();
    final bookmarks = await loadBookmarks();
    final settings = await loadSettings();
    return (
      documents: documents,
      folders: folders,
      bookmarks: bookmarks,
      settings: settings,
      reachedServer: _serverResponses > 0,
    );
  }

  /// Erases the server's copy of the library, used when the user turns sync
  /// off and asks for the remote copy to go with it.
  ///
  /// Takes the config explicitly because it must run while syncing is still
  /// enabled, before the new (disabled) preferences are stored. Returns
  /// whether every write landed, so the caller can be honest about a server
  /// that could not be reached instead of claiming a deletion that never
  /// happened.
  Future<bool> clearServer(SyncConfig config) async {
    Future<bool> put(String path, Object body) async {
      final uri = _resolve(path, config);
      if (uri == null) return false;
      try {
        final response = await _client
            .put(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(_networkTimeout);
        return response.statusCode == 200;
      } catch (error) {
        debugPrint('sepia: clearing $path failed: $error');
        return false;
      }
    }

    final results = await Future.wait([
      put('/api/documents', const []),
      put('/api/folders', const []),
      put('/api/bookmarks', const []),
      put('/api/settings', const <String, dynamic>{}),
    ]);
    return results.every((ok) => ok);
  }
}
