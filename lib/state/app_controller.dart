import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/app_settings.dart';
import '../models/folder_import.dart';
import '../models/library_document.dart';
import '../models/library_folder.dart';
import '../services/storage_service.dart';

class AppController extends ChangeNotifier {
  AppController({StorageService? storage})
    : _storage = storage ?? StorageService();
  final StorageService _storage;
  final Uuid _uuid = const Uuid();
  final List<LibraryDocument> _documents = [];
  final List<LibraryFolder> _folders = [];
  AppSettings _settings = const AppSettings();

  List<LibraryDocument> get documents {
    final sorted = List<LibraryDocument>.from(_documents)
      ..sort((a, b) {
        if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return List.unmodifiable(sorted);
  }

  AppSettings get settings => _settings;

  List<LibraryFolder> get folders {
    final sorted = List<LibraryFolder>.from(_folders)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List.unmodifiable(sorted);
  }

  List<LibraryFolder> foldersIn(String? parentId) => folders
      .where((folder) => folder.parentId == parentId)
      .toList(growable: false);

  List<LibraryDocument> documentsIn(String? folderId) => documents
      .where((document) => document.folderId == folderId)
      .toList(growable: false);

  Future<void> initialize() async {
    _settings = await _storage.loadSettings();
    _folders.addAll(await _storage.loadFolders());
    _documents.addAll(await _storage.loadDocuments());
    if (_documents.isEmpty) {
      final now = DateTime.now();
      final isEnglish = _usesEnglish;
      _documents.add(
        LibraryDocument(
          id: _uuid.v4(),
          title: isEnglish ? 'Welcome to Sépia' : 'Bem-vindo ao Sépia',
          extension: 'md',
          createdAt: now,
          updatedAt: now,
          content: isEnglish ? _welcomeDocumentEn : _welcomeDocumentPt,
        ),
      );
      await _persistDocuments();
    }
  }

  Future<LibraryDocument> createDocument({
    required String title,
    String extension = 'md',
    String content = '',
    String? folderId,
  }) async {
    final now = DateTime.now();
    final ext = extension.replaceFirst('.', '').toLowerCase();
    final suffix = '.$ext';
    var cleanTitle = title.trim();
    if (cleanTitle.toLowerCase().endsWith(suffix)) {
      cleanTitle = cleanTitle.substring(0, cleanTitle.length - suffix.length);
    }
    final document = LibraryDocument(
      id: _uuid.v4(),
      title: cleanTitle.isEmpty
          ? (_usesEnglish ? 'Untitled' : 'Sem título')
          : cleanTitle,
      content: content,
      extension: ext,
      createdAt: now,
      updatedAt: now,
      folderId: folderId,
    );
    _documents.add(document);
    await _persistDocuments();
    notifyListeners();
    return document;
  }

  Future<void> updateDocument(LibraryDocument document) async {
    final index = _documents.indexWhere((item) => item.id == document.id);
    if (index == -1) return;
    _documents[index] = document.copyWith(updatedAt: DateTime.now());
    await _persistDocuments();
    notifyListeners();
  }

  Future<void> renameDocument(String id, String name) async {
    final index = _documents.indexWhere((document) => document.id == id);
    if (index == -1) return;
    final document = _documents[index];
    final suffix = '.${document.extension}';
    var cleanTitle = name.trim();
    if (cleanTitle.toLowerCase().endsWith(suffix.toLowerCase())) {
      cleanTitle = cleanTitle.substring(0, cleanTitle.length - suffix.length);
    }
    cleanTitle = cleanTitle.trim();
    if (cleanTitle.isEmpty) return;
    _documents[index] = document.copyWith(
      title: cleanTitle,
      updatedAt: DateTime.now(),
    );
    await _persistDocuments();
    notifyListeners();
  }

  Future<void> deleteDocument(String id) async {
    _documents.removeWhere((document) => document.id == id);
    await _persistDocuments();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final index = _documents.indexWhere((document) => document.id == id);
    if (index == -1) return;
    _documents[index] = _documents[index].copyWith(
      isFavorite: !_documents[index].isFavorite,
    );
    await _persistDocuments();
    notifyListeners();
  }

  Future<LibraryFolder> createFolder({
    required String name,
    String? parentId,
  }) async {
    final folder = _createFolderInMemory(name: name, parentId: parentId);
    await _persistFolders();
    notifyListeners();
    return folder;
  }

  Future<void> renameFolder(String id, String name) async {
    final index = _folders.indexWhere((folder) => folder.id == id);
    final cleanName = _cleanFolderName(name);
    if (index == -1 || cleanName.isEmpty) return;
    _folders[index] = _folders[index].copyWith(
      name: _uniqueFolderName(
        cleanName,
        _folders[index].parentId,
        exceptId: id,
      ),
      updatedAt: DateTime.now(),
    );
    await _persistFolders();
    notifyListeners();
  }

  Future<void> moveDocument(String documentId, String? folderId) async {
    final index = _documents.indexWhere(
      (document) => document.id == documentId,
    );
    if (index == -1) return;
    _documents[index] = _documents[index].copyWith(
      folderId: folderId,
      moveToRoot: folderId == null,
      updatedAt: DateTime.now(),
    );
    await _persistDocuments();
    notifyListeners();
  }

  Future<bool> deleteEmptyFolder(String id) async {
    final index = _folders.indexWhere((folder) => folder.id == id);
    if (index == -1 ||
        _folders.any((folder) => folder.parentId == id) ||
        _documents.any((document) => document.folderId == id)) {
      return false;
    }
    _folders.removeAt(index);
    await _persistFolders();
    notifyListeners();
    return true;
  }

  Future<int> importFolder(
    FolderImportSelection selection, {
    String? parentId,
  }) async {
    if (selection.files.isEmpty) return 0;
    final root = _createFolderInMemory(
      name: selection.folderName,
      parentId: parentId,
    );
    final folderIds = <String, String>{'': root.id};
    var imported = 0;

    for (final file in selection.files) {
      final parts = file.relativePath
          .replaceAll('\\', '/')
          .split('/')
          .where((part) => part.trim().isNotEmpty)
          .toList();
      if (parts.isEmpty) continue;
      final filename = parts.removeLast();
      var currentPath = '';
      var currentFolderId = root.id;
      for (final segment in parts) {
        currentPath = currentPath.isEmpty ? segment : '$currentPath/$segment';
        currentFolderId = folderIds.putIfAbsent(
          currentPath,
          () => _createFolderInMemory(
            name: segment,
            parentId: currentFolderId,
          ).id,
        );
      }
      final nameParts = filename.split('.');
      final extension = nameParts.length > 1
          ? nameParts.removeLast().toLowerCase()
          : 'txt';
      final title = nameParts.join('.');
      _createDocumentInMemory(
        title: title,
        extension: extension,
        content: utf8.decode(file.bytes, allowMalformed: true),
        folderId: currentFolderId,
      );
      imported++;
    }

    await _persistLibrary();
    notifyListeners();
    return imported;
  }

  LibraryDocument? documentById(String id) {
    try {
      return _documents.firstWhere((document) => document.id == id);
    } catch (_) {
      return null;
    }
  }

  LibraryFolder? folderById(String id) {
    try {
      return _folders.firstWhere((folder) => folder.id == id);
    } catch (_) {
      return null;
    }
  }

  List<LibraryFolder> folderPath(String? folderId) {
    final path = <LibraryFolder>[];
    final seen = <String>{};
    var currentId = folderId;
    while (currentId != null && seen.add(currentId)) {
      final folder = folderById(currentId);
      if (folder == null) break;
      path.insert(0, folder);
      currentId = folder.parentId;
    }
    return path;
  }

  int folderDocumentCount(String folderId) {
    final ids = <String>{folderId};
    var changed = true;
    while (changed) {
      changed = false;
      for (final folder in _folders) {
        if (folder.parentId != null &&
            ids.contains(folder.parentId) &&
            ids.add(folder.id)) {
          changed = true;
        }
      }
    }
    return _documents
        .where((document) => ids.contains(document.folderId))
        .length;
  }

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    await _storage.saveSettings(settings);
    notifyListeners();
  }

  Future<void> _persistDocuments() => _storage.saveDocuments(_documents);

  Future<void> _persistFolders() => _storage.saveFolders(_folders);

  Future<void> _persistLibrary() async {
    await Future.wait([_persistDocuments(), _persistFolders()]);
  }

  LibraryFolder _createFolderInMemory({
    required String name,
    String? parentId,
  }) {
    final now = DateTime.now();
    final cleanName = _cleanFolderName(name);
    final folder = LibraryFolder(
      id: _uuid.v4(),
      name: _uniqueFolderName(
        cleanName.isEmpty
            ? (_usesEnglish ? 'New folder' : 'Nova pasta')
            : cleanName,
        parentId,
      ),
      parentId: parentId,
      createdAt: now,
      updatedAt: now,
    );
    _folders.add(folder);
    return folder;
  }

  LibraryDocument _createDocumentInMemory({
    required String title,
    required String extension,
    required String content,
    String? folderId,
  }) {
    final now = DateTime.now();
    final document = LibraryDocument(
      id: _uuid.v4(),
      title: title.trim().isEmpty
          ? (_usesEnglish ? 'Untitled' : 'Sem título')
          : title.trim(),
      content: content,
      extension: extension,
      folderId: folderId,
      createdAt: now,
      updatedAt: now,
    );
    _documents.add(document);
    return document;
  }

  String _cleanFolderName(String name) => name
      .trim()
      .replaceAll(RegExp(r'[\\/]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  String _uniqueFolderName(
    String requested,
    String? parentId, {
    String? exceptId,
  }) {
    final names = _folders
        .where((folder) => folder.parentId == parentId && folder.id != exceptId)
        .map((folder) => folder.name.toLowerCase())
        .toSet();
    if (!names.contains(requested.toLowerCase())) return requested;
    var suffix = 2;
    while (names.contains('$requested $suffix'.toLowerCase())) {
      suffix++;
    }
    return '$requested $suffix';
  }

  bool get _usesEnglish {
    if (_settings.localeCode == 'en') return true;
    if (_settings.localeCode == 'pt_BR') return false;
    return PlatformDispatcher.instance.locale.languageCode == 'en';
  }
}

const _welcomeDocumentPt = '''# Bem-vindo ao Sépia

Um lugar calmo para **ler, escrever e guardar** seus textos.

## Comece por aqui

- Importe arquivos `.md`, `.txt` ou arquivos de código.
- Crie um Markdown diretamente na biblioteca.
- Ajuste fonte, tamanho, largura e cores para a sua leitura.
- Ative o **modo leitura** para ocultar as ferramentas e bloquear edições.
- Exporte seu texto quando quiser — ele continua sendo seu.

> A melhor interface de leitura é aquela que desaparece quando o texto começa.

```dart
void main() {
  print('Olá, Sépia!');
}
```

Boa leitura. ☕
''';

const _welcomeDocumentEn = '''# Welcome to Sépia

A calm place to **read, write, and keep** your texts.

## Start here

- Import `.md`, `.txt`, or source-code files.
- Create a Markdown document directly in the library.
- Adjust the font, size, width, and colors for your reading.
- Turn on **reading mode** to hide the tools and lock editing.
- Export your text whenever you want — it remains yours.

> The best reading interface disappears when the text begins.

```dart
void main() {
  print('Hello, Sépia!');
}
```

Enjoy your reading. ☕
''';
