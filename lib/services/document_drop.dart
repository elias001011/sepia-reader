import '../models/document_drop.dart';
import 'document_drop_stub.dart'
    if (dart.library.js_interop) 'document_drop_web.dart'
    as implementation;

bool get supportsDocumentDrop => implementation.supportsDocumentDrop;

DocumentDropBinding bindDocumentDrop({
  required void Function(bool active) onDragActive,
  required Future<void> Function(DocumentDropSelection selection) onDrop,
}) =>
    implementation.bindDocumentDrop(onDragActive: onDragActive, onDrop: onDrop);
