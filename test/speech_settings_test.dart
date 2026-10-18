import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sepia_reader/l10n/app_localizations.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/screens/speech_settings_sheet.dart';
import 'package:sepia_reader/state/app_controller.dart';
import 'package:sepia_reader/widgets/sheet_scaffold.dart';

import 'support/offline_updates.dart';

void main() {
  for (final supportsPitch in [true, false]) {
    testWidgets('speech controls fit narrow screens; pitch=$supportsPitch', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
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
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.4)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAppSheet<bool>(
                  context: context,
                  builder: (_) => SpeechSettingsSheet(
                    controller: controller,
                    supportsPitch: supportsPitch,
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Velocidade'), findsOneWidget);
      expect(find.text('Tom'), supportsPitch ? findsOneWidget : findsNothing);
      expect(find.byType(Slider), findsNWidgets(supportsPitch ? 2 : 1));
      final slider = tester.widget<Slider>(find.byType(Slider).first);
      slider.onChanged!(1.5);
      await tester.pump();
      expect(find.text('1.50x'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(controller.settings.ttsRate, 1.5);
      expect(find.byType(SpeechSettingsSheet), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
}
