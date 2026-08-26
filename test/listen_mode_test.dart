import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sepia_reader/app.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/state/app_controller.dart';
import 'package:sepia_reader/widgets/markdown_view.dart';

import 'support/offline_updates.dart';

/// Reading aloud is opt-in: nothing about the reader changes until it is
/// switched on, and once it is, the button leads to a chapter picker rather
/// than starting from the top of the document every time.
void main() {
  Future<AppController> openReader(
    WidgetTester tester, {
    required bool ttsEnabled,
    required String content,
  }) async {
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'sepia.settings.v1': jsonEncode(
        AppSettings(localeCode: 'pt_BR', ttsEnabled: ttsEnabled).toJson(),
      ),
    });
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();
    await controller.createDocument(title: 'Fic', content: content);

    await tester.pumpWidget(SepiaApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Fic.md'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fic.md'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Modo leitura'));
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('sem a opção ligada, o modo leitura não ganha botão de ouvir', (
    tester,
  ) async {
    await openReader(tester, ttsEnabled: false, content: '# Um\n\nTexto.');
    expect(find.byTooltip('Ouvir'), findsNothing);
  });

  testWidgets('com a opção ligada, o botão abre a escolha de capítulo', (
    tester,
  ) async {
    await openReader(
      tester,
      ttsEnabled: true,
      content: '# Capítulo um\n\nTexto.\n\n## Capítulo dois\n\nMais texto.',
    );
    expect(find.byTooltip('Ouvir'), findsOneWidget);

    await tester.tap(find.byTooltip('Ouvir'));
    await tester.pumpAndSettle();

    expect(find.text('Ouvir a partir de'), findsOneWidget);
    expect(find.text('2 capítulos'), findsOneWidget);
    expect(find.text('Ler o documento inteiro'), findsOneWidget);
    expect(find.text('Capítulo um'), findsWidgets);
    expect(find.text('Capítulo dois'), findsWidgets);
  });

  testWidgets('html abre em prévia e alterna para o código', (tester) async {
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'sepia.settings.v1': jsonEncode(
        const AppSettings(localeCode: 'pt_BR').toJson(),
      ),
    });
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();
    await controller.createDocument(
      title: 'Pagina',
      extension: 'html',
      content: '<h1>Um titulo</h1><p>Um <strong>paragrafo</strong>.</p>',
    );

    await tester.pumpWidget(SepiaApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pagina.html'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pagina.html'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Modo leitura'));
    await tester.pumpAndSettle();

    // Preview: the markup is rendered, not spelled out.
    expect(find.text('Um titulo'), findsOneWidget);
    expect(find.textContaining('<h1>'), findsNothing);

    await tester.tap(find.byTooltip('Código'));
    await tester.pumpAndSettle();

    // Source: the tags are back, in the numbered code viewer.
    expect(find.byType(CodeViewer), findsOneWidget);
    expect(find.textContaining('<h1>'), findsOneWidget);
  });

  testWidgets('documento sem títulos só oferece ler tudo', (tester) async {
    await openReader(
      tester,
      ttsEnabled: true,
      content: 'Só texto corrido.\n\nOutro parágrafo.',
    );
    await tester.tap(find.byTooltip('Ouvir'));
    await tester.pumpAndSettle();

    expect(find.text('Ler o documento inteiro'), findsOneWidget);
    expect(
      find.textContaining('não tem capítulos'),
      findsOneWidget,
      reason: 'says why there is nothing to choose from',
    );
  });
}
