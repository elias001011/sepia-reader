import 'dart:typed_data';

class DroppedDocumentFile {
  const DroppedDocumentFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class DocumentDropSelection {
  const DocumentDropSelection({
    required this.files,
    required this.skippedFiles,
  });

  final List<DroppedDocumentFile> files;
  final int skippedFiles;
}

abstract interface class DocumentDropBinding {
  void dispose();
}
