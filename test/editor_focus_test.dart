import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sepia_reader/app.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/state/app_controller.dart';

import 'support/offline_updates.dart';

/// The document title used to be a live [TextField] in the editor's AppBar,
/// which made it the first focusable node of the route: whenever a modal
/// sheet on top of the editor closed, focus restoration landed there, the
/// title got selected and the soft keyboard came up as if a rename had been
/// asked for. It is a plain label now, so there is nothing to land on —
/// these tests pin both halves of that: no editable title by default, and
/// still an editable one when the user actually taps it.
void main() {
  Future<void> openEditor(WidgetTester tester) async {
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
    await tester.pumpWidget(SepiaApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bem-vindo ao Sépia.md'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bem-vindo ao Sépia.md'));
    await tester.pumpAndSettle();
  }

  Finder appBarTitle() => find.descendant(
    of: find.byType(AppBar),
    matching: find.text('Bem-vindo ao Sépia'),
  );

  Finder appBarEditable() => find.descendant(
    of: find.byType(AppBar),
    matching: find.byType(EditableText),
  );

  testWidgets('o título é um rótulo, não um campo sempre editável', (
    tester,
  ) async {
    await openEditor(tester);
    expect(appBarTitle(), findsOneWidget);
    expect(appBarEditable(), findsNothing);
  });

  testWidgets('fechar os ajustes de leitura não abre o teclado no título', (
    tester,
  ) async {
    await openEditor(tester);

    await tester.tap(find.byTooltip('Ajustes de leitura'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sépia'));
    await tester.pumpAndSettle();
    final apply = find.widgetWithText(FilledButton, 'Aplicar na leitura');
    await tester.dragUntilVisible(
      apply,
      find.byType(SingleChildScrollView).last,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(apply);
    await tester.pumpAndSettle();

    expect(
      appBarEditable(),
      findsNothing,
      reason: 'closing a sheet must not turn the title into a live field',
    );
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('tocar no título ainda permite renomear', (tester) async {
    await openEditor(tester);
    await tester.tap(appBarTitle());
    await tester.pumpAndSettle();
    expect(appBarEditable(), findsOneWidget);
    await tester.enterText(appBarEditable(), 'Minha fic');
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Minha fic')), findsOneWidget);
  });
}
