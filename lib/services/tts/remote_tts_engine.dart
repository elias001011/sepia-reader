import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'remote_speech_client.dart';
import 'remote_speech_config.dart';
import 'speech_audio_buffer.dart';
import 'tts_engine.dart';

abstract class RemoteAudioOutput {
  Stream<void> get completed;
  Future<void> prepare();
  Future<void> play(SpeechRecording audio);
  Future<void> stop();
  Future<void> dispose();
}

class _DeviceRemoteOutput implements RemoteAudioOutput {
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
  Future<void> play(SpeechRecording audio) =>
      _player.play(BytesSource(audio.bytes, mimeType: audio.mimeType));
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();
}

class RemoteTtsEngine extends TtsEngine {
  RemoteTtsEngine({
    required this.loadConfig,
    this.syncUrl = '',
    this.syncToken = '',
    RemoteAudioOutput? output,
    this.clientFactory,
  }) : _outputFactory = (() => output ?? _DeviceRemoteOutput());
  final Future<RemoteSpeechConfig> Function() loadConfig;
  final String syncUrl, syncToken;
  final RemoteAudioOutput Function() _outputFactory;
  final RemoteSpeechClient Function(RemoteSpeechConfig)? clientFactory;
  RemoteAudioOutput? _output;
  RemoteSpeechClient? _client;
  RemoteSpeechConfig? _config;
  StreamSubscription<void>? _completion;
  Future<void>? _preparing, _releasing;
  Future<void> _operations = Future.value();
  Completer<void>? _playback, _abort;
  int _epoch = 0;
  double _rate = 1;
  late final _audio = SpeechAudioBuffer<SpeechRecording>(
    render: _render,
    discard: (_) {},
  );

  @override
  String get label => 'remote';
  @override
  bool get supportsPitch => false;
  @override
  bool get preserveSpeechPunctuation => true;
  @override
  int get utteranceLimit => 600;
  @override
  Future<bool> isAvailable() async => true;

  Future<void> _serialize(Future<void> Function() operation) {
    final future = _operations.then((_) => operation());
    _operations = future.catchError((Object _) {});
    return future;
  }

  Future<void> _prepareClient() async {
    if (_client != null) return;
    final config = await loadConfig();
    final client =
        clientFactory?.call(config) ??
        RemoteSpeechClient(config, syncUrl: syncUrl, syncToken: syncToken);
    try {
      client.validate();
    } catch (_) {
      client.close();
      rethrow;
    }
    _config = config;
    _client = client;
  }

  @override
  Future<void> prepare() async {
    await _releasing;
    return _preparing ??= _prepare().whenComplete(() => _preparing = null);
  }

  Future<void> _prepare() async {
    await _prepareClient();
    if (_output != null) return;
    final output = _outputFactory();
    try {
      await output.prepare();
    } catch (_) {
      await output.dispose();
      rethrow;
    }
    _output = output;
    _completion = output.completed.listen((_) {
      final playback = _playback;
      _playback = null;
      if (playback != null && !playback.isCompleted) playback.complete();
    });
  }

  @override
  Future<List<TtsVoice>> availableVoices() async {
    await _prepareClient();
    return _client!.voices();
  }

  @override
  Future<void> configure({
    String? voiceId,
    required double rate,
    required double pitch,
  }) async {
    final next = rate.clamp(.5, 2.0);
    if (_rate != next) {
      await stop();
      _rate = next;
    }
  }

  Future<SpeechRecording> _render(String text) async {
    final abort = _abort = Completer<void>();
    try {
      return await _client!.synthesize(text, _rate, abort: abort.future);
    } finally {
      if (identical(_abort, abort)) _abort = null;
    }
  }

  @override
  Future<void> prime(String text) async {
    if (_config?.prefetch != true) return;
    try {
      await _audio.obtain(text, ahead: true);
    } catch (_) {
      /* report only if current */
    }
  }

  @override
  Future<void> speak(String text) => speakWithLookAhead(text, null);
  @override
  Future<void> speakWithLookAhead(String text, String? nextText) async {
    if (text.trim().isEmpty) return;
    final epoch = _epoch;
    await prepare();
    if (epoch != _epoch) return;
    final audio = await _audio.obtain(text);
    if (epoch != _epoch || audio == null) return;
    final playback = Completer<void>();
    await _serialize(() async {
      if (epoch != _epoch) return;
      _playback = playback;
      await _output!.play(audio);
      if (epoch == _epoch && nextText != null) unawaitedPrime(nextText);
    });
    if (epoch != _epoch) return;
    try {
      await playback.future.timeout(Duration(seconds: 20 + text.length));
    } on TimeoutException {
      if (epoch == _epoch) {
        await stop();
        throw const RemoteSpeechException('playback-timeout');
      }
    }
  }

  @override
  Future<void> stop() {
    _epoch++;
    final abort = _abort;
    if (abort != null && !abort.isCompleted) abort.complete();
    _audio.clear();
    return _serialize(() async {
      try {
        await _output?.stop();
      } finally {
        final playback = _playback;
        _playback = null;
        if (playback != null && !playback.isCompleted) playback.complete();
      }
    });
  }

  @override
  Future<void> release() =>
      _releasing ??= _release().whenComplete(() => _releasing = null);
  Future<void> _release() async {
    await stop();
    try {
      await _preparing;
    } catch (_) {
      /* clean failed preparation too */
    }
    await _completion?.cancel();
    _completion = null;
    try {
      await _output?.dispose();
    } finally {
      _output = null;
      _client?.close();
      _client = null;
      _config = null;
    }
  }
}
