import 'package:http/http.dart' as http;

import 'voice_catalog.dart';
import 'voice_store_types.dart';

/// Web stand-in: neural voices need native inference and a filesystem, so on
/// the web this reports "unsupported" and the reader stays on the platform
/// voice.
class VoiceStore implements VoiceStorage {
  VoiceStore({http.Client? client});

  @override
  bool get isSupported => false;

  @override
  Future<bool> isInstalled(VoicePack pack) async => false;

  @override
  Future<List<VoicePack>> installedPacks() async => const [];

  Future<int> installedSize(VoicePack pack) async => 0;

  @override
  Future<void> remove(VoicePack pack) async {}

  @override
  Future<void> install(
    VoicePack pack, {
    void Function(VoiceInstallProgress)? onProgress,
    bool Function()? shouldCancel,
  }) async =>
      throw UnsupportedError('neural voices need a native platform');
}
