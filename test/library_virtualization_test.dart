import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/app.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/models/library_document.dart';
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
}
