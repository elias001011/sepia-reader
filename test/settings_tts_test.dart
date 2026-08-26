import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sepia_reader/app.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/state/app_controller.dart';

import 'support/offline_updates.dart';

/// The read-aloud controls have to be *findable* on a phone, which is where
/// this app is actually used: the settings sheet is a bottom sheet with a
/// long scrolling body, and a section that never comes into view might as
/// well not exist.
void main() {
  testWidgets('a seção de leitura em voz alta aparece nas configurações', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
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

    await tester.tap(find.byTooltip('Configurações'));
    // Not pumpAndSettle: the voice list shows a spinner while it looks for
    // voices, and there is no speech plugin in a widget test, so nothing
    // ever settles.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    final sheet = find.byType(SingleChildScrollView).last;
    await tester.dragUntilVisible(
      find.text('Leitura em voz alta'),
      sheet,
      const Offset(0, -150),
    );
    await tester.pump();
    expect(find.text('Leitura em voz alta'), findsOneWidget);
    expect(find.text('Ativar a leitura em voz alta'), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'the sheet must lay out on a 390pt-wide phone without overflow',
    );
  });
}
