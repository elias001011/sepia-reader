import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

/// User-owned fonts stay local: never bundled or sent to the sync server.
class CustomFonts {
  static const _key = 'sepia.customFonts.v1';
  static final Map<String, String> _files = {};
  static final Set<String> _loaded = {};
  static List<String> get families => _files.keys.toList(growable: false);

  static Future<void> load({String? selectedFamily}) async {
    _files.clear();
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null) return;
    try {
      for (final entry
          in (jsonDecode(stored) as Map<String, dynamic>).entries) {
        try {
          final encoded = entry.value as String;
          _files[entry.key] = encoded;
          if (entry.key == selectedFamily) await ensureLoaded(entry.key);
        } catch (_) {
          // One invalid font must not prevent the library from opening.
        }
      }
    } catch (_) {
      // A damaged local font registry falls back to the bundled faces.
    }
  }

  static Future<void> ensureLoaded(String family) async {
    if (_loaded.contains(family)) return;
    final encoded = _files[family];
    if (encoded == null) return;
    await _register(family, base64Decode(encoded));
    _loaded.add(family);
  }

  static Future<void> remove(String family) async {
    _files.remove(family);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_files));
  }

  static Future<void> _register(String family, Uint8List bytes) async {
    if (bytes.length < 12 || bytes.length > 5 * 1024 * 1024) {
      throw const FormatException('Invalid font size');
    }
    final signature = ByteData.sublistView(bytes).getUint32(0);
    if (signature != 0x00010000 &&
        signature != 0x4F54544F &&
        signature != 0x74727565) {
      throw const FormatException('Expected an OpenType or TrueType font');
    }
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }

  static Future<String?> import() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['ttf', 'otf'],
    );
    if (picked == null) return null;
    final file = picked;
    if ((await file.length() ?? 0) > 5 * 1024 * 1024) {
      throw const FormatException('Font too large');
    }
    final bytes = await file.readAsBytes();
    if (_files.length >= 12) throw const FormatException('Font limit reached');
    final name = file.name.replaceFirst(
      RegExp(r'\.(ttf|otf)$', caseSensitive: false),
      '',
    );
    final family =
        '$name · ${sha256.convert(bytes).toString().substring(0, 8)}';
    await _register(family, bytes);
    _loaded.add(family);
    _files[family] = base64Encode(bytes);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key, jsonEncode(_files))) {
      throw const FormatException('Could not save font');
    }
    return family;
  }
}
