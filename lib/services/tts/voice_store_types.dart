import 'voice_catalog.dart';

/// How far along a voice install is.
class VoiceInstallProgress {
  const VoiceInstallProgress({
    required this.filesDone,
    required this.filesTotal,
    required this.bytesDone,
    required this.bytesTotal,
    this.currentFile,
  });

  final int filesDone;
  final int filesTotal;
  final int bytesDone;
  final int bytesTotal;
  final String? currentFile;

  double get fraction => bytesTotal == 0 ? 0 : bytesDone / bytesTotal;
}

/// Raised when an install is asked to stop.
class VoiceInstallCancelled implements Exception {
  const VoiceInstallCancelled();
  @override
  String toString() => 'VoiceInstallCancelled';
}

/// What a download manager needs from voice storage.
///
/// Narrower than the store itself on purpose: the manager has no business
/// knowing about repository listings or filesystem paths, and depending only
/// on this is what lets it be driven by a fake in a test — and what keeps
/// the web build, whose store can do none of it, honest about saying so.
abstract class VoiceStorage {
  bool get isSupported;

  Future<bool> isInstalled(VoicePack pack);

  Future<List<VoicePack>> installedPacks();

  Future<void> remove(VoicePack pack);

  Future<void> install(
    VoicePack pack, {
    void Function(VoiceInstallProgress)? onProgress,
    bool Function()? shouldCancel,
  });
}
