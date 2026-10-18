import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'tts_engine.dart';
import 'speech_audio_buffer.dart';
import 'voice_catalog.dart';
import 'voice_store_io.dart';

/// A request sent to the synthesis isolate.
class _SynthesisRequest {
  const _SynthesisRequest({
    required this.id,
    required this.text,
    required this.speakerId,
    required this.speed,
    required this.outputPath,
  });
  final int id;
  final String text;
  final int speakerId;
  final double speed;
  final String outputPath;
}

class _SynthesisReply {
  const _SynthesisReply({required this.id, this.path, this.error});
  final int id;
  final String? path;
  final String? error;
}

class _WorkerReady {
  const _WorkerReady();
}

class _WorkerBootstrap {
  const _WorkerBootstrap({required this.reply, required this.config});
  final SendPort reply;
  final Map<String, dynamic> config;
}

/// Audio output is separate from synthesis so cancellation can be verified
/// while either operation is pending, without a physical audio device.
abstract class SpeechAudioOutput {
  Stream<void> get completed;
  Future<void> prepare();
  Future<void> setSource(String path);
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

class _DeviceAudioOutput implements SpeechAudioOutput {
  final _player = AudioPlayer();
  @override
  Stream<void> get completed => _player.onPlayerComplete;
  @override
  Future<void> prepare() async {
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.speech,
        ),
      ),
    );
  }

  @override
  Future<void> setSource(String path) =>
      _player.setSource(DeviceFileSource(path));
  @override
  Future<void> resume() => _player.resume();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();
}

/// Speech from a neural model running on the device.
///
/// Synthesis happens in its own isolate. `OfflineTts.generate` is a blocking
/// FFI call that takes a noticeable fraction of a second per sentence even on
/// a quick phone; on the UI isolate that is a visibly frozen reader, so the
/// model lives in a worker and only file paths cross back.
///
/// The model is loaded on [prepare] and freed on [release], never at start-up:
/// a Piper voice holds tens of megabytes and Kokoro several hundred, and none
/// of that has any business being resident while somebody is only reading.
class NeuralTtsEngine extends TtsEngine {
  NeuralTtsEngine({
    required this.pack,
    required this.voice,
    required this.store,
  }) : _synthesizeOverride = null,
       _outputOverride = null;

  @visibleForTesting
  NeuralTtsEngine.testing({
    required this.pack,
    required this.voice,
    required this.store,
    Future<String> Function(String, double)? synthesize,
    required SpeechAudioOutput output,
  }) : _synthesizeOverride = synthesize,
       _outputOverride = output;

  final Future<String> Function(String, double)? _synthesizeOverride;
  final SpeechAudioOutput? _outputOverride;

  /// The downloaded model this voice comes out of. For Piper the pack holds
  /// exactly this voice; for Kokoro it holds dozens, and the voice is chosen
  /// per utterance by speaker id.
  final VoicePack pack;
  final NeuralVoice voice;
  final VoiceStore store;

  Isolate? _isolate;
  SendPort? _toWorker;
  ReceivePort? _fromWorker;
  Completer<void>? _workerExited;
  Object? _workerError;
  Directory? _scratch;

  SpeechAudioOutput? _player;
  final Map<int, Completer<String>> _pending = {};
  late final _audio = SpeechAudioBuffer<String>(
    render: _render,
    discard: _deleteRendered,
  );
  Future<void>? _preparing;
  Future<void>? _releasing;
  Future<void> _audioOperations = Future.value();
  int _epoch = 0;

  Future<void> _withPlayer(Future<void> Function() operation) {
    final result = _audioOperations.then((_) => operation());
    _audioOperations = result.catchError((Object _) {});
    return result;
  }

  int _nextId = 0;
  double _speed = 1;
  Completer<void>? _playback;
  StreamSubscription<void>? _completionSubscription;

  @override
  String get label => 'neural';

  @override
  bool get supportsPitch => false;

  @override
  Future<bool> isAvailable() => store.isInstalled(pack);

  @override
  Future<void> prepare() async {
    await _releasing;
    if (_completionSubscription != null) {
      if (_workerError != null) {
        throw StateError('speech worker failed: $_workerError');
      }
      return;
    }
    return _preparing ??= _prepare()
        .catchError((Object error, StackTrace stack) async {
          await _destroy();
          Error.throwWithStackTrace(error, stack);
        })
        .whenComplete(() => _preparing = null);
  }

  Future<void> _prepare() async {
    _workerError = null;
    if (_synthesizeOverride != null) {
      await _prepareOutput();
      return;
    }
    if (!await store.isInstalled(pack)) {
      throw StateError('the voice ${voice.id} is not installed');
    }
    final dir = await store.packDirectory(pack);
    final scratch = await Directory.systemTemp.createTemp('sepia-tts-');
    _scratch = scratch;

    final ready = Completer<void>();
    final exited = _workerExited = Completer<void>();
    final fromWorker = ReceivePort();
    _fromWorker = fromWorker;
    fromWorker.listen((message) {
      if (message is SendPort) {
        _toWorker = message;
        return;
      }
      if (message is _WorkerReady) {
        if (!ready.isCompleted) ready.complete();
        return;
      }
      if (message == null || message is List) {
        if (message == null && !exited.isCompleted) exited.complete();
        final error = StateError('speech worker exited: $message');
        _workerError = error;
        if (!ready.isCompleted) ready.completeError(error);
        for (final pending in _pending.values) {
          if (!pending.isCompleted) pending.completeError(error);
        }
        _pending.clear();
        return;
      }
      if (message is! _SynthesisReply) return;
      final completer = _pending.remove(message.id);
      if (completer == null || completer.isCompleted) {
        _deleteRendered(message.path);
        return;
      }
      if (message.error != null) {
        completer.completeError(StateError(message.error!));
      } else {
        completer.complete(message.path!);
      }
    });

    _isolate = await Isolate.spawn(
      _synthesisWorker,
      _WorkerBootstrap(
        reply: fromWorker.sendPort,
        config: _describeModel(dir.path),
      ),
      debugName: 'sepia-tts',
      errorsAreFatal: true,
      onError: fromWorker.sendPort,
      onExit: fromWorker.sendPort,
    );
    await ready.future.timeout(const Duration(seconds: 60));

    await _prepareOutput();
  }

  Future<void> _prepareOutput() async {
    final player = _player = _outputOverride ?? _DeviceAudioOutput();
    await player.prepare();
    _completionSubscription = player.completed.listen((_) {
      final playback = _playback;
      _playback = null;
      if (playback != null && !playback.isCompleted) playback.complete();
    });
  }

  /// The model description handed to the worker, as a plain map so none of
  /// the sherpa types have to cross the isolate boundary.
  Map<String, dynamic> _describeModel(String dirPath) {
    String at(String name) => '$dirPath/$name';
    if (pack.isKokoro) {
      return {
        'kind': 'kokoro',
        'model': at(pack.modelFile),
        'voices': at(pack.voicesFile!),
        'tokens': at(pack.tokensFile),
        'dataDir': at(pack.dataDir),
        'lexicon': pack.lexicon.map(at).join(','),
        'lang': voice.espeakLanguage,
      };
    }
    return {
      'kind': 'piper',
      'model': at(pack.modelFile),
      'tokens': at(pack.tokensFile),
      'dataDir': at(pack.dataDir),
    };
  }

  @override
  Future<List<TtsVoice>> availableVoices() async => [
    TtsVoice(id: voice.id, name: voice.label, locale: voice.language),
  ];

  @override
  Future<void> configure({
    String? voiceId,
    required double rate,
    required double pitch,
  }) async {
    if (rate != _speed) {
      await stop();
      _speed = rate.clamp(0.5, 2.0);
    }
  }

  Future<String> _render(String text) async {
    final epoch = _epoch;
    await prepare();
    if (epoch != _epoch) throw StateError('synthesis cancelled');
    if (_synthesizeOverride != null) return _synthesizeOverride(text, _speed);
    final id = _nextId++;
    final completer = Completer<String>();
    _pending[id] = completer;
    _toWorker!.send(
      _SynthesisRequest(
        id: id,
        text: text,
        speakerId: voice.speakerId,
        speed: _speed,
        outputPath: '${_scratch!.path}/$id.wav',
      ),
    );
    return completer.future;
  }

  void _deleteRendered(String? path) {
    if (path == null) return;
    final file = File(path);
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException catch (error) {
      debugPrint('sepia: could not remove temporary speech audio: $error');
    }
  }

  @override
  Future<void> prime(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _audio.obtain(text, ahead: true);
    } catch (error) {
      // Working ahead is an optimisation. If the failure is real, speak()
      // will hit it too and report it properly; there is nothing useful to
      // tell the reader about a sentence they have not reached yet.
      debugPrint('sepia: could not pre-render an utterance: $error');
    }
  }

  @override
  Future<void> speak(String text) => speakWithLookAhead(text, null);

  @override
  Future<void> speakWithLookAhead(String text, String? nextText) async {
    if (text.trim().isEmpty) return;
    final epoch = _epoch;
    await prepare();
    await _audioOperations;
    if (epoch != _epoch) return;
    final path = await _audio.obtain(text);
    if (epoch != _epoch || path == null) return;
    final playback = Completer<void>();
    await _withPlayer(() async {
      if (epoch != _epoch) return;
      _playback = playback;
      await _player!.setSource(path);
      if (epoch != _epoch) return;
      await _player!.resume();
      if (epoch == _epoch && nextText != null) unawaitedPrime(nextText);
    });
    if (epoch != _epoch) return;
    // A plugin/audio-route failure must not leave the reader waiting forever.
    try {
      await playback.future.timeout(Duration(seconds: 10 + text.length));
    } on TimeoutException {
      if (epoch != _epoch) return;
      await stop();
      throw StateError('audio playback did not complete');
    }
  }

  @override
  Future<void> stop() {
    _epoch++;
    return _withPlayer(() async {
      try {
        await _player?.stop();
      } finally {
        final playback = _playback;
        _playback = null;
        if (playback != null && !playback.isCompleted) playback.complete();
        _audio.clear();
      }
    });
  }

  @override
  Future<void> release() =>
      _releasing ??= _release().whenComplete(() => _releasing = null);

  Future<void> _release() async {
    await stop();
    // A model being prepared must not reappear after release returns.
    try {
      await _preparing;
    } catch (_) {
      /* release also cleans up failed preparation */
    }
    await _destroy();
  }

  Future<void> _destroy() async {
    await _completionSubscription?.cancel();
    _completionSubscription = null;
    try {
      await _player?.dispose();
    } catch (error) {
      debugPrint('sepia: could not release speech audio output: $error');
    }
    _player = null;
    _audio.clear();
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('the speech engine was released'));
      }
    }
    _pending.clear();
    final worker = _isolate;
    if (worker != null) {
      _toWorker?.send('dispose');
      try {
        // Killing an isolate does not run tts.free(): its ONNX allocations
        // would survive in the process. Let the active native call finish,
        // then let the worker free its model and exit cooperatively.
        await _workerExited?.future.timeout(const Duration(seconds: 60));
      } on TimeoutException {
        debugPrint('sepia: speech worker did not shut down in time');
        worker.kill(priority: Isolate.immediate);
      }
    }
    _toWorker = null;
    _fromWorker?.close();
    _fromWorker = null;
    _isolate = null;
    _workerExited = null;
    final scratch = _scratch;
    _scratch = null;
    if (scratch != null && await scratch.exists()) {
      await scratch.delete(recursive: true);
    }
  }
}

/// Runs in its own isolate: owns the model and does the synthesis.
void _synthesisWorker(_WorkerBootstrap bootstrap) {
  final inbox = ReceivePort();
  bootstrap.reply.send(inbox.sendPort);
  sherpa.OfflineTts? tts;

  sherpa.OfflineTts create() {
    // FFI bindings are per-isolate, so this happens here rather than being
    // inherited from whoever spawned us.
    sherpa.initBindings();
    final config = bootstrap.config;
    final model = config['kind'] == 'kokoro'
        ? sherpa.OfflineTtsModelConfig(
            kokoro: sherpa.OfflineTtsKokoroModelConfig(
              model: config['model'] as String,
              voices: config['voices'] as String,
              tokens: config['tokens'] as String,
              dataDir: config['dataDir'] as String,
              lexicon: config['lexicon'] as String,
              lang: config['lang'] as String,
            ),
            numThreads: 2,
            debug: false,
          )
        : sherpa.OfflineTtsModelConfig(
            vits: sherpa.OfflineTtsVitsModelConfig(
              model: config['model'] as String,
              tokens: config['tokens'] as String,
              dataDir: config['dataDir'] as String,
            ),
            numThreads: 2,
            debug: false,
          );
    return sherpa.OfflineTts(sherpa.OfflineTtsConfig(model: model));
  }

  // Report readiness only after model initialization succeeds. Otherwise
  // start() reports success and the first synthesis failure arrives too late
  // for the reader's platform-voice fallback.
  try {
    tts = create();
    bootstrap.reply.send(const _WorkerReady());
  } catch (error, stack) {
    bootstrap.reply.send(['model initialization failed: $error', '$stack']);
    inbox.close();
    return;
  }

  inbox.listen((message) {
    if (message == 'dispose') {
      tts?.free();
      tts = null;
      inbox.close();
      return;
    }
    if (message is! _SynthesisRequest) return;
    try {
      final engine = tts ??= create();
      final audio = engine.generate(
        // Headings and whitespace-split clauses still need a terminal pause.
        text: RegExp(r'[.!?;:]["”’»)]?$').hasMatch(message.text)
            ? message.text
            : '${message.text}.',
        sid: message.speakerId,
        speed: message.speed,
      );
      if (audio.samples.isEmpty) {
        throw StateError('the model produced no audio for this text');
      }
      sherpa.writeWave(
        filename: message.outputPath,
        // Give the audio route a short silent lead-in so opening/restarting
        // a track cannot swallow the first consonant. Never trim model audio.
        samples:
            Float32List(audio.samples.length + audio.sampleRate * 18 ~/ 100)
              ..setRange(
                audio.sampleRate * 12 ~/ 100,
                audio.sampleRate * 12 ~/ 100 + audio.samples.length,
                audio.samples,
              ),
        sampleRate: audio.sampleRate,
      );
      bootstrap.reply.send(
        _SynthesisReply(id: message.id, path: message.outputPath),
      );
    } catch (error) {
      bootstrap.reply.send(_SynthesisReply(id: message.id, error: '$error'));
    }
  });
}
