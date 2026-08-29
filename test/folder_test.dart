import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/models/folder_import.dart';
import 'package:sepia_reader/services/folder_import_rules.dart';
import 'package:sepia_reader/state/app_controller.dart';

import 'support/offline_updates.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'sepia.settings.v1': jsonEncode(
        const AppSettings(localeCode: 'pt_BR').toJson(),
      ),
    });
  });

  test('cria, renomeia e move documentos entre pasta e raiz', () async {
    final controller = AppController(updateChecker: offlineUpdateChecker());
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

    final restored = AppController(updateChecker: offlineUpdateChecker());
    await restored.initialize();
    expect(restored.folderById(folder.id)?.name, 'Leituras');
    expect(restored.documentById(document.id)?.title, 'Capítulo revisado');
    expect(restored.documentById(document.id)?.folderId, isNull);
  });

  test('move uma pasta para dentro de outra e persiste', () async {
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();
    final outer = await controller.createFolder(name: 'Fora');
    final inner = await controller.createFolder(name: 'Dentro');
    final doc = await controller.createDocument(
      title: 'Capítulo',
      folderId: inner.id,
    );

    await controller.moveFolder(inner.id, outer.id);

    expect(controller.folderById(inner.id)?.parentId, outer.id);
    expect(controller.foldersIn(outer.id).single.id, inner.id);
    // O documento continua na subpasta, agora aninhada.
    expect(controller.documentsIn(inner.id).single.id, doc.id);
    expect(controller.folderDocumentCount(outer.id), 1);

    final restored = AppController(updateChecker: offlineUpdateChecker());
    await restored.initialize();
    expect(restored.folderById(inner.id)?.parentId, outer.id);
  });

  test('não deixa mover uma pasta para dentro de si mesma ou de um filho', () async {
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();
    final parent = await controller.createFolder(name: 'Pai');
    final child = await controller.createFolder(
      name: 'Filho',
      parentId: parent.id,
    );

    expect(controller.canMoveFolderInto(parent.id, parent.id), isFalse);
    expect(controller.canMoveFolderInto(parent.id, child.id), isFalse);

    await controller.moveFolder(parent.id, child.id);
    expect(controller.folderById(parent.id)?.parentId, isNull);
  });

  test('move uma seleção mista de pasta e documento de uma vez', () async {
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();
    final destination = await controller.createFolder(name: 'Destino');
    final loose = await controller.createFolder(name: 'Solta');
    final doc = await controller.createDocument(title: 'Avulso');

    await controller.moveEntries(
      folderIds: {loose.id},
      documentIds: {doc.id},
      destinationParentId: destination.id,
    );

    expect(controller.folderById(loose.id)?.parentId, destination.id);
    expect(controller.documentById(doc.id)?.folderId, destination.id);
  });

  test('exclui uma seleção mista, com tudo que as pastas contêm', () async {
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();
    final folder = await controller.createFolder(name: 'Pasta');
    final nested = await controller.createFolder(
      name: 'Aninhada',
      parentId: folder.id,
    );
    final insideNested = await controller.createDocument(
      title: 'Dentro da aninhada',
      folderId: nested.id,
    );
    final loneDoc = await controller.createDocument(title: 'Sozinho');

    await controller.deleteEntries(
      folderIds: {folder.id},
      documentIds: {loneDoc.id},
    );

    expect(controller.folderById(folder.id), isNull);
    expect(controller.folderById(nested.id), isNull);
    expect(controller.documentById(insideNested.id), isNull);
    expect(controller.documentById(loneDoc.id), isNull);

    final restored = AppController(updateChecker: offlineUpdateChecker());
    await restored.initialize();
    expect(restored.folderById(folder.id), isNull);
    expect(restored.documentById(insideNested.id), isNull);
  });

  test('importa uma árvore de pastas preservando os caminhos', () async {
    final controller = AppController(updateChecker: offlineUpdateChecker());
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

  test('importação sem nenhum arquivo aproveitável não cria pasta', () async {
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();
    final foldersBefore = controller.foldersIn(null).length;

    final result = await controller.importFolder(
      FolderImportSelection(
        folderName: 'Só binários',
        skippedFiles: 0,
        files: [
          // ".md" by name, ZIP (PK\x03\x04) by content — rejected as binary.
          FolderImportFile(
            relativePath: 'nested/a.md',
            bytes: Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 1, 2, 3, 4]),
          ),
          FolderImportFile(
            relativePath: 'b.md',
            bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 13, 10]),
          ),
        ],
      ),
    );

    expect(result.imported, 0);
    expect(result.rejected, 2);
    expect(controller.foldersIn(null).length, foldersBefore);

    final restored = AppController(updateChecker: offlineUpdateChecker());
    await restored.initialize();
    expect(restored.foldersIn(null).length, foldersBefore);
  });

  test('filtra somente extensões compatíveis', () {
    expect(isSupportedDocumentPath('livro/capitulo.md'), isTrue);
    expect(isSupportedDocumentPath('codigo/EXEMPLO.DART'), isTrue);
    expect(isSupportedDocumentPath('imagem.png'), isFalse);
    expect(isSupportedDocumentPath('sem-extensao'), isFalse);
  });
}
