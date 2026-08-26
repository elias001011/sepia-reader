import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sepia_reader/app.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/state/app_controller.dart';
import 'package:sepia_reader/widgets/sheet_scaffold.dart';

import 'support/offline_updates.dart';

/// The settings sheet on a phone: it must stay a panel rather than swallow
/// the screen, and it must not throw away changes on the way out.
void main() {
  /// Bounded pumps instead of pumpAndSettle: the voice picker spins while it
  /// looks for platform voices, and a widget test has no speech plugin to
  /// answer it, so nothing ever settles.
  Future<void> settle(WidgetTester tester, [int frames = 12]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<AppController> openSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 44 * 1);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    SharedPreferences.setMockInitialValues({
      'sepia.settings.v1': jsonEncode(
        const AppSettings(localeCode: 'pt_BR').toJson(),
      ),
    });
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();
    await tester.pumpWidget(SepiaApp(controller: controller));
    await settle(tester);
    await tester.tap(find.byTooltip('Configurações'));
    await settle(tester);
    return controller;
  }

  testWidgets('a folha não encosta no topo da tela', (tester) async {
    await openSettings(tester);
    final sheet = tester.getRect(find.byType(SheetScaffold));
    // The status bar inset is 44; the sheet must start below it with room
    // to spare, so the notch and camera stay clear.
    expect(
      sheet.top,
      greaterThan(44),
      reason: 'the sheet reached over the status bar and the camera',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sair sem salvar pergunta, e salvar aplica', (tester) async {
    final controller = await openSettings(tester);
    expect(controller.settings.uiScale, 1);

    // Change something: drag the interface-size slider.
    final slider = find.byType(Slider).first;
    await tester.drag(slider, const Offset(60, 0));
    await tester.pump();
    final changed = tester.widget<Slider>(slider).value;
    expect(changed, greaterThan(1));

    // Closing now must ask rather than discard silently.
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await settle(tester);
    expect(find.text('Sair sem salvar?'), findsOneWidget);

    await tester.tap(find.text('Salvar e sair'));
    await settle(tester);
    expect(controller.settings.uiScale, changed);
    expect(find.byType(SheetScaffold), findsNothing);
  });

  testWidgets('descartar sai sem aplicar', (tester) async {
    final controller = await openSettings(tester);
    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await settle(tester);
    await tester.tap(find.text('Sair sem salvar'));
    await settle(tester);

    expect(controller.settings.uiScale, 1);
    expect(find.byType(SheetScaffold), findsNothing);
  });

  testWidgets('sem mudança nenhuma, fecha direto', (tester) async {
    await openSettings(tester);
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await settle(tester);
    expect(find.text('Sair sem salvar?'), findsNothing);
    expect(find.byType(SheetScaffold), findsNothing);
  });
}
