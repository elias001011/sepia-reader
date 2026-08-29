import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/library_document.dart';
import '../../widgets/markdown_view.dart';
import '../document_sections.dart';
import 'tts_engine.dart';

enum TtsPlaybackState { idle, preparing, playing, paused }

/// One thing to say, and where in the document it came from.
class SpokenPiece {
  const SpokenPiece({required this.chunkIndex, required this.text});
  final int chunkIndex;
  final String text;
}

/// Drives listening: turns a chosen chapter into a queue of utterances, feeds
/// them to the engine one at a time, and keeps track of where in the document
/// the voice currently is so the reader can follow along.
///
/// Pause is implemented as "stop after the utterance in flight, and replay it
/// on resume" rather than as a real mid-sentence pause. Platform pause
/// support is inconsistent — Android honours it, the browser's
/// `speechSynthesis.pause()` is unreliable across engines, and a neural
/// backend synthesising ahead of playback has no equivalent at all. Restarting
/// the current sentence behaves the same everywhere and never loses the place.
class TtsPlaybackController extends ChangeNotifier {
  // The field is reassignable (useEngine swaps backends) and private, so it
  // can be neither final nor a named initializing formal.
  // ignore: prefer_initializing_formals
  TtsPlaybackController({required TtsEngine engine}) : _engine = engine;

  TtsEngine _engine;
  TtsPlaybackState _state = TtsPlaybackState.idle;
  List<SpokenPiece> _pieces = const [];
  int _index = 0;
  String? _documentId;
  String? _sectionTitle;
  String? _error;

  /// Guards the playback loop so a rapid stop/start cannot leave two loops
  /// racing to advance the same index.
  int _generation = 0;

  TtsPlaybackState get state => _state;
  bool get isActive => _state != TtsPlaybackState.idle;
  bool get isPlaying => _state == TtsPlaybackState.playing;
  String? get sectionTitle => _sectionTitle;
  String? get documentId => _documentId;
  String? get error => _error;
  int get pieceCount => _pieces.length;
  int get pieceIndex => _index;

  /// Chunk the voice is currently reading, so the reader can scroll to it.
  int? get currentChunkIndex =>
      _index < _pieces.length ? _pieces[_index].chunkIndex : null;

  double get progress =>
      _pieces.isEmpty ? 0 : (_index / _pieces.length).clamp(0.0, 1.0);

  /// Swaps the backend (the user picked a different engine in settings).
  Future<void> useEngine(TtsEngine engine) async {
    if (identical(engine, _engine)) return;
    await stop();
    await _engine.release();
    _engine = engine;
  }

  /// Builds the queue for [section] of [document] and starts speaking.
  Future<void> start({
    required LibraryDocument document,
    required DocumentSection section,
    required String? voiceId,
    required double rate,
    required double pitch,
  }) async {
    await stop();
    _error = null;
    _state = TtsPlaybackState.preparing;
    _documentId = document.id;
    _sectionTitle = section.level == 0 ? null : section.title;
    _pieces = _buildPieces(document, section);
    _index = 0;
    notifyListeners();

    if (_pieces.isEmpty) {
      _state = TtsPlaybackState.idle;
      notifyListeners();
      return;
    }
    try {
      await _engine.prepare();
      await _engine.configure(voiceId: voiceId, rate: rate, pitch: pitch);
    } catch (error) {
      _error = '$error';
      _state = TtsPlaybackState.idle;
      notifyListeners();
      return;
    }
    _state = TtsPlaybackState.playing;
    notifyListeners();
    unawaited(_run(++_generation));
  }

  static List<SpokenPiece> _buildPieces(
    LibraryDocument document,
    DocumentSection section,
  ) {
    final chunks = chunksForDocument(document);
    final pieces = <SpokenPiece>[];
    final end = section.endChunk.clamp(0, chunks.length);
    for (var i = section.startChunk.clamp(0, chunks.length); i < end; i++) {
      final spoken = document.isMarkdown
          ? speakableText(chunks[i])
          : chunks[i].trim();
      for (final utterance in utterancesFor(spoken)) {
        pieces.add(SpokenPiece(chunkIndex: i, text: utterance));
      }
    }
    return pieces;
  }

  Future<void> _run(int generation) async {
    while (generation == _generation &&
        _state == TtsPlaybackState.playing &&
        _index < _pieces.length) {
      final piece = _pieces[_index];
      // Ask the engine to work ahead on the next sentence while this one is
      // still playing. A neural backend has to synthesise before it can play,
      // so without this there is a gap before every single sentence; engines
      // that speak directly ignore it.
      if (_index + 1 < _pieces.length) {
        unawaited(_engine.prime(_pieces[_index + 1].text));
      }
      try {
        await _engine.speak(piece.text);
      } catch (error) {
        // An interruption — pause, skip, stop, a new chapter — can make the
        // engine reject the utterance in flight. That is not a failure, and a
        // newer generation is already in charge; bail out like every other
        // transition in this loop.
        if (generation != _generation) return;
        debugPrint('sepia: speaking failed: $error');
        // A real mid-chapter failure: tear the session down the same way
        // stop() does (engine stopped, queue cleared) and then surface the
        // error, so the player bar cannot linger showing a dead pause button.
        await stop();
        _error = '$error';
        notifyListeners();
        return;
      }
      // A stop or pause landed while this utterance was in flight: leave the
      // index where it is so resume replays exactly this sentence.
      if (generation != _generation || _state != TtsPlaybackState.playing) {
        return;
      }
      _index++;
      notifyListeners();
    }
    if (generation != _generation) return;
    if (_index >= _pieces.length) await stop();
  }

  Future<void> pause() async {
    if (_state != TtsPlaybackState.playing) return;
    _state = TtsPlaybackState.paused;
    _generation++;
    notifyListeners();
    await _engine.stop();
  }

  Future<void> resume() async {
    if (_state != TtsPlaybackState.paused) return;
    _state = TtsPlaybackState.playing;
    notifyListeners();
    unawaited(_run(++_generation));
  }

  Future<void> skip(int delta) async {
    if (_pieces.isEmpty) return;
    final wasPlaying = _state == TtsPlaybackState.playing;
    _generation++;
    await _engine.stop();
    _index = (_index + delta).clamp(0, _pieces.length - 1);
    notifyListeners();
    if (wasPlaying) {
      _state = TtsPlaybackState.playing;
      unawaited(_run(++_generation));
    }
  }

  /// Jumps playback to whichever utterance starts [chunkIndex].
  Future<void> jumpToChunk(int chunkIndex) async {
    final target = _pieces.indexWhere(
      (piece) => piece.chunkIndex >= chunkIndex,
    );
    if (target == -1) return;
    await skip(target - _index);
  }

  Future<void> stop() async {
    _generation++;
    final wasActive = _state != TtsPlaybackState.idle;
    _state = TtsPlaybackState.idle;
    _index = 0;
    _pieces = const [];
    _documentId = null;
    _sectionTitle = null;
    if (wasActive) notifyListeners();
    await _engine.stop();
  }

  /// Stops and hands back whatever the engine was holding. The reader calls
  /// this on the way out so an idle document is not keeping a speech backend
  /// (and, for a neural engine, its model) alive in memory.
  Future<void> release() async {
    await stop();
    await _engine.release();
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_engine.release());
    super.dispose();
  }
}
