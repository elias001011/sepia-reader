import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/library_document.dart';

class StorageService {
  static const _documentsKey = 'sepia.documents.v1';
  static const _settingsKey = 'sepia.settings.v1';

  Future<List<LibraryDocument>> loadDocuments() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      _documentsKey,
    );
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map(
            (item) => LibraryDocument.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<AppSettings> loadSettings() async {
    final raw = (await SharedPreferences.getInstance()).getString(_settingsKey);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveDocuments(List<LibraryDocument> documents) async =>
      (await SharedPreferences.getInstance()).setString(
        _documentsKey,
        jsonEncode(documents.map((document) => document.toJson()).toList()),
      );
  Future<void> saveSettings(AppSettings settings) async =>
      (await SharedPreferences.getInstance()).setString(
        _settingsKey,
        jsonEncode(settings.toJson()),
      );
}
