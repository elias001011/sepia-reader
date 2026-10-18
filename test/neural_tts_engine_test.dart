import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/services/tts/neural_tts_engine_io.dart';
import 'package:sepia_reader/services/tts/voice_catalog.dart';
import 'package:sepia_reader/services/tts/voice_store_io.dart';

class TestOutput implements SpeechAudioOutput {
  final events = StreamController<void>.broadcast();
  final played = <String>[];
  String? source;
  Completer<void>? loading;
  int disposed = 0;
  @override
  Stream<void> get completed => events.stream;
  @override
  Future<void> prepare() async {}
  @override
  Future<void> setSource(String path) async {
    source = path;
    await loading?.future;
  }

  @override
  Future<void> resume() async => played.add(source!);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {
    disposed++;
  }
}

void main() {
  late Directory temp;
  late NeuralTtsEngine engine;
  late TestOutput output;
  late Map<String, Completer<String>> synthesis;
  late List<({String text, double rate})> requests;
  late VoiceStore store;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('sepia-tts-test-');
    synthesis = {};
    requests = [];
    output = TestOutput();
    store = VoiceStore();
    final pack = voicePacks.first;
    engine = NeuralTtsEngine.testing(
      pack: pack,
      voice: pack.voices.first,
      store: store,
      output: output,
      synthesize: (text, rate) {
        requests.add((text: text, rate: rate));
        return (synthesis[text] = Completer<String>()).future;
      },
    );
  });
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<String> render(String text) async {
    final file = File('${temp.path}/${requests.length}.wav');
    await file.writeAsString('audio');
    synthesis[text]!.complete(file.path);
    await settle();
    return file.path;
  }

  tearDown(() async {
    await engine.release();
    // Complete a cancelled test renderer so its result is cleaned up, too.
    for (final entry in synthesis.entries) {
      if (!entry.value.isCompleted) {
        final file = File('${temp.path}/late.wav');
        await file.writeAsString('late');
        entry.value.complete(file.path);
      }
    }
    await settle();
    await output.events.close();
    await temp.delete(recursive: true);
  });

  test(
    'renders current first, then next during playback, with no duplicate',
    () async {
      final current = engine.speakWithLookAhead('current', 'next');
      await settle();
      expect(requests.map((r) => r.text), ['current']);
      final first = await render('current');
      expect(output.played, [first]);
      expect(requests.map((r) => r.text), ['current', 'next']);
      final next = await render('next');
      output.events.add(null);
      await current;
      final following = engine.speak('next');
      await settle();
      expect(output.played, [first, next]);
      expect(requests.length, 2);
      output.events.add(null);
      await following;
    },
  );

  test(
    'pause during synthesis returns promptly and late audio never plays',
    () async {
      final spoken = engine.speak('cancelled');
      await settle();
      await engine.stop();
      await spoken;
      final path = await render('cancelled');
      expect(output.played, isEmpty);
      expect(File(path).existsSync(), isFalse);
    },
  );

  test(
    'stop during source preparation prevents resume and look-ahead',
    () async {
      output.loading = Completer<void>();
      final spoken = engine.speakWithLookAhead('loading', 'obsolete');
      await settle();
      await render('loading');
      final stopped = engine.stop();
      output.loading!.complete();
      await Future.wait([spoken, stopped]);
      expect(output.played, isEmpty);
      expect(requests.map((r) => r.text), ['loading']);
    },
  );

  test('speed change discards in-flight look-ahead at old speed', () async {
    final current = engine.speakWithLookAhead('current', 'next');
    await settle();
    await render('current');
    await engine.configure(rate: 1.5, pitch: 1);
    await current;
    final fresh = engine.speak('next');
    await settle();
    final obsolete = await render('next');
    expect(File(obsolete).existsSync(), isFalse);
    expect(requests.last.rate, 1.5);
    final correct = await render('next');
    expect(output.played.last, correct);
    output.events.add(null);
    await fresh;
  });

  test('release disposes output and discards unfinished synthesis', () async {
    final spoken = engine.speak('release');
    await settle();
    await engine.release();
    await spoken;
    final path = await render('release');
    expect(output.played, isEmpty);
    expect(output.disposed, 1);
    expect(File(path).existsSync(), isFalse);
  });
}
