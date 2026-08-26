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

const testPack = VoicePack(
  id: 'piper/test',
  label: 'Teste',
  kind: NeuralVoiceKind.piper,
  repo: 'fake/voice',
  approxBytes: 6000,
  modelFile: 'model.onnx',
  voices: [
    NeuralVoice(
      id: 'piper/test',
      label: 'Teste',
      language: 'pt-BR',
      speakerId: 0,
    ),
  ],
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
    expect(await store.isInstalled(testPack), isFalse);

    final seen = <VoiceInstallProgress>[];
    await store.install(testPack, onProgress: seen.add);

    expect(await store.isInstalled(testPack), isTrue);
    final dir = await store.packDirectory(testPack);
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
        .install(testPack);
    expect(firstFetches.toSet(), _files.keys.toSet());

    final secondFetches = <String>[];
    await VoiceStore(client: fakeClient(onFetch: secondFetches.add))
        .install(testPack);
    expect(
      secondFetches,
      isEmpty,
      reason: 'um download interrompido deve retomar, não recomeçar',
    );
  });

  test('arquivo truncado é rebaixado em vez de aceito', () async {
    final store = VoiceStore(client: fakeClient());
    await store.install(testPack);
    final dir = await store.packDirectory(testPack);
    final model = File('${dir.path}/model.onnx');
    model.writeAsBytesSync(List<int>.filled(10, 0));

    final fetches = <String>[];
    await VoiceStore(client: fakeClient(onFetch: fetches.add))
        .install(testPack);
    expect(fetches, contains('model.onnx'));
    expect(model.lengthSync(), _files['model.onnx']!.length);
  });

  test('uma falha de rede não deixa arquivo pela metade', () async {
    final store = VoiceStore(client: fakeClient(failOnce: {'model.onnx'}));
    await expectLater(
      store.install(testPack),
      throwsA(isA<HttpException>()),
    );
    final dir = await store.packDirectory(testPack);
    expect(File('${dir.path}/model.onnx').existsSync(), isFalse);
    expect(File('${dir.path}/model.onnx.part').existsSync(), isFalse);
    expect(
      await store.isInstalled(testPack),
      isFalse,
      reason: 'sem manifesto, uma instalação incompleta não conta como pronta',
    );
  });

  test('cancelar interrompe e a voz não fica instalada', () async {
    final store = VoiceStore(client: fakeClient());
    await expectLater(
      store.install(testPack, shouldCancel: () => true),
      throwsA(isA<VoiceInstallCancelled>()),
    );
    expect(await store.isInstalled(testPack), isFalse);
  });

  test('remover apaga tudo do aparelho', () async {
    final store = VoiceStore(client: fakeClient());
    await store.install(testPack);
    expect(await store.installedSize(testPack), greaterThan(0));

    await store.remove(testPack);

    expect(await store.isInstalled(testPack), isFalse);
    expect((await store.packDirectory(testPack)).existsSync(), isFalse);
  });

  test('o Kokoro é um download só, com várias vozes dentro', () {
    final kokoro = voicePacks.where((pack) => pack.isKokoro).toList();
    expect(
      kokoro,
      hasLength(1),
      reason: 'um modelo de 400 MB não pode aparecer uma vez por voz',
    );
    expect(kokoro.single.voices.length, greaterThan(3));
    // The Brazilian speakers, at the ids sherpa-onnx packed them at.
    final brazilian = kokoro.single.voices
        .where((voice) => voice.language == 'pt-BR')
        .toList();
    expect(brazilian.map((voice) => voice.speakerId).toSet(), {42, 43, 44});
    // Every speaker id is distinct, or two voices would sound identical.
    final ids = kokoro.single.voices.map((voice) => voice.speakerId).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('cada pacote Piper é uma voz só', () {
    for (final pack in voicePacks.where((pack) => !pack.isKokoro)) {
      expect(pack.voices, hasLength(1), reason: pack.id);
      expect(pack.voices.single.speakerId, 0, reason: pack.id);
    }
  });

  test('nenhum identificador de voz se repete no catálogo', () {
    final ids = allNeuralVoices.map((voice) => voice.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(resolveVoice(id), isNotNull);
    }
    expect(resolveVoice('nada/disso'), isNull);
  });

  test('todo pacote tem repositório e arquivo de modelo próprios', () {
    final repos = <String>{};
    for (final pack in voicePacks) {
      expect(pack.repo, isNotEmpty, reason: pack.id);
      expect(pack.modelFile, endsWith('.onnx'), reason: pack.id);
      expect(pack.voices, isNotEmpty, reason: pack.id);
      expect(repos.add(pack.repo), isTrue, reason: 'repo repetido: ${pack.repo}');
      if (pack.isKokoro) {
        expect(pack.voicesFile, isNotNull, reason: pack.id);
      }
    }
  });
}
