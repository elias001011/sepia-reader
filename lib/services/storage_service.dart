import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/bookmark.dart';
import '../models/library_document.dart';
import '../models/library_folder.dart';

class StorageService {
  static const _documentsKey = 'sepia.documents.v1';
  static const _settingsKey = 'sepia.settings.v1';
  static const _foldersKey = 'sepia.folders.v1';
  static const _bookmarksKey = 'sepia.bookmarks.v1';

  static const _networkTimeout = Duration(seconds: 6);

  Uri _apiUri(String path) => Uri.base.resolve(path);

  Future<dynamic> _fetchJson(String path) async {
    try {
      final response = await http.get(_apiUri(path)).timeout(_networkTimeout);
      if (response.statusCode != 200) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (error) {
      debugPrint('sepia: GET $path failed: $error');
      return null;
    }
  }

  void _pushJson(String path, Object body) {
    unawaited(() async {
      try {
        final response = await http
            .put(
              _apiUri(path),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(_networkTimeout);
        if (response.statusCode != 200) {
          debugPrint('sepia: PUT $path returned ${response.statusCode}');
        }
      } catch (error) {
        debugPrint('sepia: PUT $path failed: $error');
      }
    }());
  }

  Future<List<LibraryDocument>> loadDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final localRaw = prefs.getString(_documentsKey);
    final local = _decodeDocumentsRaw(localRaw);
    final remote = await _fetchJson('/api/documents');
    if (remote is List) {
      if (remote.isNotEmpty || local.isEmpty) {
        await prefs.setString(_documentsKey, jsonEncode(remote));
        return _decodeDocuments(remote);
      }
      // Server has nothing yet but this device already has a library: don't
      // let an unsynced/empty server silently wipe local data. Seed the
      // server from what we have instead.
      _pushJson('/api/documents', local.map((d) => d.toJson()).toList());
      return local;
    }
    return local;
  }

  List<LibraryDocument> _decodeDocumentsRaw(String? raw) {
    if (raw == null) return [];
    try {
      return _decodeDocuments(jsonDecode(raw) as List<dynamic>);
    } catch (_) {
      return [];
    }
  }

  List<LibraryDocument> _decodeDocuments(List<dynamic> raw) => raw
      .map(
        (item) =>
            LibraryDocument.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .toList();

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final localRaw = prefs.getString(_settingsKey);
    final remote = await _fetchJson('/api/settings');
    if (remote is Map && remote.isNotEmpty) {
      final map = Map<String, dynamic>.from(remote);
      await prefs.setString(_settingsKey, jsonEncode(map));
      return AppSettings.fromJson(map);
    }
    if (localRaw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(localRaw) as Map),
      );
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<List<LibraryFolder>> loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final localRaw = prefs.getString(_foldersKey);
    final local = _decodeFoldersRaw(localRaw);
    final remote = await _fetchJson('/api/folders');
    if (remote is List) {
      if (remote.isNotEmpty || local.isEmpty) {
        await prefs.setString(_foldersKey, jsonEncode(remote));
        return _decodeFolders(remote);
      }
      _pushJson('/api/folders', local.map((f) => f.toJson()).toList());
      return local;
    }
    return local;
  }

  List<LibraryFolder> _decodeFoldersRaw(String? raw) {
    if (raw == null) return [];
    try {
      return _decodeFolders(jsonDecode(raw) as List<dynamic>);
    } catch (_) {
      return [];
    }
  }

  List<LibraryFolder> _decodeFolders(List<dynamic> raw) => raw
      .map(
        (item) =>
            LibraryFolder.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .toList();

  Future<List<ReadingBookmark>> loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final localRaw = prefs.getString(_bookmarksKey);
    final local = _decodeBookmarksRaw(localRaw);
    final remote = await _fetchJson('/api/bookmarks');
    if (remote is List) {
      if (remote.isNotEmpty || local.isEmpty) {
        await prefs.setString(_bookmarksKey, jsonEncode(remote));
        return _decodeBookmarks(remote);
      }
      _pushJson('/api/bookmarks', local.map((b) => b.toJson()).toList());
      return local;
    }
    return local;
  }

  List<ReadingBookmark> _decodeBookmarksRaw(String? raw) {
    if (raw == null) return [];
    try {
      return _decodeBookmarks(jsonDecode(raw) as List<dynamic>);
    } catch (_) {
      return [];
    }
  }

  List<ReadingBookmark> _decodeBookmarks(List<dynamic> raw) => raw
      .map(
        (item) =>
            ReadingBookmark.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .toList();

  Future<void> saveBookmarks(List<ReadingBookmark> bookmarks) async {
    final json = bookmarks.map((bookmark) => bookmark.toJson()).toList();
    await (await SharedPreferences.getInstance()).setString(
      _bookmarksKey,
      jsonEncode(json),
    );
    _pushJson('/api/bookmarks', json);
  }

  Future<void> saveDocuments(List<LibraryDocument> documents) async {
    final json = documents.map((document) => document.toJson()).toList();
    await (await SharedPreferences.getInstance()).setString(
      _documentsKey,
      jsonEncode(json),
    );
    _pushJson('/api/documents', json);
  }

  Future<void> saveSettings(AppSettings settings) async {
    final json = settings.toJson();
    await (await SharedPreferences.getInstance()).setString(
      _settingsKey,
      jsonEncode(json),
    );
    _pushJson('/api/settings', json);
  }

  Future<void> saveFolders(List<LibraryFolder> folders) async {
    final json = folders.map((folder) => folder.toJson()).toList();
    await (await SharedPreferences.getInstance()).setString(
      _foldersKey,
      jsonEncode(json),
    );
    _pushJson('/api/folders', json);
  }

  /// Forces an unconditional pull from the server, bypassing the
  /// don't-overwrite-local-with-empty-remote safety used by [loadDocuments]
  /// et al. Used for an explicit user-triggered "force sync" action, where
  /// an empty remote response is meaningful (e.g. after clearing the
  /// library on another device) rather than a sign of an unsynced server.
  Future<
    ({
      List<LibraryDocument> documents,
      List<LibraryFolder> folders,
      List<ReadingBookmark> bookmarks,
      AppSettings settings,
    })
  >
  forcePull() async {
    final prefs = await SharedPreferences.getInstance();

    final remoteDocuments = await _fetchJson('/api/documents');
    final documents = remoteDocuments is List
        ? _decodeDocuments(remoteDocuments)
        : _decodeDocumentsRaw(prefs.getString(_documentsKey));
    if (remoteDocuments is List) {
      await prefs.setString(_documentsKey, jsonEncode(remoteDocuments));
    }

    final remoteFolders = await _fetchJson('/api/folders');
    final folders = remoteFolders is List
        ? _decodeFolders(remoteFolders)
        : _decodeFoldersRaw(prefs.getString(_foldersKey));
    if (remoteFolders is List) {
      await prefs.setString(_foldersKey, jsonEncode(remoteFolders));
    }

    final remoteBookmarks = await _fetchJson('/api/bookmarks');
    final bookmarks = remoteBookmarks is List
        ? _decodeBookmarks(remoteBookmarks)
        : _decodeBookmarksRaw(prefs.getString(_bookmarksKey));
    if (remoteBookmarks is List) {
      await prefs.setString(_bookmarksKey, jsonEncode(remoteBookmarks));
    }

    final remoteSettings = await _fetchJson('/api/settings');
    AppSettings settings;
    if (remoteSettings is Map) {
      final map = Map<String, dynamic>.from(remoteSettings);
      await prefs.setString(_settingsKey, jsonEncode(map));
      settings = AppSettings.fromJson(map);
    } else {
      settings = await loadSettings();
    }

    return (
      documents: documents,
      folders: folders,
      bookmarks: bookmarks,
      settings: settings,
    );
  }
}
