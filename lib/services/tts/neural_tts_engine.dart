/// On-device neural speech.
///
/// Sépia Lite ships without the native inference stack (`sherpa_onnx`), so
/// this always resolves to the stub: [NeuralTtsEngine] exists for the imports
/// to bind, but the settings screen never offers it because
/// [VoiceStore.isSupported] is `false`.
library;

export 'neural_tts_engine_stub.dart';
