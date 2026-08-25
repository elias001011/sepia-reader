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
