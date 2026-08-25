import '../models/folder_import.dart';
export 'folder_import_rules.dart';
import 'folder_importer_stub.dart'
    if (dart.library.io) 'folder_importer_io.dart'
    if (dart.library.js_interop) 'folder_importer_web.dart'
    as implementation;

Future<FolderImportSelection?> pickDocumentFolder() =>
    implementation.pickDocumentFolder();
