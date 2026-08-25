import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sepia_reader/services/tts/voice_catalog.dart';
import 'package:sepia_reader/services/tts/voice_store_io.dart';
import 'package:sepia_reader/services/tts/voice_store_types.dart';

/// Files a fake repository serves.
final _files = <String, List<int>>{
  'model.onnx': List<int>.generate(4096, (i) => i % 251),
  'tokens.txt': utf8.encode('a 1\nb 2\n'),
  'espeak-ng-data/pt_dict': List<int>.filled(1024, 7),
  'espeak-ng-data/phontab': List<int>.filled(512, 3),
};

http.Client fakeClient({
  Set<String> failOnce = const {},
  void Function(String path)? onFetch,
}) {
  final failed = <String>{};
  return MockClient.streaming((request, bodyStream) async {
    final path = request.url.path;
    if (path.startsWith('/api/models/')) {
      final listing = [
        for (final entry in _files.entries)
          {'type': 'file', 'path': entry.key, 'size': entry.value.length},
        {'type': 'directory', 'path': 'espeak-ng-data'},
      ];
      final body = utf8.encode(jsonEncode(listing));
      return http.StreamedResponse(Stream.value(body), 200);
    }
    final marker = '/resolve/main/';
    final index = path.indexOf(marker);
    final name = Uri.decodeFull(path.substring(index + marker.length));
    onFetch?.call(name);
    if (failOnce.contains(name) && failed.add(name)) {
      return http.StreamedResponse(const Stream.empty(), 500);
    }
    final bytes = _files[name];
    if (bytes == null) return http.StreamedResponse(const Stream.empty(), 404);
    return http.StreamedResponse(Stream.value(bytes), 200);
  });
}

const testVoice = NeuralVoice(
  id: 'piper/test',
  label: 'Teste',
  language: 'pt-BR',
  kind: NeuralVoiceKind.piper,
  repo: 'fake/voice',
  approxBytes: 6000,
  modelFile: 'model.onnx',
);

void main() {
  late Directory sandbox;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sandbox = Directory.systemTemp.createTempSync('sepia-voices');
    // path_provider has no implementation in a widget test; point it at a
    // real temp directory so the store exercises the actual filesystem.
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => sandbox.path,
    );
  });

  tearDown(() {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  test('instala todos os arquivos e marca a voz como instalada', () async {
    final store = VoiceStore(client: fakeClient());
    expect(await store.isInstalled(testVoice), isFalse);

    final seen = <VoiceInstallProgress>[];
    await store.install(testVoice, onProgress: seen.add);

    expect(await store.isInstalled(testVoice), isTrue);
    final dir = await store.voiceDirectory(testVoice);
    for (final entry in _files.entries) {
      final file = File('${dir.path}/${entry.key}');
      expect(file.existsSync(), isTrue, reason: 'faltou ${entry.key}');
      expect(file.lengthSync(), entry.value.length);
    }
    expect(seen, isNotEmpty);
    expect(seen.last.filesDone, _files.length);
    expect(seen.last.fraction, 1.0);
  });

  test('reinstalar não baixa de novo o que já está certo', () async {
    final firstFetches = <String>[];
    await VoiceStore(client: fakeClient(onFetch: firstFetches.add))
        .install(testVoice);
    expect(firstFetches.toSet(), _files.keys.toSet());

    final secondFetches = <String>[];
    await VoiceStore(client: fakeClient(onFetch: secondFetches.add))
        .install(testVoice);
    expect(
      secondFetches,
      isEmpty,
      reason: 'um download interrompido deve retomar, não recomeçar',
    );
  });

  test('arquivo truncado é rebaixado em vez de aceito', () async {
    final store = VoiceStore(client: fakeClient());
    await store.install(testVoice);
    final dir = await store.voiceDirectory(testVoice);
    final model = File('${dir.path}/model.onnx');
    model.writeAsBytesSync(List<int>.filled(10, 0));

    final fetches = <String>[];
    await VoiceStore(client: fakeClient(onFetch: fetches.add))
        .install(testVoice);
    expect(fetches, contains('model.onnx'));
    expect(model.lengthSync(), _files['model.onnx']!.length);
  });

  test('uma falha de rede não deixa arquivo pela metade', () async {
    final store = VoiceStore(client: fakeClient(failOnce: {'model.onnx'}));
    await expectLater(
      store.install(testVoice),
      throwsA(isA<HttpException>()),
    );
    final dir = await store.voiceDirectory(testVoice);
    expect(File('${dir.path}/model.onnx').existsSync(), isFalse);
    expect(File('${dir.path}/model.onnx.part').existsSync(), isFalse);
    expect(
      await store.isInstalled(testVoice),
      isFalse,
      reason: 'sem manifesto, uma instalação incompleta não conta como pronta',
    );
  });

  test('cancelar interrompe e a voz não fica instalada', () async {
    final store = VoiceStore(client: fakeClient());
    await expectLater(
      store.install(testVoice, shouldCancel: () => true),
      throwsA(isA<VoiceInstallCancelled>()),
    );
    expect(await store.isInstalled(testVoice), isFalse);
  });

  test('remover apaga tudo do aparelho', () async {
    final store = VoiceStore(client: fakeClient());
    await store.install(testVoice);
    expect(await store.installedSize(testVoice), greaterThan(0));

    await store.remove(testVoice);

    expect(await store.isInstalled(testVoice), isFalse);
    expect((await store.voiceDirectory(testVoice)).existsSync(), isFalse);
  });

  test('vozes que compartilham o modelo compartilham a instalação', () {
    final kokoro = neuralVoices.where((v) => v.isKokoro).toList();
    expect(kokoro, hasLength(3));
    expect(kokoro.map((v) => v.repo).toSet(), hasLength(1));
    expect(voicesSharing(kokoro.first), hasLength(3));
    // Distinct speakers inside that one model.
    expect(kokoro.map((v) => v.speakerId).toSet(), {42, 43, 44});
    // And a Piper voice shares with nobody.
    final piper = neuralVoices.firstWhere((v) => !v.isKokoro);
    expect(voicesSharing(piper), hasLength(1));
  });
}
