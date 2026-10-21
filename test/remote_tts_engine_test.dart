import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sepia_reader/services/tts/remote_speech_client.dart';
import 'package:sepia_reader/services/tts/remote_speech_config.dart';
import 'package:sepia_reader/services/tts/remote_tts_engine.dart';

import 'remote_speech_client_test.dart' show testWav;

class Output implements RemoteAudioOutput {
  final events = StreamController<void>.broadcast();
  final played = <SpeechRecording>[];
  int disposed = 0;
  @override
  Stream<void> get completed => events.stream;
  @override
  Future<void> prepare() async {}
  @override
  Future<void> play(SpeechRecording audio) async {
    played.add(audio);
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {
    disposed++;
  }
}

void main() {
  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  for (final prefetch in [false, true]) {
    test(
      'remote queue handles look-ahead=$prefetch without duplicate billing requests',
      () async {
        final output = Output();
        final requested = <String>[];
        final client = MockClient((request) async {
          requested.add(jsonDecode(request.body)['text'] as String);
          return http.Response.bytes(testWav(requested.length), 200);
        });
        final config = RemoteSpeechConfig(
          provider: 'sepia',
          voice: 'M2',
          consent: true,
          serverUrl: 'https://example.org',
          prefetch: prefetch,
        );
        final engine = RemoteTtsEngine(
          loadConfig: () async => config,
          output: output,
          clientFactory: (c) => RemoteSpeechClient(c, client: client),
        );
        final current = engine.speakWithLookAhead('current', 'next');
        await settle();
        expect(requested, prefetch ? ['current', 'next'] : ['current']);
        expect(output.played, hasLength(1));
        output.events.add(null);
        await current;
        final next = engine.speak('next');
        await settle();
        expect(requested, ['current', 'next']);
        expect(output.played, hasLength(2));
        output.events.add(null);
        await next;
        await engine.release();
        expect(output.disposed, 1);
        client.close();
        await output.events.close();
      },
    );
  }
  test('pause aborts the request and a late response never plays', () async {
    final output = Output();
    final pending = Completer<http.Response>();
    final called = Completer<void>();
    final client = MockClient((_) {
      called.complete();
      return pending.future;
    });
    const config = RemoteSpeechConfig(apiKey: 'key', consent: true);
    final engine = RemoteTtsEngine(
      loadConfig: () async => config,
      output: output,
      clientFactory: (c) => RemoteSpeechClient(c, client: client),
    );
    final speaking = engine.speak('obsolete');
    await called.future;
    await engine.stop();
    await speaking;
    pending.complete(http.Response.bytes(testWav(), 200));
    await settle();
    expect(output.played, isEmpty);
    await engine.release();
    client.close();
    await output.events.close();
  });
  test(
    'changing rate invalidates cached audio and keeps current text',
    () async {
      final output = Output();
      final rates = <String>[];
      final client = MockClient((request) async {
        rates.add(request.body);
        return http.Response.bytes(testWav(), 200);
      });
      const config = RemoteSpeechConfig(apiKey: 'key', consent: true);
      final engine = RemoteTtsEngine(
        loadConfig: () async => config,
        output: output,
        clientFactory: (c) => RemoteSpeechClient(c, client: client),
      );
      final first = engine.speak('same');
      await settle();
      await engine.configure(rate: 1.5, pitch: 1);
      await first;
      final second = engine.speak('same');
      await settle();
      expect(rates, hasLength(2));
      expect(rates.last, contains('rate="50%"'));
      output.events.add(null);
      await second;
      await engine.release();
      client.close();
      await output.events.close();
    },
  );
}
