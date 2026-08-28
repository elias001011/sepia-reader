import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/library_document.dart';

/// What became of an export attempt.
enum ExportOutcome {
  /// The bytes were written to the location the user chose.
  saved,

  /// The user dismissed the save dialog without picking a location.
  cancelled,
}

/// Writes [document] out through the platform's own "save file" dialog.
///
/// This used to go through `file_saver`, which on Android 11+ resolved to a
/// path the app could not actually write to: no permission was ever asked
/// for, nothing landed in Downloads, and no error was raised — the export
/// simply did nothing. `FilePicker.saveFile` hands the bytes to the system
/// document picker instead, which needs no storage permission, lets the user
/// drop the file straight into Downloads, and reports back whether it was
/// saved or dismissed.
Future<ExportOutcome> exportDocument(LibraryDocument document) async {
  final bytes = Uint8List.fromList(utf8.encode(document.content));
  final result = await FilePicker.saveFile(
    fileName: '${document.title}.${document.extension}',
    bytes: bytes,
    mimeType: _mimeFor(document.extension),
  );
  return result == null ? ExportOutcome.cancelled : ExportOutcome.saved;
}

String _mimeFor(String extension) => switch (extension.toLowerCase()) {
  'md' || 'markdown' => 'text/markdown',
  'json' => 'application/json',
  'yaml' || 'yml' => 'application/yaml',
  'xml' => 'application/xml',
  'sql' => 'application/sql',
  'html' || 'htm' => 'text/html',
  'csv' => 'text/csv',
  _ => 'text/plain',
};
