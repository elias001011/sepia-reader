import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'tts_engine.dart';
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

class _WorkerBootstrap {
  const _WorkerBootstrap({required this.reply, required this.config});
  final SendPort reply;
  final Map<String, dynamic> config;
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
  });

  /// The downloaded model this voice comes out of. For Piper the pack holds
  /// exactly this voice; for Kokoro it holds dozens, and the voice is chosen
  /// per utterance by speaker id.
  final VoicePack pack;
  final NeuralVoice voice;
  final VoiceStore store;

  Isolate? _isolate;
  SendPort? _toWorker;
  ReceivePort? _fromWorker;
  Directory? _scratch;

  final AudioPlayer _player = AudioPlayer();
  final Map<int, Completer<String>> _pending = {};

  /// Sentences already rendered to disk, keyed by the text that produced
  /// them. Deliberately small: it exists to hold the sentence being spoken
  /// and the one after it, not a chapter of audio.
  final Map<String, String> _rendered = {};
  static const _maxRendered = 4;

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
    if (_toWorker != null) return;
    if (!await store.isInstalled(pack)) {
      throw StateError('the voice ${voice.id} is not installed');
    }
    final dir = await store.packDirectory(pack);
    final scratch = Directory('${dir.path}/.audio');
    if (scratch.existsSync()) scratch.deleteSync(recursive: true);
    scratch.createSync(recursive: true);
    _scratch = scratch;

    final ready = Completer<SendPort>();
    final fromWorker = ReceivePort();
    _fromWorker = fromWorker;
    fromWorker.listen((message) {
      if (message is SendPort) {
        if (!ready.isCompleted) ready.complete(message);
        return;
      }
      if (message is! _SynthesisReply) return;
      final completer = _pending.remove(message.id);
      if (completer == null || completer.isCompleted) return;
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
      errorsAreFatal: false,
    );
    _toWorker = await ready.future.timeout(const Duration(seconds: 30));

    _completionSubscription = _player.onPlayerComplete.listen((_) {
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
        'lang': pack.espeakLang,
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
    // Anything rendered at the old speed is no longer what was asked for.
    if (rate != _speed) {
      _speed = rate;
      _discardRendered();
    }
  }

  Future<String> _render(String text) async {
    final cached = _rendered[text];
    if (cached != null && File(cached).existsSync()) return cached;
    await prepare();
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
    final path = await completer.future;
    _rendered[text] = path;
    _trimRendered();
    return path;
  }

  void _trimRendered() {
    while (_rendered.length > _maxRendered) {
      final oldest = _rendered.keys.first;
      _deleteRendered(_rendered.remove(oldest));
    }
  }

  void _discardRendered() {
    for (final path in _rendered.values) {
      _deleteRendered(path);
    }
    _rendered.clear();
  }

  void _deleteRendered(String? path) {
    if (path == null) return;
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  }

  @override
  Future<void> prime(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _render(text);
    } catch (error) {
      // Working ahead is an optimisation. If the failure is real, speak()
      // will hit it too and report it properly; there is nothing useful to
      // tell the reader about a sentence they have not reached yet.
      debugPrint('sepia: could not pre-render an utterance: $error');
    }
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    final path = await _render(text);
    final playback = Completer<void>();
    _playback = playback;
    await _player.play(DeviceFileSource(path));
    await playback.future;
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    final playback = _playback;
    _playback = null;
    if (playback != null && !playback.isCompleted) playback.complete();
  }

  @override
  Future<void> release() async {
    await stop();
    await _completionSubscription?.cancel();
    _completionSubscription = null;
    _toWorker?.send('dispose');
    _toWorker = null;
    _fromWorker?.close();
    _fromWorker = null;
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _isolate = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('the speech engine was released'));
      }
    }
    _pending.clear();
    _rendered.clear();
    final scratch = _scratch;
    _scratch = null;
    if (scratch != null && scratch.existsSync()) {
      scratch.deleteSync(recursive: true);
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
        text: message.text,
        sid: message.speakerId,
        speed: message.speed,
      );
      if (audio.samples.isEmpty) {
        throw StateError('the model produced no audio for this text');
      }
      sherpa.writeWave(
        filename: message.outputPath,
        samples: audio.samples,
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
