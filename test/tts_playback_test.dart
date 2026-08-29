import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/models/library_document.dart';
import 'package:sepia_reader/services/document_sections.dart';
import 'package:sepia_reader/services/tts/tts_engine.dart';
import 'package:sepia_reader/services/tts/tts_playback.dart';

/// A speech engine that records what it was asked to say and only finishes an
/// utterance when the test says so, so the queue's behaviour mid-sentence is
/// observable.
class FakeEngine extends TtsEngine {
  final spoken = <String>[];
  final configured = <({String? voiceId, double rate, double pitch})>[];
  int prepareCalls = 0;
  int releaseCalls = 0;
  Completer<void>? _current;

  @override
  String get label => 'fake';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> prepare() async => prepareCalls++;

  @override
  Future<List<TtsVoice>> availableVoices() async => const [];

  @override
  Future<void> configure({
    String? voiceId,
    required double rate,
    required double pitch,
  }) async => configured.add((voiceId: voiceId, rate: rate, pitch: pitch));

  final primed = <String>[];

  @override
  Future<void> prime(String text) async => primed.add(text);

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
    final completer = Completer<void>();
    _current = completer;
    await completer.future;
  }

  @override
  Future<void> stop() async => _finish();

  @override
  Future<void> release() async {
    releaseCalls++;
    _finish();
  }

  void _finish() {
    final pending = _current;
    _current = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  /// Lets the utterance currently in flight finish.
  Future<void> finishUtterance() async {
    _finish();
    await Future<void>.delayed(Duration.zero);
  }

  bool get isSpeaking => _current != null;
}

LibraryDocument fic() => LibraryDocument(
  id: 'd',
  title: 'Fic',
  content: '''
# Capítulo um

Primeira frase do um.

Segunda frase do um.

# Capítulo dois

Primeira frase do dois.

Segunda frase do dois.
''',
  extension: 'md',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('ler um capítulo fala só aquele capítulo, na ordem', () async {
    final engine = FakeEngine();
    final controller = TtsPlaybackController(engine: engine);
    final sections = sectionsOf(fic());
    final chapterTwo = sections.firstWhere((s) => s.title == 'Capítulo dois');

    await controller.start(
      document: fic(),
      section: chapterTwo,
      voiceId: 'v1',
      rate: 1.25,
      pitch: 0.9,
    );

    expect(engine.prepareCalls, greaterThan(0));
    expect(engine.configured.single.voiceId, 'v1');
    expect(engine.configured.single.rate, 1.25);
    expect(engine.configured.single.pitch, 0.9);
    expect(controller.isPlaying, isTrue);
    expect(controller.sectionTitle, 'Capítulo dois');

    // Drain the queue.
    for (var i = 0; i < 10 && controller.isActive; i++) {
      await engine.finishUtterance();
    }

    expect(engine.spoken, [
      'Capítulo dois',
      'Primeira frase do dois.',
      'Segunda frase do dois.',
    ]);
    expect(engine.spoken.join(' '), isNot(contains('do um')));
    expect(controller.isActive, isFalse, reason: 'stops at the end');
  });

  test('ler tudo cobre o documento inteiro', () async {
    final engine = FakeEngine();
    final controller = TtsPlaybackController(engine: engine);
    final sections = sectionsOf(fic());

    await controller.start(
      document: fic(),
      section: DocumentSection(
        title: 'tudo',
        level: 0,
        startChunk: 0,
        endChunk: sections.last.endChunk,
      ),
      voiceId: null,
      rate: 1,
      pitch: 1,
    );
    for (var i = 0; i < 20 && controller.isActive; i++) {
      await engine.finishUtterance();
    }
    expect(engine.spoken, [
      'Capítulo um',
      'Primeira frase do um.',
      'Segunda frase do um.',
      'Capítulo dois',
      'Primeira frase do dois.',
      'Segunda frase do dois.',
    ]);
  });

  test('pausar para na frase atual e continuar repete essa frase', () async {
    final engine = FakeEngine();
    final controller = TtsPlaybackController(engine: engine);
    final sections = sectionsOf(fic());

    await controller.start(
      document: fic(),
      section: sections.first,
      voiceId: null,
      rate: 1,
      pitch: 1,
    );
    await engine.finishUtterance(); // heading done, now on the first sentence
    expect(engine.spoken.last, 'Primeira frase do um.');

    await controller.pause();
    expect(controller.isPlaying, isFalse);
    expect(engine.isSpeaking, isFalse, reason: 'pause silences the engine');
    final spokenAtPause = engine.spoken.length;

    await controller.resume();
    await Future<void>.delayed(Duration.zero);
    expect(engine.spoken.length, spokenAtPause + 1);
    expect(
      engine.spoken.last,
      'Primeira frase do um.',
      reason: 'resume replays the sentence it stopped in, losing nothing',
    );
  });

  test('pular avança e volta sem sair do trecho', () async {
    final engine = FakeEngine();
    final controller = TtsPlaybackController(engine: engine);
    final sections = sectionsOf(fic());

    await controller.start(
      document: fic(),
      section: sections.first,
      voiceId: null,
      rate: 1,
      pitch: 1,
    );
    expect(controller.pieceIndex, 0);

    await controller.skip(1);
    await Future<void>.delayed(Duration.zero);
    expect(controller.pieceIndex, 1);
    expect(engine.spoken.last, 'Primeira frase do um.');

    await controller.skip(-1);
    await Future<void>.delayed(Duration.zero);
    expect(controller.pieceIndex, 0);

    // Cannot walk off either end.
    await controller.skip(-5);
    expect(controller.pieceIndex, 0);
    await controller.skip(99);
    expect(controller.pieceIndex, controller.pieceCount - 1);
  });

  test('o índice do trecho acompanha o pedaço do documento na tela', () async {
    final engine = FakeEngine();
    final controller = TtsPlaybackController(engine: engine);
    final sections = sectionsOf(fic());
    final chapterTwo = sections.firstWhere((s) => s.title == 'Capítulo dois');

    await controller.start(
      document: fic(),
      section: chapterTwo,
      voiceId: null,
      rate: 1,
      pitch: 1,
    );
    expect(controller.currentChunkIndex, chapterTwo.startChunk);
    await engine.finishUtterance();
    expect(
      controller.currentChunkIndex,
      greaterThan(chapterTwo.startChunk),
      reason: 'moving on to the next sentence moves the follow-along anchor',
    );
  });

  test('a próxima fala é preparada enquanto a atual toca', () async {
    final engine = FakeEngine();
    final controller = TtsPlaybackController(engine: engine);
    final sections = sectionsOf(fic());

    await controller.start(
      document: fic(),
      section: sections.first,
      voiceId: null,
      rate: 1,
      pitch: 1,
    );
    // The first sentence is still playing, and the second is already being
    // rendered — which is what keeps a neural voice from pausing between
    // every sentence.
    expect(engine.spoken.last, 'Capítulo um');
    expect(engine.primed, contains('Primeira frase do um.'));

    await engine.finishUtterance();
    expect(engine.primed, contains('Segunda frase do um.'));
  });

  test('um motor que não sobe reporta erro em vez de ficar mudo', () async {
    final controller = TtsPlaybackController(engine: BrokenEngine());
    final sections = sectionsOf(fic());
    await controller.start(
      document: fic(),
      section: sections.first,
      voiceId: null,
      rate: 1,
      pitch: 1,
    );
    expect(controller.error, isNotNull);
    expect(controller.isActive, isFalse);

    // And the player can be handed a working engine and carry on, which is
    // what the reader does when a neural voice fails: fall back, not fail.
    final engine = FakeEngine();
    await controller.useEngine(engine);
    await controller.start(
      document: fic(),
      section: sections.first,
      voiceId: null,
      rate: 1,
      pitch: 1,
    );
    expect(controller.error, isNull);
    expect(controller.isPlaying, isTrue);
    expect(engine.spoken, isNotEmpty);
  });

  test('uma falha no meio da fala não trava o player em "tocando"', () async {
    final controller = TtsPlaybackController(engine: MidSentenceFailEngine());
    final sections = sectionsOf(fic());
    await controller.start(
      document: fic(),
      section: sections.first,
      voiceId: null,
      rate: 1,
      pitch: 1,
    );

    // The speak() call fails from inside the fire-and-forget loop, after
    // start() has already returned. Let that loop run.
    for (var i = 0; i < 10 && controller.isPlaying; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(controller.error, isNotNull);
    expect(
      controller.isPlaying,
      isFalse,
      reason: 'sem isto o player fica "tocando" sem áudio nem mensagem',
    );
    expect(controller.isActive, isFalse);
  });

  test('parar libera o motor e zera o estado', () async {
    final engine = FakeEngine();
    final controller = TtsPlaybackController(engine: engine);
    final sections = sectionsOf(fic());
    await controller.start(
      document: fic(),
      section: sections.first,
      voiceId: null,
      rate: 1,
      pitch: 1,
    );
    await controller.release();
    expect(controller.isActive, isFalse);
    expect(controller.pieceCount, 0);
    expect(engine.releaseCalls, 1);
    expect(engine.isSpeaking, isFalse);
  });
}

/// An engine that starts fine but throws once asked to speak — a neural
/// backend that loses its audio route, or a platform voice that dies
/// partway through a chapter.
class MidSentenceFailEngine extends TtsEngine {
  @override
  String get label => 'mid-fail';
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<void> prepare() async {}
  @override
  Future<List<TtsVoice>> availableVoices() async => const [];
  @override
  Future<void> configure({
    String? voiceId,
    required double rate,
    required double pitch,
  }) async {}
  @override
  Future<void> prime(String text) async {}
  @override
  Future<void> speak(String text) async => throw StateError('audio route lost');
  @override
  Future<void> stop() async {}
  @override
  Future<void> release() async {}
}

/// An engine that cannot start — the shape of a neural voice whose model is
/// missing, whose native library will not load, or whose audio output is
/// unavailable.
class BrokenEngine extends TtsEngine {
  @override
  String get label => 'broken';
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<void> prepare() async => throw StateError('no model');
  @override
  Future<List<TtsVoice>> availableVoices() async => const [];
  @override
  Future<void> configure({
    String? voiceId,
    required double rate,
    required double pitch,
  }) async {}
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> release() async {}
}
