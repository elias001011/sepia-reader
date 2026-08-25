import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

import '../models/folder_import.dart';
import 'folder_import_rules.dart';

Future<FolderImportSelection?> pickDocumentFolder() async {
  final completer = Completer<FolderImportSelection?>();
  final input = HTMLInputElement()
    ..type = 'file'
    ..multiple = true
    ..style.display = 'none';
  input.setAttribute('webkitdirectory', '');
  input.setAttribute('directory', '');

  var eventTriggered = false;

  void cleanup() {
    input.remove();
  }

  void onCancel(Event _) {
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (eventTriggered) return;
      eventTriggered = true;
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
    });
  }

  void onChange(Event event) async {
    if (eventTriggered) return;
    eventTriggered = true;
    final files = input.files;
    if (files == null || files.length == 0) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final imported = <FolderImportFile>[];
    var skipped = 0;
    String? folderName;
    for (var index = 0; index < files.length; index++) {
      final file = files.item(index);
      if (file == null) continue;
      final rawPath = file.webkitRelativePath.isEmpty
          ? file.name
          : file.webkitRelativePath;
      final parts = rawPath
          .replaceAll('\\', '/')
          .split('/')
          .where((part) => part.isNotEmpty)
          .toList();
      if (parts.length > 1) folderName ??= parts.removeAt(0);
      final relativePath = parts.join('/');
      if (!isSupportedDocumentPath(relativePath) ||
          file.size > maxImportedFileBytes) {
        skipped++;
        continue;
      }
      final buffer = await file.arrayBuffer().toDart;
      imported.add(
        FolderImportFile(
          relativePath: relativePath,
          bytes: buffer.toDart.asUint8List(),
        ),
      );
    }

    cleanup();
    if (!completer.isCompleted) {
      completer.complete(
        FolderImportSelection(
          folderName: folderName ?? 'Imported folder',
          files: imported,
          skippedFiles: skipped,
        ),
      );
    }
  }

  input.addEventListener('change', onChange.toJS);
  input.addEventListener('cancel', onCancel.toJS);
  document.body?.append(input);
  input.click();
  return completer.future;
}
