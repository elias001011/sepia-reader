import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Serializes the upstream JSON tables in sherpa-onnx's documented binary
/// format. ONNX weights remain unchanged. Runs in the install isolate.
/// See scripts/supertonic/generate_{indexer,voices}_bin.py in sherpa-onnx.
Future<void> prepareSupertonicAssets(String directory) async {
  final index = jsonDecode(
    await File('$directory/onnx/unicode_indexer.json').readAsString(),
  ) as List;
  final indexBytes = ByteData(index.length * 4);
  for (var i = 0; i < index.length; i++) {
    final value = index[i];
    if (value is! int || value < -2147483648 || value > 2147483647) {
      throw const FormatException('invalid Unicode indexer');
    }
    indexBytes.setInt32(i * 4, value, Endian.little);
  }
  final styles = <Map<String, dynamic>>[];
  // Stable order: M1 = speaker 0, M2 = speaker 1, independent of UI sorting.
  for (final voice in ['M1', 'M2']) {
    styles.add(
      jsonDecode(
        await File('$directory/voice_styles/$voice.json').readAsString(),
      ) as Map<String, dynamic>,
    );
  }
  final tables = <List<double>>[];
  final dimensions = <int>[];
  for (final key in ['style_ttl', 'style_dp']) {
    List<int>? shape;
    final values = <double>[];
    for (final style in styles) {
      final table = style[key] as Map<String, dynamic>;
      final dims = (table['dims'] as List).cast<int>();
      if (dims.length != 3 ||
          dims.first != 1 ||
          dims.any((d) => d <= 0) ||
          (shape != null && (dims[1] != shape[1] || dims[2] != shape[2]))) {
        throw const FormatException('inconsistent voice style dimensions');
      }
      shape = dims;
      final flat = <double>[];
      void flatten(Object? value) {
        if (value is List) {
          for (final item in value) {
            flatten(item);
          }
        } else if (value is num && value.isFinite) {
          flat.add(value.toDouble());
        } else {
          throw const FormatException('invalid voice style value');
        }
      }

      flatten(table['data']);
      if (flat.length != dims[1] * dims[2]) {
        throw const FormatException('invalid voice style length');
      }
      values.addAll(flat);
    }
    dimensions.addAll([styles.length, shape![1], shape[2]]);
    tables.add(values);
  }
  final voiceBytes = ByteData(
    48 + tables.fold<int>(0, (n, t) => n + t.length * 4),
  );
  for (var i = 0; i < dimensions.length; i++) {
    voiceBytes.setInt64(i * 8, dimensions[i], Endian.little);
  }
  var offset = 48;
  for (final table in tables) {
    for (final value in table) {
      voiceBytes.setFloat32(offset, value, Endian.little);
      offset += 4;
    }
  }
  // These small derived assets are replaceable; the install manifest is only
  // committed after both have been written successfully.
  await File('$directory/unicode_indexer.bin')
      .writeAsBytes(indexBytes.buffer.asUint8List(), flush: true);
  await File('$directory/voice.bin')
      .writeAsBytes(voiceBytes.buffer.asUint8List(), flush: true);
}
