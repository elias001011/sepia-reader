import 'tts_engine.dart';
import 'voice_catalog.dart';
import 'voice_store_stub.dart';

/// Web stand-in. Never selected — the settings screen only offers the neural
/// engine where [VoiceStore.isSupported] — but it has to exist for the import
/// to resolve.
class NeuralTtsEngine extends TtsEngine {
  NeuralTtsEngine({required this.voice, required this.store});

  final NeuralVoice voice;
  final VoiceStore store;

  Never _unsupported() =>
      throw UnsupportedError('neural voices need a native platform');

  @override
  String get label => 'neural';

  @override
  bool get supportsPitch => false;

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> prepare() async => _unsupported();

  @override
  Future<List<TtsVoice>> availableVoices() async => const [];

  @override
  Future<void> configure({
    String? voiceId,
    required double rate,
    required double pitch,
  }) async {}

  @override
  Future<void> speak(String text) async => _unsupported();

  @override
  Future<void> stop() async {}

  @override
  Future<void> release() async {}
}
