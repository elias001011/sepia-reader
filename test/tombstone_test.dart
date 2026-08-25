import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/state/app_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'sepia.settings.v1': jsonEncode(
        const AppSettings(localeCode: 'pt_BR').toJson(),
      ),
    });
  });

  test('documento apagado some da biblioteca e das buscas por id', () async {
    final controller = AppController();
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
    final controller = AppController();
    await controller.initialize();
    final document = await controller.createDocument(title: 'Fic');
    await controller.addBookmark(
      document.id,
      scrollFraction: .5,
      excerpt: 'onde parei',
    );
    expect(controller.bookmarksForDocument(document.id), hasLength(1));

    await controller.deleteDocument(document.id);

    expect(controller.bookmarksForDocument(document.id), isEmpty);
  });

  test('marcador removido não reaparece na lista', () async {
    final controller = AppController();
    await controller.initialize();
    final document = await controller.createDocument(title: 'Fic');
    final bookmark = await controller.addBookmark(
      document.id,
      scrollFraction: .25,
      excerpt: 'trecho',
    );

    await controller.removeBookmark(bookmark.id);

    expect(controller.bookmarksForDocument(document.id), isEmpty);
  });

  test('pasta cujos documentos foram apagados conta como vazia', () async {
    final controller = AppController();
    await controller.initialize();
    final folder = await controller.createFolder(name: 'Fics');
    final document = await controller.createDocument(
      title: 'Capítulo 1',
      folderId: folder.id,
    );
    // Com o documento vivo, a pasta não pode ser apagada.
    expect(await controller.deleteEmptyFolder(folder.id), isFalse);

    await controller.deleteDocument(document.id);

    expect(controller.folderDocumentCount(folder.id), 0);
    expect(await controller.deleteEmptyFolder(folder.id), isTrue);
    expect(controller.folders.where((item) => item.id == folder.id), isEmpty);
    expect(controller.folderById(folder.id), isNull);
  });

  test('nome de pasta apagada volta a ficar livre', () async {
    final controller = AppController();
    await controller.initialize();
    final first = await controller.createFolder(name: 'Fics');
    await controller.deleteEmptyFolder(first.id);

    final second = await controller.createFolder(name: 'Fics');

    expect(second.name, 'Fics');
  });

  test('biblioteca esvaziada recria o documento de boas-vindas', () async {
    final controller = AppController();
    await controller.initialize();
    for (final document in controller.documents) {
      await controller.deleteDocument(document.id);
    }
    expect(controller.documents, isEmpty);

    final reopened = AppController();
    await reopened.initialize();

    expect(reopened.documents, hasLength(1));
    expect(reopened.documents.single.title, 'Bem-vindo ao Sépia');
  });
}
