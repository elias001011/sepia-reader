import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

const _large = 256 * 1024;

String _encode(Object value) => jsonEncode(value);
dynamic _decode(String value) => jsonDecode(value);
List<String> _encodeRecords(List<Map<String, dynamic>> values) =>
    values.map(jsonEncode).toList(growable: false);

int _weight(Object? value) {
  if (value is Map) return (value['content'] as String?)?.length ?? 0;
  if (value is List) return value.fold(0, (n, item) => n + _weight(item));
  return 0;
}

Future<dynamic> decodeStoredJson(String value) async =>
    !kIsWeb && value.length >= _large
    ? compute(_decode, value)
    : jsonDecode(value);

/// Native encoding uses a worker for large payloads. Browsers yield between
/// bounded pieces, because Flutter Web's compute runs on the UI thread.
Future<String> encodeStoredJson(Object value) async {
  if (_weight(value) < _large) return jsonEncode(value);
  if (!kIsWeb) return compute(_encode, value);
  if (value is List) {
    final records = await encodeJsonRecords(value.cast<Map<String, dynamic>>());
    return '[${records.join(',')}]';
  }
  if (value is Map<String, dynamic> && value['content'] is String) {
    final content = value['content'] as String;
    final metadata = Map<String, dynamic>.of(value)..remove('content');
    final prefix = jsonEncode(metadata);
    final pieces = <String>[];
    for (var start = 0; start < content.length; start += 32768) {
      final end = (start + 32768).clamp(0, content.length);
      final encoded = jsonEncode(content.substring(start, end));
      pieces.add(encoded.substring(1, encoded.length - 1));
      await Future<void>.delayed(Duration.zero);
    }
    final separator = metadata.isEmpty ? '' : ',';
    return '${prefix.substring(0, prefix.length - 1)}$separator"content":"${pieces.join()}"}';
  }
  return jsonEncode(value);
}

Future<List<String>> encodeJsonRecords(
  List<Map<String, dynamic>> values,
) async {
  if (!kIsWeb && _weight(values) >= _large) {
    return compute(_encodeRecords, values);
  }
  final result = <String>[];
  var budget = 0;
  for (final value in values) {
    result.add(await encodeStoredJson(value));
    budget += _weight(value) + 512;
    if (budget >= 65536) {
      budget = 0;
      await Future<void>.delayed(Duration.zero);
    }
  }
  return result;
}
