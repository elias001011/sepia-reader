import 'dart:typed_data';

class FolderImportFile {
  const FolderImportFile({required this.relativePath, required this.bytes});

  final String relativePath;
  final Uint8List bytes;
}

class FolderImportSelection {
  const FolderImportSelection({
    required this.folderName,
    required this.files,
    required this.skippedFiles,
  });

  final String folderName;
  final List<FolderImportFile> files;
  final int skippedFiles;
}
