import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

import '../models/document_drop.dart';
import 'folder_import_rules.dart';

const supportsDocumentDrop = true;

DocumentDropBinding bindDocumentDrop({
  required void Function(bool active) onDragActive,
  required Future<void> Function(DocumentDropSelection selection) onDrop,
}) => _WebDocumentDropBinding(onDragActive: onDragActive, onDrop: onDrop);

class _WebDocumentDropBinding implements DocumentDropBinding {
  _WebDocumentDropBinding({required this.onDragActive, required this.onDrop}) {
    _dragEnterListener = _handleDragEnter.toJS;
    _dragOverListener = _handleDragOver.toJS;
    _dragLeaveListener = _handleDragLeave.toJS;
    _dropListener = _handleDrop.toJS;
    document.addEventListener('dragenter', _dragEnterListener);
    document.addEventListener('dragover', _dragOverListener);
    document.addEventListener('dragleave', _dragLeaveListener);
    document.addEventListener('drop', _dropListener);
  }

  final void Function(bool active) onDragActive;
  final Future<void> Function(DocumentDropSelection selection) onDrop;
  late final JSFunction _dragEnterListener;
  late final JSFunction _dragOverListener;
  late final JSFunction _dragLeaveListener;
  late final JSFunction _dropListener;
  var _dragDepth = 0;
  var _disposed = false;

  void _handleDragEnter(DragEvent event) {
    if (_disposed) return;
    event.preventDefault();
    _dragDepth++;
    event.dataTransfer?.dropEffect = 'copy';
    onDragActive(true);
  }

  void _handleDragOver(DragEvent event) {
    if (_disposed) return;
    event.preventDefault();
    event.dataTransfer?.dropEffect = 'copy';
  }

  void _handleDragLeave(DragEvent event) {
    if (_disposed) return;
    event.preventDefault();
    _dragDepth = (_dragDepth - 1).clamp(0, 1 << 20);
    if (_dragDepth == 0) onDragActive(false);
  }

  void _handleDrop(DragEvent event) {
    if (_disposed) return;
    event.preventDefault();
    _dragDepth = 0;
    onDragActive(false);
    unawaited(_readDroppedFiles(event));
  }

  Future<void> _readDroppedFiles(DragEvent event) async {
    final fileList = event.dataTransfer?.files;
    if (fileList == null) return;
    final files = <DroppedDocumentFile>[];
    var skipped = 0;
    for (var index = 0; index < fileList.length; index++) {
      final file = fileList.item(index);
      if (file == null) continue;
      if (!isSupportedDocumentPath(file.name) ||
          file.size > maxImportedFileBytes) {
        skipped++;
        continue;
      }
      final buffer = await file.arrayBuffer().toDart;
      files.add(
        DroppedDocumentFile(
          name: file.name,
          bytes: buffer.toDart.asUint8List(),
        ),
      );
    }
    await onDrop(DocumentDropSelection(files: files, skippedFiles: skipped));
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    document.removeEventListener('dragenter', _dragEnterListener);
    document.removeEventListener('dragover', _dragOverListener);
    document.removeEventListener('dragleave', _dragLeaveListener);
    document.removeEventListener('drop', _dropListener);
  }
}
