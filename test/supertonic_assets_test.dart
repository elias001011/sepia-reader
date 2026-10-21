import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/services/tts/supertonic_assets.dart';
import 'package:sepia_reader/services/tts/voice_catalog.dart';

void main() {
  test(
    'catalog has pinned original models and explicit language/speaker ids',
    () {
      for (final version in [2, 3]) {
        final pack = voicePackById('supertonic/$version')!;
        expect(pack.revision, matches(RegExp(r'^[a-f0-9]{40}$')));
        expect(pack.files.where((f) => f.path.endsWith('.onnx')), hasLength(4));
        expect(pack.files.any((f) => f.path == 'LICENSE'), isTrue);
        expect(pack.files.every((f) => f.sha256.length == 64), isTrue);
        expect(
          pack.files.fold<int>(0, (n, f) => n + f.bytes),
          pack.approxBytes,
        );
        expect(resolveVoice('supertonic/$version/M1')!.voice.speakerId, 0);
        expect(resolveVoice('supertonic/$version/M2')!.voice.speakerId, 1);
        expect(pack.languages.length, version == 2 ? 5 : 31);
        for (final language in pack.languages) {
          expect(
            pack.voices
                .where((v) => v.language == language)
                .map((v) => v.speakerId),
            [1, 0],
          );
        }
      }
    },
  );

  test(
    'binary tables use upstream order, shapes and little endian values',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'sepia-supertonic-assets-',
      );
      addTearDown(() => dir.delete(recursive: true));
      await Directory('${dir.path}/onnx').create();
      await Directory('${dir.path}/voice_styles').create();
      await File('${dir.path}/onnx/unicode_indexer.json')
          .writeAsString('[0, -1, 200]');
      for (var i = 1; i <= 2; i++) {
        await File('${dir.path}/voice_styles/M$i.json').writeAsString(
          jsonEncode({
            'style_ttl': {
              'dims': [1, 1, 2],
              'data': [
                [
                  [i + 0.25, i + 0.5],
                ],
              ],
            },
            'style_dp': {
              'dims': [1, 1, 1],
              'data': [
                [
                  [i + 0.75],
                ],
              ],
            },
          }),
        );
      }
      await prepareSupertonicAssets(dir.path);
      final index = ByteData.sublistView(
        await File('${dir.path}/unicode_indexer.bin').readAsBytes(),
      );
      expect(index.getInt32(4, Endian.little), -1);
      expect(index.getInt32(8, Endian.little), 200);
      final voices = ByteData.sublistView(
        await File('${dir.path}/voice.bin').readAsBytes(),
      );
      expect(
        [for (var i = 0; i < 6; i++) voices.getInt64(i * 8, Endian.little)],
        [2, 1, 2, 2, 1, 1],
      );
      expect(
        [
          for (var offset = 48; offset < voices.lengthInBytes; offset += 4)
            voices.getFloat32(offset, Endian.little),
        ],
        [1.25, 1.5, 2.25, 2.5, 1.75, 2.75],
      );
    },
  );
}
