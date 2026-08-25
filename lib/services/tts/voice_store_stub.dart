import 'package:http/http.dart' as http;

import 'voice_catalog.dart';
import 'voice_store_types.dart';

/// Web stand-in: neural voices need native inference and a filesystem, so on
/// the web this reports "unsupported" and the reader stays on the platform
/// voice.
class VoiceStore {
  VoiceStore({http.Client? client});

  bool get isSupported => false;

  Future<bool> isInstalled(NeuralVoice voice) async => false;

  Future<List<NeuralVoice>> installedVoices() async => const [];

  Future<int> installedSize(NeuralVoice voice) async => 0;

  Future<void> remove(NeuralVoice voice) async {}

  Future<void> install(
    NeuralVoice voice, {
    void Function(VoiceInstallProgress)? onProgress,
    bool Function()? shouldCancel,
  }) async =>
      throw UnsupportedError('neural voices need a native platform');
}
