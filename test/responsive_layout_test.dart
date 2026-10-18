import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/app.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/models/library_document.dart';
import 'package:sepia_reader/models/library_folder.dart';
import 'package:sepia_reader/state/app_controller.dart';

import 'support/offline_updates.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final width in [320.0, 768.0]) {
    for (final layout in ['standard', 'grid', 'list']) {
      testWidgets('$layout at $width with enlarged interface and long names', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final now = DateTime.utc(2026);
        SharedPreferences.setMockInitialValues({
          'sepia.settings.v1': jsonEncode(
            AppSettings(
              localeCode: 'pt_BR',
              uiScale: 1.4,
              libraryLayout: layout,
              ttsEnabled: false,
            ).toJson(),
          ),
          'sepia.documents.v1': jsonEncode([
            LibraryDocument(
              id: 'a',
              title: 'Um nome bastante longo para testar várias linhas e os limites do cartão',
              extension: 'md',
              content: 'Exemplo de conteúdo para leitura.',
              createdAt: now,
              updatedAt: now,
            ).toJson(),
          ]),
          'sepia.folders.v1': jsonEncode([
            LibraryFolder(
              id: 'f',
              name: 'Uma pasta com um nome bem longo para caber em mais de uma linha',
              createdAt: now,
              updatedAt: now,
            ).toJson(),
          ]),
        });
        final controller = AppController(updateChecker: offlineUpdateChecker());
        await controller.initialize();
        await tester.pumpWidget(SepiaApp(controller: controller));
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -450),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Configurações'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
