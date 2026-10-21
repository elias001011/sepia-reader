import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sepia_reader/services/tts/voice_catalog.dart';
import 'package:sepia_reader/services/tts/voice_store_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  final style = jsonEncode({
    'style_ttl': {
      'dims': [1, 1, 1],
      'data': [0.1],
    },
    'style_dp': {
      'dims': [1, 1, 1],
      'data': [0.2],
    },
  });
  final files = {
    'onnx/model.onnx': [1, 2, 3],
    'onnx/unicode_indexer.json': utf8.encode('[0, -1, 2]'),
    'voice_styles/M1.json': utf8.encode(style),
    'voice_styles/M2.json': utf8.encode(style),
  };
  final pack = VoicePack(
    id: 'supertonic/test',
    label: 'Test',
    kind: NeuralVoiceKind.supertonic,
    repo: 'test/model',
    revision: 'fixed-revision',
    approxBytes: 10,
    modelFile: 'onnx/model.onnx',
    voices: const [],
    files: [
      for (final f in files.entries)
        VoicePackFile(
          f.key,
          f.value.length,
          sha256.convert(f.value).toString(),
        ),
    ],
  );
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sepia-download-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => dir.path,
        );
  });
  tearDown(() => dir.delete(recursive: true));

  VoiceStore store({bool corrupt = false, List<String>? fetches}) => VoiceStore(
    client: MockClient((request) async {
      expect(request.url.path, contains('/resolve/fixed-revision/'));
      final path = request.url.path.split('/resolve/fixed-revision/').last;
      fetches?.add(path);
      return http.Response.bytes(
        corrupt && path.endsWith('.onnx') ? [9, 9, 9] : files[path]!,
        200,
      );
    }),
  );

  test(
    'pinned install fetches only curated assets and produces binary tables',
    () async {
      final requests = <String>[];
      final storage = store(fetches: requests);
      await storage.install(pack);
      expect(requests.toSet(), files.keys.toSet());
      expect(await storage.isInstalled(pack), isTrue);
      final folder = await storage.packDirectory(pack);
      await File('${folder.path}/voice.bin').delete();
      expect(await storage.isInstalled(pack), isFalse);
      requests.clear();
      await storage.install(pack);
      expect(requests, isEmpty);
      expect(await storage.isInstalled(pack), isTrue);
    },
  );

  test(
    'equal-size corrupted model is rejected and never marked installed',
    () async {
      final storage = store(corrupt: true);
      await expectLater(storage.install(pack), throwsA(isA<HttpException>()));
      expect(await storage.isInstalled(pack), isFalse);
    },
  );

  test(
    'resuming verifies existing weights before trusting their size',
    () async {
      final storage = store();
      await storage.install(pack);
      final folder = await storage.packDirectory(pack);
      await File('${folder.path}/onnx/model.onnx').writeAsBytes([9, 9, 9]);
      final requests = <String>[];
      await store(fetches: requests).install(pack);
      expect(requests, ['onnx/model.onnx']);
      expect(await File('${folder.path}/onnx/model.onnx').readAsBytes(), [
        1,
        2,
        3,
      ]);
    },
  );
}
