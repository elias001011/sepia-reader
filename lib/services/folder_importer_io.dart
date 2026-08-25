import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../models/folder_import.dart';
import 'folder_import_rules.dart';

Future<FolderImportSelection?> pickDocumentFolder() async {
  final selectedPath = await FilePicker.getDirectoryPath();
  if (selectedPath == null) return null;

  final directory = Directory(selectedPath);
  if (!await directory.exists()) {
    throw const FileSystemException('The selected folder is not accessible.');
  }

  final normalizedRoot = directory.absolute.path.replaceAll('\\', '/');
  final rootName = normalizedRoot
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .last;
  final files = <FolderImportFile>[];
  var skipped = 0;

  await for (final entity in directory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) continue;
    final normalizedPath = entity.absolute.path.replaceAll('\\', '/');
    final relativePath = normalizedPath.startsWith('$normalizedRoot/')
        ? normalizedPath.substring(normalizedRoot.length + 1)
        : normalizedPath.split('/').last;
    if (!isSupportedDocumentPath(relativePath) ||
        await entity.length() > maxImportedFileBytes) {
      skipped++;
      continue;
    }
    files.add(
      FolderImportFile(
        relativePath: relativePath,
        bytes: await entity.readAsBytes(),
      ),
    );
  }

  return FolderImportSelection(
    folderName: rootName,
    files: files,
    skippedFiles: skipped,
  );
}
