import '../models/document_drop.dart';

const supportsDocumentDrop = false;

DocumentDropBinding bindDocumentDrop({
  required void Function(bool active) onDragActive,
  required Future<void> Function(DocumentDropSelection selection) onDrop,
}) => _NoopDocumentDropBinding();

class _NoopDocumentDropBinding implements DocumentDropBinding {
  @override
  void dispose() {}
}
