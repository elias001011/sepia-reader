import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/app.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/models/library_document.dart';
import 'package:sepia_reader/models/library_folder.dart';
import 'package:sepia_reader/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/offline_updates.dart';

void main() {
  testWidgets('a biblioteca constrói só os cartões próximos da tela', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final documents = List.generate(
      200,
      (index) => LibraryDocument(
        id: 'd$index',
        title: 'Documento $index',
        content: 'Conteúdo $index ' * 100,
        extension: 'md',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026, 8, 31, 0, index),
      ),
    );
    SharedPreferences.setMockInitialValues({
      'sepia.settings.v1': jsonEncode(
        const AppSettings(localeCode: 'pt_BR').toJson(),
      ),
      'sepia.syncconfig.v1': jsonEncode({
        'syncEnabled': false,
        'syncServerUrl': '',
      }),
      'sepia.documents.v1': jsonEncode(
        documents.map((document) => document.toJson()).toList(),
      ),
    });
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();

    await tester.pumpWidget(SepiaApp(controller: controller));
    await tester.pumpAndSettle();

    final builtTitles = find.byWidgetPredicate(
      (widget) => widget is Text &&
          widget.data != null &&
          widget.data!.startsWith('Documento ') &&
          widget.data!.endsWith('.md'),
    );
    expect(
      builtTitles.evaluate().length,
      lessThan(40),
      reason: 'um grid shrinkWrap materializa os 200 cartões de uma vez',
    );
  });

  testWidgets('abrir pasta não calcula palavras de cada documento', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _LibraryController(
      folders: [
        LibraryFolder(
          id: 'folder',
          name: 'Capítulos',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
      documents: List.generate(
        6,
        (index) => _WordCountTrapDocument(
          id: 'd$index',
          title: 'Capítulo $index',
          content: 'texto grande ' * 50000,
          folderId: 'folder',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026, 8, 31, 0, index),
        ),
      ),
    );

    await tester.pumpWidget(SepiaApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capítulos'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Capítulo 0.md'), findsOneWidget);
  });

  testWidgets('pesquisa de conteúdo publica o resultado assíncrono', (
    tester,
  ) async {
    final documents = List.generate(
      8,
      (index) => LibraryDocument(
        id: 'search-$index',
        title: 'Arquivo $index',
        content: '${'conteúdo comum ' * 10000}${index == 6 ? 'agulha' : ''}',
        extension: 'md',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026, 8, 31, 0, index),
      ),
    );
    SharedPreferences.setMockInitialValues({
      'sepia.settings.v1': jsonEncode(
        const AppSettings(localeCode: 'pt_BR').toJson(),
      ),
      'sepia.syncconfig.v1': jsonEncode({
        'syncEnabled': false,
        'syncServerUrl': '',
      }),
      'sepia.documents.v1': jsonEncode(
        documents.map((document) => document.toJson()).toList(),
      ),
    });
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();

    await tester.pumpWidget(SepiaApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'agulha');
    await tester.pump(const Duration(milliseconds: 200));
    for (var i = 0; i < 100 && find.text('Arquivo 6.md').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text('Arquivo 6.md'), findsOneWidget);
    expect(find.text('Arquivo 5.md'), findsNothing);
  });
}

class _LibraryController extends AppController {
  _LibraryController({
    required List<LibraryDocument> documents,
    required List<LibraryFolder> folders,
  })  : documentsValue = documents,
        foldersValue = folders,
        super(updateChecker: offlineUpdateChecker());

  final List<LibraryDocument> documentsValue;
  final List<LibraryFolder> foldersValue;

  @override
  List<LibraryDocument> get documents => documentsValue;

  @override
  List<LibraryFolder> get folders => foldersValue;

  @override
  LibraryDocument? documentById(String id) {
    for (final document in documentsValue) {
      if (document.id == id) return document;
    }
    return null;
  }
}

class _WordCountTrapDocument extends LibraryDocument {
  _WordCountTrapDocument({
    required super.id,
    required super.title,
    required super.content,
    required super.createdAt,
    required super.updatedAt,
    required super.folderId,
  }) : super(extension: 'md');

  @override
  int get wordCount => throw StateError(
        'a construção do cartão não pode varrer o documento inteiro',
      );
}
