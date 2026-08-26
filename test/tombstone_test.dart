import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sepia_reader/models/app_settings.dart';
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

  test('documento apagado some da biblioteca e das buscas por id', () async {
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();
    final document = await controller.createDocument(title: 'Fic');

    await controller.deleteDocument(document.id);

    expect(
      controller.documents.where((item) => item.id == document.id),
      isEmpty,
    );
    expect(controller.documentById(document.id), isNull);
  });

  test('apagar o documento também esconde seus marcadores', () async {
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();
    final document = await controller.createDocument(title: 'Fic');
    await controller.addBookmark(
      document.id,
      chunkIndex: 0,
      excerpt: 'onde parei',
    );
    expect(controller.bookmarksForDocument(document.id), hasLength(1));

    await controller.deleteDocument(document.id);

    expect(controller.bookmarksForDocument(document.id), isEmpty);
  });

  test('marcador removido não reaparece na lista', () async {
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();
    final document = await controller.createDocument(title: 'Fic');
    final bookmark = await controller.addBookmark(
      document.id,
      chunkIndex: 0,
      excerpt: 'trecho',
    );

    await controller.removeBookmark(bookmark.id);

    expect(controller.bookmarksForDocument(document.id), isEmpty);
  });

  test('pasta cujos documentos foram apagados conta como vazia', () async {
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();
    final folder = await controller.createFolder(name: 'Fics');
    final document = await controller.createDocument(
      title: 'Capítulo 1',
      folderId: folder.id,
    );
    expect(controller.folderContents(folder.id).documents, hasLength(1));

    await controller.deleteDocument(document.id);

    expect(controller.folderDocumentCount(folder.id), 0);
    expect(controller.folderContents(folder.id).documents, isEmpty);
    await controller.deleteFolder(folder.id);
    expect(controller.folders.where((item) => item.id == folder.id), isEmpty);
    expect(controller.folderById(folder.id), isNull);
  });

  test('apagar pasta com conteúdo leva subpastas e documentos junto', () async {
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();
    final parent = await controller.createFolder(name: 'Fics');
    final child = await controller.createFolder(
      name: 'Capítulos',
      parentId: parent.id,
    );
    final inParent = await controller.createDocument(
      title: 'Sinopse',
      folderId: parent.id,
    );
    final inChild = await controller.createDocument(
      title: 'Capítulo 1',
      folderId: child.id,
    );
    final outside = await controller.createDocument(title: 'Outra coisa');

    final contents = controller.folderContents(parent.id);
    expect(contents.folderIds, {parent.id, child.id});
    expect(contents.documents.map((d) => d.id).toSet(), {
      inParent.id,
      inChild.id,
    });

    await controller.deleteFolder(parent.id);

    expect(controller.folderById(parent.id), isNull);
    expect(controller.folderById(child.id), isNull);
    expect(controller.documentById(inParent.id), isNull);
    expect(controller.documentById(inChild.id), isNull);
    // Anything outside the folder is untouched.
    expect(controller.documentById(outside.id), isNotNull);

    // The deletions travel as tombstones, so another device learns about
    // them instead of pushing the records back.
    final restored = AppController(updateChecker: offlineUpdateChecker());
    await restored.initialize();
    expect(restored.folderById(parent.id), isNull);
    expect(restored.documentById(inChild.id), isNull);
    expect(restored.documentById(outside.id), isNotNull);
  });

  test('nome de pasta apagada volta a ficar livre', () async {
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();
    final first = await controller.createFolder(name: 'Fics');
    await controller.deleteFolder(first.id);

    final second = await controller.createFolder(name: 'Fics');

    expect(second.name, 'Fics');
  });

  test('biblioteca esvaziada recria o documento de boas-vindas', () async {
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();
    for (final document in controller.documents) {
      await controller.deleteDocument(document.id);
    }
    expect(controller.documents, isEmpty);

    final reopened = AppController(updateChecker: offlineUpdateChecker());
    await reopened.initialize();

    expect(reopened.documents, hasLength(1));
    expect(reopened.documents.single.title, 'Bem-vindo ao Sépia');
  });
}
