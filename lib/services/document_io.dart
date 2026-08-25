import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

import '../models/library_document.dart';

Future<void> exportDocument(LibraryDocument document) async {
  await FileSaver.instance.saveFile(
    name: document.title,
    bytes: Uint8List.fromList(utf8.encode(document.content)),
    fileExtension: document.extension,
    mimeType: _mimeFor(document.extension),
  );
}

MimeType _mimeFor(String extension) => switch (extension.toLowerCase()) {
  'md' || 'markdown' => MimeType.markdown,
  'json' => MimeType.json,
  'yaml' || 'yml' => MimeType.yaml,
  'xml' => MimeType.xml,
  'sql' => MimeType.sql,
  _ => MimeType.text,
};
