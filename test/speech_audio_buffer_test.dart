import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/services/tts/speech_audio_buffer.dart';

void main() {
  late SpeechAudioBuffer<String> buffer;
  late List<String> requests, discarded;
  late Map<String, Completer<String>> renders;
  setUp(() {
    requests = [];
    discarded = [];
    renders = {};
    buffer = SpeechAudioBuffer(
      render: (text) {
        requests.add(text);
        return (renders[text] = Completer<String>()).future;
      },
      discard: discarded.add,
    );
  });
  Future<void> finish(String text) async {
    renders[text]!.complete('$text.wav');
    await Future<void>.delayed(Duration.zero);
  }

  test('shares pending synthesis instead of rendering next twice', () async {
    final ahead = buffer.obtain('next', ahead: true);
    final spoken = buffer.obtain('next');
    expect(identical(ahead, spoken), isTrue);
    await finish('next');
    expect(await spoken, 'next.wav');
    expect(await buffer.obtain('next'), 'next.wav');
    expect(requests, ['next']);
  });

  test('current text takes priority over queued look-ahead', () async {
    final old = buffer.obtain('old');
    final next = buffer.obtain('next', ahead: true);
    final current = buffer.obtain('current');
    expect(await next, isNull);
    expect(requests, ['old']);
    await finish('old');
    expect(requests, ['old', 'current']);
    await finish('current');
    expect(await old, 'old.wav');
    expect(await current, 'current.wav');
  });

  test('cancel resolves immediately and discards late audio', () async {
    final old = buffer.obtain('old');
    final next = buffer.obtain('next', ahead: true);
    buffer.clear();
    expect(await old, isNull);
    expect(await next, isNull);
    final fresh = buffer.obtain('fresh');
    await finish('old');
    expect(discarded, ['old.wav']);
    expect(requests, ['old', 'fresh']);
    await finish('fresh');
    expect(await fresh, 'fresh.wav');
  });

  test('same text after a cancellation is a fresh request', () async {
    final old = buffer.obtain('same');
    buffer.clear();
    final fresh = buffer.obtain('same');
    await finish('same');
    expect(await old, isNull);
    expect(requests, ['same', 'same']);
    await finish('same');
    expect(await fresh, 'same.wav');
  });

  test('cache and speculative backlog stay bounded', () async {
    for (var i = 0; i < 8; i++) {
      final rendered = buffer.obtain('$i');
      await finish('$i');
      await rendered;
    }
    expect(discarded.length, 5);
    final active = buffer.obtain('active');
    final waiting = <Future<String?>>[];
    for (var i = 0; i < 100; i++) {
      waiting.add(buffer.obtain('ahead$i', ahead: true));
    }
    await finish('active');
    await active;
    expect(requests.last, 'ahead99');
    await finish('ahead99');
    final results = await Future.wait(waiting);
    expect(results.where((value) => value != null), ['ahead99.wav']);
    buffer.clear();
    expect(discarded.length, requests.length);
  });

  test('failed synthesis can be retried', () async {
    final failed = buffer.obtain('retry');
    final assertion = expectLater(failed, throwsStateError);
    renders['retry']!.completeError(StateError('failed'));
    await assertion;
    final retry = buffer.obtain('retry');
    await finish('retry');
    expect(await retry, 'retry.wav');
  });
}
