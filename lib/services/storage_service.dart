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
import 'server_connection.dart';
import 'json_work.dart';

String _joinDocumentJsonRecords(List<String> records) =>
    '[${records.join(',')}]';

/// Locally-stored sync preferences.
///
/// Deliberately kept out of the synced settings payload: if the only copy
/// lived on the server, a settings response could disable a device's sync
/// (locking it out of ever syncing again) or silently repoint it at another
/// host. The local copy is always authoritative.
class SyncConfig {
  const SyncConfig({
    this.enabled = false,
    this.serverUrl = '',
    this.token = '',
  });
  final bool enabled;
  final String serverUrl;
  final String token;

  Map<String, dynamic> toJson() => {
    'syncEnabled': enabled,
    'syncServerUrl': serverUrl,
    'syncToken': token,
  };

  /// Defaults to off: a freshly installed copy of an open-source, local-first
  /// app should not assume a server exists. Devices that already stored a
  /// preference keep it, since the key is present in their saved payload.
  factory SyncConfig.fromJson(Map<String, dynamic> json) => SyncConfig(
    enabled: json['syncEnabled'] as bool? ?? false,
    serverUrl: json['syncServerUrl'] as String? ?? '',
    token: json['syncToken'] as String? ?? '',
  );
}

/// Outcome of an explicit "test connection" from the settings screen.
typedef SyncTestResult = ({bool ok, int? documentCount, String? error});

class StorageService {
  StorageService({http.Client? client}) : _client = client ?? http.Client();

  static const _documentsKey = 'sepia.documents.v1';
  static const _settingsKey = 'sepia.settings.v1';
  static const _foldersKey = 'sepia.folders.v1';
  static const _bookmarksKey = 'sepia.bookmarks.v1';
  static const _syncConfigKey = 'sepia.syncconfig.v1';
  static const _lastSyncKey = 'sepia.lastsync.v1';

  // A real sync may carry multi-megabyte documents over a sleepy phone's
  // Wi-Fi. Six seconds was short enough to turn an otherwise healthy server
  // into "Future not completed". The lightweight health probe remains short;
  // transferring the library gets a realistic budget.
  static const _probeTimeout = Duration(seconds: 6);
  static const _networkTimeout = Duration(seconds: 30);
  static const _mergeHeaders = {
    'Content-Type': 'application/json',
    'X-Sepia-Write-Mode': 'merge',
  };

  final http.Client _client;

  /// JSON for unchanged documents, keyed by the object that produced it.
  /// Autosave changes one record, so re-encoding every other large body on
  /// every save was pure main-isolate work.
  final Map<String, ({LibraryDocument document, String json})>
  _encodedDocuments = {};

  SyncConfig? _cachedSyncConfig;
  Future<void> _pendingPushes = Future.value();
  Future<void> _pendingDocumentWrites = Future.value();

  /// `true`/`false` once the server has given a definitive answer about merge
  /// writes; stays null while only transient failures (offline, server still
  /// waking) have been seen, so the next autosave probes again instead of
  /// falling back to full-collection uploads for the rest of the session.
  bool? _mergeWriteCapability;
  int _connectionGeneration = 0;

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
    _mergeWriteCapability = null;
    _connectionGeneration++;
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

  /// Reads only this device's saved documents, without touching the network.
  ///
  /// Startup uses the local variants so the first frame never waits for a
  /// server. A background sync reconciles these values after the app is
  /// already visible.
  Future<List<LibraryDocument>> loadLocalDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_documentsKey);
    if (raw == null) return [];
    try {
      return _decodeList(
        (await decodeStoredJson(raw)) as List<dynamic>,
        _decodeDocuments,
      );
    } catch (_) {
      return [];
    }
  }

  Future<List<LibraryFolder>> loadLocalFolders() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeListRaw(prefs.getString(_foldersKey), _decodeFolders);
  }

  Future<List<ReadingBookmark>> loadLocalBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeListRaw(prefs.getString(_bookmarksKey), _decodeBookmarks);
  }

  Future<AppSettings> loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return _withLocalSyncConfig(
      _decodeSettings(prefs.getString(_settingsKey)) ?? const AppSettings(),
    );
  }

  /// Resolves an API path against the configured server, or returns null
  /// when syncing is off (in which case the app runs fully local).
  ///
  /// An empty address means "wherever this app was served from", which only
  /// has a meaning on the web. In an installed app `Uri.base` is a file
  /// location, not an origin, so an empty address there would produce a
  /// request that can never succeed — treat it as "not configured" instead.
  Uri? _resolve(String path, SyncConfig config) =>
      serverUri(config.serverUrl, path, enabled: config.enabled);

  Map<String, String> _authHeaders(SyncConfig config) => {
    if (config.token.isNotEmpty) 'Authorization': 'Bearer ${config.token}',
  };

  Future<dynamic> _fetchJson(String path) async {
    final config = await loadSyncConfig();
    final uri = _resolve(path, config);
    if (uri == null) return null;
    try {
      final response = await serverRequest(
        _client,
        'GET',
        uri,
        headers: _authHeaders(config),
      ).timeout(_networkTimeout);
      if (response.statusCode != 200) return null;
      final decoded = await decodeStoredJson(utf8.decode(response.bodyBytes));
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
    return _enqueuePush(() => _sendJson(path, body));
  }

  Future<void> _enqueuePush(Future<void> Function() operation) {
    final queued = _pendingPushes.then((_) => operation());
    _pendingPushes = queued;
    return queued;
  }

  Future<void> _sendJson(String path, Object body, {SyncConfig? config}) async {
    try {
      config ??= await loadSyncConfig();
      final uri = _resolve(path, config);
      if (uri == null) return;
      final response = await serverRequest(
        _client,
        'PUT',
        uri,
        headers: {..._mergeHeaders, ..._authHeaders(config)},
        body: await encodeStoredJson(body),
      ).timeout(_networkTimeout);
      if (response.statusCode != 200) {
        debugPrint('sepia: PUT $path returned ${response.statusCode}');
      } else {
        await _markSynced();
      }
    } catch (error) {
      // Never let one failed push poison the queue: every queued operation
      // completes even when its network request does not.
      debugPrint('sepia: PUT $path failed: $error');
    }
  }

  @visibleForTesting
  Future<void> waitForPendingSync() => _pendingPushes;

  /// Explicitly probes a server address, regardless of whether syncing is
  /// currently enabled, so the settings screen can tell the user what is
  /// actually wrong instead of failing silently.
  Future<SyncTestResult> testConnection(
    String serverUrl, {
    String token = '',
  }) async {
    final config = SyncConfig(
      enabled: true,
      serverUrl: serverUrl,
      token: token,
    );
    final healthUri = _resolve('/healthz', config);
    if (healthUri == null) {
      return (
        ok: false,
        documentCount: null,
        error: serverUrl.trim().isEmpty
            ? 'Informe o endereço do servidor'
            : 'URL inválida',
      );
    }
    try {
      // Current servers expose a tiny liveness response. The old probe fetched
      // the entire document collection merely to prove the server existed —
      // 2.4 MB in a real library — and routinely hit the six-second timeout.
      final health = await serverRequest(
        _client,
        'GET',
        healthUri,
      ).timeout(_probeTimeout);
      if (health.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(health.bodyBytes));
        if (decoded is Map && decoded['ok'] == true) {
          if (decoded['authentication'] == true) {
            final authorized = await serverRequest(
              _client,
              'HEAD',
              _resolve('/api/documents', config)!,
              headers: _authHeaders(config),
            ).timeout(_probeTimeout);
            if (authorized.statusCode != 200) {
              return (
                ok: false,
                documentCount: null,
                error: 'HTTP ${authorized.statusCode}',
              );
            }
          }
          return (ok: true, documentCount: null, error: null);
        }
        return (ok: false, documentCount: null, error: 'Resposta inesperada');
      }

      // Compatibility with servers from before /healthz existed. This path
      // can be retired once those versions are no longer in use.
      if (health.statusCode != 404) {
        return (
          ok: false,
          documentCount: null,
          error: 'HTTP ${health.statusCode}',
        );
      }

      final documentsUri = _resolve('/api/documents', config)!;
      final response = await serverRequest(
        _client,
        'GET',
        documentsUri,
        headers: _authHeaders(config),
      ).timeout(_networkTimeout);
      if (response.statusCode != 200) {
        return (
          ok: false,
          documentCount: null,
          error: 'HTTP ${response.statusCode}',
        );
      }
      final decoded = await decodeStoredJson(utf8.decode(response.bodyBytes));
      if (decoded is! List) {
        return (ok: false, documentCount: null, error: 'Resposta inesperada');
      }
      // Live records only. The payload also carries tombstones — the marker
      // a deletion travels to other devices as — and counting those told the
      // user their server held ten documents when it held one.
      final live = decoded
          .whereType<Map>()
          .where((record) => record['deletedAt'] == null)
          .length;
      return (ok: true, documentCount: live, error: null);
    } on TimeoutException {
      return (
        ok: false,
        documentCount: null,
        error: 'Tempo esgotado ao contatar o servidor',
      );
    } catch (error) {
      return (ok: false, documentCount: null, error: '$error');
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
    final remoteRaw = await _fetchJson(path);
    final remote = remoteRaw is List ? _decodeList(remoteRaw, decode) : null;

    Future<List<T>> reconcile() async {
      // Re-read inside the write queue: a large encode can yield while an
      // autosave arrives. Both operations must keep their issue order.
      final raw = prefs.getString(key);
      List<T> local;
      try {
        local = raw == null
            ? []
            : _decodeList(await decodeStoredJson(raw) as List<dynamic>, decode);
      } catch (_) {
        local = [];
      }
      final merged = purgeExpiredTombstones(
        remote == null ? local : mergeById(local, remote),
      );
      final localChanged = !sameRecordVersions(local, merged);
      final remoteChanged =
          remoteRaw is List &&
          (remote == null ||
              remote.length != remoteRaw.length ||
              !sameRecordVersions(remote, merged));
      if (localChanged || remoteChanged) {
        final encoded = merged.map(encode).toList(growable: false);
        if (localChanged) {
          await prefs.setString(key, await encodeStoredJson(encoded));
        }
        if (remoteChanged) unawaited(_pushJson(path, encoded));
      }
      return merged;
    }

    if (key != _documentsKey) return reconcile();
    final operation = _pendingDocumentWrites.then((_) => reconcile());
    _pendingDocumentWrites = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
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
      .map((item) {
        try {
          return LibraryDocument.fromJson(
            Map<String, dynamic>.from(item as Map),
          );
        } catch (error) {
          debugPrint('sepia: skipped malformed document: $error');
          return null;
        }
      })
      .whereType<LibraryDocument>()
      .toList();

  /// Forces the device's own sync preferences onto a settings object, so a
  /// payload coming from the server can never change them.
  Future<AppSettings> _withLocalSyncConfig(AppSettings settings) async {
    final config = await loadSyncConfig();
    return settings.copyWith(
      syncEnabled: config.enabled,
      syncServerUrl: config.serverUrl,
      syncToken: config.token,
    );
  }

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final local = _decodeSettings(prefs.getString(_settingsKey));
    final remoteRaw = await _fetchJson('/api/settings');
    // Guard the remote decode the same way the local one is. The server
    // accepts any JSON object at /api/settings, so a malformed payload
    // (e.g. `{"themeMode": 123}`) would otherwise throw here and abort the
    // whole four-endpoint Future.wait, failing pull-to-refresh outright.
    final remote = _decodeRemoteSettings(remoteRaw);

    // With nothing stored locally there is nothing to protect: adopt the
    // server's copy wholesale, the way a fresh install pointed at an existing
    // library always has.
    //
    // Otherwise the server's copy only wins when it is genuinely newer. It
    // used to win unconditionally, so a stale server copy (a push that had
    // not landed yet when the app was killed or restarted for an upgrade)
    // quietly reverted local appearance changes on the next launch.
    if (remote != null &&
        (local == null ||
            _isNewer(remote.settingsUpdatedAt, local.settingsUpdatedAt))) {
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
        ..remove('syncServerUrl')
        ..remove('syncToken');
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

  /// Decodes the settings object the server returned, treating anything that
  /// is not a well-formed [AppSettings] as "no remote settings" rather than
  /// letting it throw out of the sync.
  AppSettings? _decodeRemoteSettings(Object? raw) {
    if (raw is! Map || raw.isEmpty) return null;
    try {
      return AppSettings.fromJson(Map<String, dynamic>.from(raw));
    } catch (error) {
      debugPrint('sepia: could not decode remote settings: $error');
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
      .map((item) {
        try {
          return LibraryFolder.fromJson(Map<String, dynamic>.from(item as Map));
        } catch (error) {
          debugPrint('sepia: skipped malformed folder: $error');
          return null;
        }
      })
      .whereType<LibraryFolder>()
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
    // Snapshot before the first await: AppController owns a mutable list, and a
    // later edit must not leak into this older snapshot while prefs loads.
    final snapshot = List<LibraryDocument>.of(documents);
    await _writeDocumentSnapshot(snapshot);
    unawaited(
      _pushJson(
        '/api/documents',
        snapshot.map((document) => document.toJson()).toList(growable: false),
      ),
    );
  }

  /// Keeps the complete local snapshot. A server gets only the changed record
  /// when it explicitly advertises merge support; legacy servers get the full
  /// list because their PUT endpoint replaced the collection.
  Future<void> saveDocument(
    List<LibraryDocument> documents,
    LibraryDocument changed,
  ) async {
    final snapshot = List<LibraryDocument>.of(documents);
    final changedRemote = changed.toJson();
    await _writeDocumentSnapshot(snapshot);
    unawaited(_pushDocumentDelta(snapshot, changedRemote));
  }

  /// Persists the startup seed without starting a network request before the
  /// first frame. The background sync will merge and publish it if needed.
  Future<void> saveDocumentsLocally(List<LibraryDocument> documents) async {
    await _writeDocumentSnapshot(List<LibraryDocument>.of(documents));
  }

  /// Joins the complete SharedPreferences snapshot away from the UI isolate.
  /// The per-record cache means an autosave only JSON-encodes the changed
  /// document, but the old `records.join(',')` still copied the entire
  /// library on the main isolate every time.
  Future<void> _writeDocumentSnapshot(List<LibraryDocument> snapshot) {
    final write = _pendingDocumentWrites.then((_) async {
      final records = await _encodeDocumentRecords(snapshot);
      final encodedSize = records.fold<int>(
        2,
        (total, record) => total + record.length + 1,
      );
      final encoded = encodedSize >= 256 * 1024
          ? await compute(_joinDocumentJsonRecords, records)
          : _joinDocumentJsonRecords(records);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_documentsKey, encoded);
    });
    _pendingDocumentWrites = write.then<void>((_) {}, onError: (_, _) {});
    return write;
  }

  Future<void> _pushDocumentDelta(
    List<LibraryDocument> full,
    Map<String, dynamic> changed,
  ) => _enqueuePush(() async {
    final config = await loadSyncConfig();
    final generation = _connectionGeneration;
    var supportsMerge = generation == _connectionGeneration
        ? _mergeWriteCapability
        : null;
    if (supportsMerge == null) {
      final probed = await _probeMergeSupport(config);
      if (probed != null && generation == _connectionGeneration) {
        _mergeWriteCapability = probed;
      }
      supportsMerge = probed ?? false;
    }
    // Modern servers receive one small record. Only construct a complete
    // remote snapshot for a legacy replace-only server; doing it eagerly on
    // every autosave walked all documents even when it was never used.
    final body = supportsMerge
        ? [changed]
        : full.map((document) => document.toJson()).toList(growable: false);
    await _sendJson('/api/documents', body, config: config);
  });

  /// `true`/`false` when the server has answered for certain, `null` when the
  /// probe could not reach it (offline, timeout, a proxy 5xx) so the caller
  /// retries next time rather than caching a pessimistic guess all session.
  Future<bool?> _probeMergeSupport(SyncConfig config) async {
    final uri = _resolve('/healthz', config);
    if (uri == null) return false;
    try {
      final response = await serverRequest(
        _client,
        'GET',
        uri,
      ).timeout(_probeTimeout);
      // A server old enough to lack /healthz has no merge endpoint either;
      // that 404 is a definitive answer. Other non-200s are transient.
      if (response.statusCode == 404) return false;
      if (response.statusCode != 200) return null;
      final decoded = await decodeStoredJson(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return false;
      final modes = decoded['write_modes'];
      return modes is List && modes.contains('merge');
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _encodeDocumentRecords(
    List<LibraryDocument> documents,
  ) async {
    final ids = documents.map((document) => document.id).toSet();
    _encodedDocuments.removeWhere((id, _) => !ids.contains(id));
    final missing = documents
        .where((d) => !identical(_encodedDocuments[d.id]?.document, d))
        .toList(growable: false);
    final encoded = await encodeJsonRecords([
      for (final d in missing) d.toJson(),
    ]);
    for (var index = 0; index < missing.length; index++) {
      final document = missing[index];
      _encodedDocuments[document.id] = (
        document: document,
        json: encoded[index],
      );
    }
    return [
      for (final document in documents) _encodedDocuments[document.id]!.json,
    ];
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
      ..remove('syncServerUrl')
      ..remove('syncToken');
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
    // Independent endpoints should not multiply a timeout by four. The old
    // serial sequence could leave a pull-to-refresh spinning for two minutes
    // when a server was unreachable.
    final results = await Future.wait<Object>([
      loadDocuments(),
      loadFolders(),
      loadBookmarks(),
      loadSettings(),
    ]);
    final documents = results[0] as List<LibraryDocument>;
    final folders = results[1] as List<LibraryFolder>;
    final bookmarks = results[2] as List<ReadingBookmark>;
    final settings = results[3] as AppSettings;
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
        final response = await serverRequest(
          _client,
          'PUT',
          uri,
          headers: {
            'Content-Type': 'application/json',
            ..._authHeaders(config),
          },
          body: await encodeStoredJson(body),
        ).timeout(_networkTimeout);
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
