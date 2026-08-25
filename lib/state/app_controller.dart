import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/app_settings.dart';
import '../models/library_document.dart';
import '../services/storage_service.dart';

class AppController extends ChangeNotifier {
  AppController({StorageService? storage})
    : _storage = storage ?? StorageService();
  final StorageService _storage;
  final Uuid _uuid = const Uuid();
  final List<LibraryDocument> _documents = [];
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

  Future<void> initialize() async {
    _settings = await _storage.loadSettings();
    _documents.addAll(await _storage.loadDocuments());
    if (_documents.isEmpty) {
      final now = DateTime.now();
      _documents.add(
        LibraryDocument(
          id: _uuid.v4(),
          title: 'Bem-vindo ao Sépia',
          extension: 'md',
          createdAt: now,
          updatedAt: now,
          content: _welcomeDocument,
        ),
      );
      await _persistDocuments();
    }
  }

  Future<LibraryDocument> createDocument({
    required String title,
    String extension = 'md',
    String content = '',
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
      title: cleanTitle.isEmpty ? 'Sem título' : cleanTitle,
      content: content,
      extension: ext,
      createdAt: now,
      updatedAt: now,
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

  LibraryDocument? documentById(String id) {
    try {
      return _documents.firstWhere((document) => document.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    await _storage.saveSettings(settings);
    notifyListeners();
  }

  Future<void> _persistDocuments() => _storage.saveDocuments(_documents);
}

const _welcomeDocument = '''# Bem-vindo ao Sépia

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
