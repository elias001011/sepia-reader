import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/models/folder_import.dart';
import 'package:sepia_reader/services/folder_import_rules.dart';
import 'package:sepia_reader/state/app_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'sepia.settings.v1': jsonEncode(
        const AppSettings(localeCode: 'pt_BR').toJson(),
      ),
    });
  });

  test('cria, renomeia e move documentos entre pasta e raiz', () async {
    final controller = AppController();
    await controller.initialize();
    final folder = await controller.createFolder(name: 'Fics');
    final document = await controller.createDocument(
      title: 'Capítulo',
      folderId: folder.id,
    );

    expect(controller.documentsIn(folder.id).single.id, document.id);
    await controller.renameFolder(folder.id, 'Leituras');
    expect(controller.folderById(folder.id)?.name, 'Leituras');
    await controller.renameDocument(document.id, 'Capítulo revisado.md');
    expect(controller.documentById(document.id)?.title, 'Capítulo revisado');
    expect(controller.documentById(document.id)?.extension, 'md');

    await controller.moveDocument(document.id, null);
    expect(controller.documentById(document.id)?.folderId, isNull);
    expect(
      controller.documentsIn(null).map((item) => item.id),
      contains(document.id),
    );

    final restored = AppController();
    await restored.initialize();
    expect(restored.folderById(folder.id)?.name, 'Leituras');
    expect(restored.documentById(document.id)?.title, 'Capítulo revisado');
    expect(restored.documentById(document.id)?.folderId, isNull);
  });

  test('importa uma árvore de pastas preservando os caminhos', () async {
    final controller = AppController();
    await controller.initialize();
    final imported = await controller.importFolder(
      FolderImportSelection(
        folderName: 'Minha fic',
        skippedFiles: 1,
        files: [
          FolderImportFile(
            relativePath: 'README.md',
            bytes: Uint8List.fromList(utf8.encode('# Início')),
          ),
          FolderImportFile(
            relativePath: 'capitulos/01.md',
            bytes: Uint8List.fromList(utf8.encode('Capítulo um')),
          ),
        ],
      ),
    );

    expect(imported.imported, 2);
    expect(imported.rejected, 0);
    final root = controller.foldersIn(null).single;
    final chapterFolder = controller.foldersIn(root.id).single;
    expect(root.name, 'Minha fic');
    expect(chapterFolder.name, 'capitulos');
    expect(controller.documentsIn(root.id).single.title, 'README');
    expect(
      controller.documentsIn(chapterFolder.id).single.content,
      'Capítulo um',
    );
    expect(controller.folderDocumentCount(root.id), 2);
  });

  test('filtra somente extensões compatíveis', () {
    expect(isSupportedDocumentPath('livro/capitulo.md'), isTrue);
    expect(isSupportedDocumentPath('codigo/EXEMPLO.DART'), isTrue);
    expect(isSupportedDocumentPath('imagem.png'), isFalse);
    expect(isSupportedDocumentPath('sem-extensao'), isFalse);
  });
}
