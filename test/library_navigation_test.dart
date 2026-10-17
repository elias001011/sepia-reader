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

/// Root holds 60 documents and one folder; the folder holds 60 more.
Future<AppController> _seed() async {
  final stamp = DateTime(2026, 8, 31);
  final documents = [
    for (var i = 0; i < 60; i++)
      LibraryDocument(
        id: 'r$i',
        title: 'Raiz $i',
        content: 'Texto $i',
        extension: 'md',
        createdAt: stamp,
        updatedAt: stamp,
      ),
    for (var i = 0; i < 60; i++)
      LibraryDocument(
        id: 'f$i',
        title: 'Dentro $i',
        content: 'Texto $i',
        extension: 'md',
        folderId: 'pasta',
        createdAt: stamp,
        updatedAt: stamp,
      ),
  ];
  SharedPreferences.setMockInitialValues({
    'sepia.settings.v1': jsonEncode(
      const AppSettings(localeCode: 'pt_BR').toJson(),
    ),
    'sepia.syncconfig.v1': jsonEncode({
      'syncEnabled': false,
      'syncServerUrl': '',
    }),
    'sepia.folders.v1': jsonEncode([
      LibraryFolder(
        id: 'pasta',
        name: 'Capítulos',
        createdAt: stamp,
        updatedAt: stamp,
      ).toJson(),
    ]),
    'sepia.documents.v1': jsonEncode(
      documents.map((document) => document.toJson()).toList(),
    ),
  });
  final controller = AppController(updateChecker: offlineUpdateChecker());
  await controller.initialize();
  return controller;
}

ScrollController _library(WidgetTester tester) =>
    tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;

void _phoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'entrar numa pasta mantém a posição da rolagem e voltar à raiz a restaura',
    (tester) async {
      _phoneView(tester);
      final controller = await _seed();
      await tester.pumpWidget(SepiaApp(controller: controller));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
      await tester.pumpAndSettle();
      final rootOffset = _library(tester).offset;
      expect(rootOffset, greaterThan(0));

      await tester.tap(find.text('Capítulos'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Dentro 0.'), findsOneWidget);
      expect(_library(tester).offset, closeTo(rootOffset, 0.5));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(_library(tester).offset, greaterThan(0));

      final offsetInFolder = _library(tester).offset;
      await tester.tap(find.text('Raiz da biblioteca'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Raiz '), findsWidgets);
      expect(_library(tester).offset, closeTo(offsetInFolder, 0.5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('os chips de arquivos e pastas levam à seção certa', (
    tester,
  ) async {
    _phoneView(tester);
    final controller = await _seed();
    await tester.pumpWidget(SepiaApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ActionChip, '60 arquivos'));
    await tester.pumpAndSettle();
    final filesOffset = _library(tester).offset;
    expect(filesOffset, greaterThan(0));
    // The files start right under the header, not at the bottom of the screen.
    final firstFile = tester.getTopLeft(find.textContaining('Raiz ').first).dy;
    expect(firstFile, lessThan(400));

    // The chips scroll with the list, so go back up to reach the other one.
    _library(tester).jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, '1 pasta'));
    await tester.pumpAndSettle();
    expect(_library(tester).offset, lessThan(filesOffset));
    expect(tester.getTopLeft(find.text('Capítulos')).dy, lessThan(400));
    expect(tester.takeException(), isNull);
  });
}
