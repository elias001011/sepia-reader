import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/app_settings.dart';
import '../models/bookmark.dart';
import '../models/folder_import.dart';
import '../models/library_document.dart';
import '../models/library_folder.dart';
import '../models/syncable.dart';
import '../services/document_kind.dart';
import '../services/storage_service.dart';
import '../services/tts/voice_download_manager.dart';
import '../services/update_checker.dart';
import '../services/sync_merge.dart';

/// Identifier of the welcome document, deliberately fixed rather than a
/// fresh UUID.
///
/// Every empty library seeds one, and a browser and a phone that both start
/// empty each used to seed their own — with different random ids, so syncing
/// merged them into two copies, then three. A constant id makes them the
/// same record, and merging collapses them.
const welcomeDocumentId = 'sepia.welcome.v1';

/// Outcome of a user-triggered sync, so the library can say what actually
/// happened instead of just spinning and stopping.
enum SyncRunResult { done, failed, disabled }

class AppController extends ChangeNotifier {
  AppController({StorageService? storage, UpdateChecker? updateChecker})
    : _storage = storage ?? StorageService(),
      updates = updateChecker ?? UpdateChecker();
  final StorageService _storage;

  /// Shared so screens do not each open their own, and so a test can hand
  /// in one that never touches the network.
  final UpdateChecker updates;

  /// Voice downloads live here, above any screen, so closing the sheet that
  /// started one does not take a several-hundred-megabyte install with it.
  final VoiceDownloadManager voiceDownloads = VoiceDownloadManager();
  final Uuid _uuid = const Uuid();
  final List<LibraryDocument> _documents = [];
  final List<LibraryFolder> _folders = [];
  final List<ReadingBookmark> _bookmarks = [];
  AppSettings _settings = const AppSettings();

  List<LibraryDocument> get documents {
    final sorted = live(_documents)
      ..sort((a, b) {
        if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return List.unmodifiable(sorted);
  }

  AppSettings get settings => _settings;

  List<LibraryFolder> get folders {
    final sorted = live(_folders)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List.unmodifiable(sorted);
  }

  List<LibraryFolder> foldersIn(String? parentId) => folders
      .where((folder) => folder.parentId == parentId)
      .toList(growable: false);

  List<LibraryDocument> documentsIn(String? folderId) => documents
      .where((document) => document.folderId == folderId)
      .toList(growable: false);

  List<ReadingBookmark> bookmarksForDocument(String documentId) {
    final matches = _bookmarks
        .where(
          (bookmark) =>
              bookmark.documentId == documentId && !bookmark.isDeleted,
        )
        .toList()
      ..sort((a, b) => a.chunkIndex.compareTo(b.chunkIndex));
    return List.unmodifiable(matches);
  }

  Future<void> initialize() async {
    _settings = await _storage.loadSettings();
    _folders.addAll(await _storage.loadFolders());
    _documents.addAll(await _storage.loadDocuments());
    _bookmarks.addAll(await _storage.loadBookmarks());
    // "Empty" means no *live* documents: a library whose documents were all
    // deleted should still get the welcome document back.
    if (live(_documents).isEmpty) {
      final now = DateTime.now();
      final isEnglish = _usesEnglish;
      final welcome = LibraryDocument(
        id: welcomeDocumentId,
        title: isEnglish ? 'Welcome to Sépia' : 'Bem-vindo ao Sépia',
        extension: 'md',
        createdAt: now,
        updatedAt: now,
        content: isEnglish ? _welcomeDocumentEn : _welcomeDocumentPt,
      );
      // Replace rather than append: a tombstoned copy from an earlier
      // emptying is still in the list, and two records with the same id
      // would make the merge's behaviour depend on their order.
      final existing = _documents.indexWhere(
        (document) => document.id == welcomeDocumentId,
      );
      if (existing == -1) {
        _documents.add(welcome);
      } else {
        _documents[existing] = welcome;
      }
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
    final index = _liveDocumentIndex(document.id);
    if (index == -1) return;
    _documents[index] = document.copyWith(updatedAt: DateTime.now());
    await _persistDocuments();
    notifyListeners();
  }

  Future<void> renameDocument(String id, String name) async {
    final index = _liveDocumentIndex(id);
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
    final index = _liveDocumentIndex(id);
    if (index == -1) return;
    final now = DateTime.now();
    // Keep the record as a tombstone so the deletion reaches other devices,
    // but drop the body: a deleted long document should not keep sitting in
    // the synced payload for the whole retention window.
    _documents[index] = _documents[index].copyWith(
      content: '',
      updatedAt: now,
      deletedAt: now,
    );
    var hadBookmarks = false;
    for (var i = 0; i < _bookmarks.length; i++) {
      final bookmark = _bookmarks[i];
      if (bookmark.documentId != id || bookmark.isDeleted) continue;
      _bookmarks[i] = bookmark.copyWith(updatedAt: now, deletedAt: now);
      hadBookmarks = true;
    }
    await _persistDocuments();
    if (hadBookmarks) await _persistBookmarks();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final index = _liveDocumentIndex(id);
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
    final index = _liveFolderIndex(id);
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
    final index = _liveDocumentIndex(documentId);
    if (index == -1) return;
    _documents[index] = _documents[index].copyWith(
      folderId: folderId,
      moveToRoot: folderId == null,
      updatedAt: DateTime.now(),
    );
    await _persistDocuments();
    notifyListeners();
  }

  /// Everything a folder holds, transitively: the ids of the folder itself
  /// and every descendant folder, plus every live document inside any of
  /// them. Used both to warn before a delete and to carry it out.
  ({Set<String> folderIds, List<LibraryDocument> documents}) folderContents(
    String id,
  ) {
    final folderIds = <String>{id};
    var changed = true;
    while (changed) {
      changed = false;
      for (final folder in live(_folders)) {
        if (folder.parentId != null &&
            folderIds.contains(folder.parentId) &&
            folderIds.add(folder.id)) {
          changed = true;
        }
      }
    }
    final documents = live(_documents)
        .where((document) => folderIds.contains(document.folderId))
        .toList(growable: false);
    return (folderIds: folderIds, documents: documents);
  }

  /// Deletes a folder along with every subfolder and document it holds.
  ///
  /// Folders used to be undeletable while anything was inside them, which
  /// just moved the work onto the user: empty it by hand, folder by folder,
  /// before the delete would go through. The confirmation now names what is
  /// about to go, and this does the whole job in one pass. Everything is
  /// tombstoned rather than dropped, so the deletion still propagates to the
  /// other devices instead of the server pushing the records back.
  Future<void> deleteFolder(String id) async {
    if (_liveFolderIndex(id) == -1) return;
    final contents = folderContents(id);
    final now = DateTime.now();
    for (var i = 0; i < _folders.length; i++) {
      if (contents.folderIds.contains(_folders[i].id) &&
          !_folders[i].isDeleted) {
        _folders[i] = _folders[i].copyWith(updatedAt: now, deletedAt: now);
      }
    }
    final documentIds = contents.documents.map((d) => d.id).toSet();
    for (var i = 0; i < _documents.length; i++) {
      if (documentIds.contains(_documents[i].id)) {
        _documents[i] = _documents[i].copyWith(updatedAt: now, deletedAt: now);
      }
    }
    for (var i = 0; i < _bookmarks.length; i++) {
      if (documentIds.contains(_bookmarks[i].documentId) &&
          !_bookmarks[i].isDeleted) {
        _bookmarks[i] = _bookmarks[i].copyWith(updatedAt: now, deletedAt: now);
      }
    }
    await Future.wait([
      _persistFolders(),
      _persistDocuments(),
      _persistBookmarks(),
    ]);
    notifyListeners();
  }

  /// Imports a picked folder tree. [rejected] counts files that looked
  /// importable by name but turned out to hold binary data — see
  /// [isBinaryPayload].
  Future<({int imported, int rejected})> importFolder(
    FolderImportSelection selection, {
    String? parentId,
  }) async {
    if (selection.files.isEmpty) return (imported: 0, rejected: 0);
    final root = _createFolderInMemory(
      name: selection.folderName,
      parentId: parentId,
    );
    final folderIds = <String, String>{'': root.id};
    var imported = 0;
    var rejected = 0;

    for (final file in selection.files) {
      if (isBinaryPayload(file.bytes)) {
        rejected++;
        continue;
      }
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
    return (imported: imported, rejected: rejected);
  }

  LibraryDocument? documentById(String id) {
    final index = _liveDocumentIndex(id);
    return index == -1 ? null : _documents[index];
  }

  /// Index into the raw list, skipping tombstones so a stale screen cannot
  /// revive a document that was deleted elsewhere.
  int _liveDocumentIndex(String id) =>
      _documents.indexWhere((document) => document.id == id && !document.isDeleted);

  int _liveFolderIndex(String id) =>
      _folders.indexWhere((folder) => folder.id == id && !folder.isDeleted);

  LibraryFolder? folderById(String id) {
    final index = _liveFolderIndex(id);
    return index == -1 ? null : _folders[index];
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
      for (final folder in live(_folders)) {
        if (folder.parentId != null &&
            ids.contains(folder.parentId) &&
            ids.add(folder.id)) {
          changed = true;
        }
      }
    }
    return live(_documents)
        .where((document) => ids.contains(document.folderId))
        .length;
  }

  Future<ReadingBookmark> addBookmark(
    String documentId, {
    required int chunkIndex,
    double alignment = 0,
    required String excerpt,
  }) async {
    final bookmark = ReadingBookmark(
      id: _uuid.v4(),
      documentId: documentId,
      chunkIndex: chunkIndex,
      alignment: alignment,
      excerpt: excerpt,
      createdAt: DateTime.now(),
    );
    _bookmarks.add(bookmark);
    await _persistBookmarks();
    notifyListeners();
    return bookmark;
  }

  Future<void> removeBookmark(String id) async {
    final index = _bookmarks.indexWhere(
      (bookmark) => bookmark.id == id && !bookmark.isDeleted,
    );
    if (index == -1) return;
    final now = DateTime.now();
    _bookmarks[index] = _bookmarks[index].copyWith(
      updatedAt: now,
      deletedAt: now,
    );
    await _persistBookmarks();
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    // Persist the sync preferences locally *before* saving, so that turning
    // sync off takes effect immediately (this very save must not be pushed)
    // and a new server address is used from here on.
    await _storage.saveSyncConfig(
      SyncConfig(
        enabled: settings.syncEnabled,
        serverUrl: settings.syncServerUrl,
      ),
    );
    await _storage.saveSettings(settings);
    notifyListeners();
  }

  /// Probes a server address on behalf of the settings screen.
  Future<SyncTestResult> testSyncConnection(String serverUrl) =>
      _storage.testConnection(serverUrl);

  /// Erases the server's copy of the library, using the sync settings that
  /// are still in force. Must be called *before* sync is turned off, and
  /// reports whether it actually succeeded.
  Future<bool> clearServerCopy() => _storage.clearServer(
    SyncConfig(
      enabled: _settings.syncEnabled,
      serverUrl: _settings.syncServerUrl,
    ),
  );

  /// Timestamp of the last successful exchange with the server, if any.
  Future<DateTime?> lastSyncAt() => _storage.loadLastSyncAt();

  /// Explicit user-triggered "force sync": pulls documents, folders and
  /// settings from the server unconditionally (an empty response is taken
  /// at face value here, unlike the cautious startup load) and replaces the
  /// in-memory state with it. Wired to the pull-to-refresh gesture on the
  /// library screen.
  Future<SyncRunResult> forceSync() async {
    if (!await _storage.isSyncEnabled()) return SyncRunResult.disabled;
    final result = await _storage.forcePull();
    _documents
      ..clear()
      ..addAll(result.documents);
    _folders
      ..clear()
      ..addAll(result.folders);
    _bookmarks
      ..clear()
      ..addAll(result.bookmarks);
    _settings = result.settings;
    notifyListeners();
    return result.reachedServer ? SyncRunResult.done : SyncRunResult.failed;
  }

  @override
  void dispose() {
    voiceDownloads.dispose();
    super.dispose();
  }

  Future<void> _persistDocuments() => _storage.saveDocuments(_documents);

  Future<void> _persistFolders() => _storage.saveFolders(_folders);

  Future<void> _persistBookmarks() => _storage.saveBookmarks(_bookmarks);

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
    final names = live(_folders)
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

- Importe arquivos `.md`, `.txt`, `.html` ou arquivos de código.
- Crie um Markdown direto na biblioteca, em qualquer pasta.
- Ajuste fonte, tamanho, entrelinha, largura e cores da leitura.
- Ative o **modo leitura** para esconder as ferramentas e travar a edição.
- Exporte seu texto quando quiser — ele continua sendo seu.

> A melhor interface de leitura é aquela que desaparece quando o texto começa.

## Ouvir em vez de ler

No modo leitura, o botão de fone lê o documento em voz alta.

- Se o texto tem títulos `#` ou `##`, dá para escolher **de qual capítulo começar** — ou continuar de onde você parou.
- A voz padrão é a do próprio Android ou do navegador: não baixa nada e funciona sem internet.
- Em **Configurações → Leitura em voz alta** dá para mudar a **velocidade**, trocar de voz, e baixar uma **voz neural** que roda no próprio aparelho, sem mandar seu texto para servidor nenhum. São 35 vozes em 14 idiomas, em dois níveis: Piper (~80 MB, leve) e Kokoro (~400 MB, mais natural).

## Marcadores

Ainda no modo leitura, marque onde você parou e volte depois pela lista de marcadores. A marcação fica presa ao trecho do texto, não a uma posição de rolagem — ela não escorrega quando o documento muda de tamanho.

## Documentos grandes

Textos muito longos são editados **por partes**, seguindo os capítulos do próprio arquivo, para a digitação não travar. O arquivo salvo continua inteiro, e o modo leitura mostra tudo de uma vez.

## O que ele entende

Títulos, **negrito**, *itálico*, ~~riscado~~, listas, tarefas, citações, tabelas, links, imagens, notas de rodapé e código com destaque de sintaxe:

```dart
void main() {
  print('Olá, Sépia!');
}
```

| Atalho | O que faz |
|---|---|
| Puxar a biblioteca para baixo | Sincroniza com o servidor |
| Tocar no título | Renomeia o documento |
| Configurações → Tamanho da interface | Deixa tudo maior ou menor |

Boa leitura. ☕
''';

const _welcomeDocumentEn = '''# Welcome to Sépia

A calm place to **read, write, and keep** your texts.

## Start here

- Import `.md`, `.txt`, `.html`, or source-code files.
- Create a Markdown document straight in the library, in any folder.
- Adjust the font, size, line height, width, and colours for your reading.
- Turn on **reading mode** to hide the tools and lock editing.
- Export your text whenever you want — it remains yours.

> The best reading interface disappears when the text begins.

## Listen instead of reading

In reading mode, the headphone button reads the document out loud.

- If the text has `#` or `##` headings, you can pick **which chapter to start from** — or carry on from where you stopped.
- The default voice is the one Android or your browser already has: nothing to download, and it works offline.
- Under **Settings → Read aloud** you can change the **speed**, switch voices, and download a **neural voice** that runs on the device itself, without sending your text to any server. Thirty-five voices across fourteen languages, in two tiers: Piper (~80 MB, light) and Kokoro (~400 MB, more natural).

## Bookmarks

Still in reading mode, mark where you stopped and come back later from the bookmark list. A bookmark is anchored to the passage, not to a scroll position — it does not drift when the document changes size.

## Long documents

Very long texts are edited **in parts**, following the file's own chapters, so typing stays responsive. The saved file remains whole, and reading mode shows all of it at once.

## What it understands

Headings, **bold**, *italic*, ~~strikethrough~~, lists, tasks, quotes, tables, links, images, footnotes, and code with syntax highlighting:

```dart
void main() {
  print('Hello, Sépia!');
}
```

| Shortcut | What it does |
|---|---|
| Pull the library down | Syncs with the server |
| Tap the title | Renames the document |
| Settings → Interface size | Makes everything bigger or smaller |

Enjoy your reading. ☕
''';
