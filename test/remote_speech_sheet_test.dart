import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/l10n/app_localizations.dart';
import 'package:sepia_reader/screens/remote_speech_sheet.dart';
import 'package:sepia_reader/services/tts/remote_speech_config.dart';
import 'package:sepia_reader/widgets/sheet_scaffold.dart';

void main() {
  testWidgets(
    'remote setup stays usable at 320px and requires explicit consent',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      FlutterSecureStorage.setMockInitialValues({});
      final store = RemoteSpeechStore();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAppSheet(
                  context: context,
                  builder: (_) => RemoteSpeechSheet(
                    store: store,
                    syncUrl: '',
                    syncToken: '',
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final preview = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Ouvir uma amostra'),
      );
      expect(preview.onPressed, isNull);
      expect(tester.takeException(), isNull);
      final keyField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Chave da API',
      );
      await tester.ensureVisible(keyField);
      await tester.enterText(keyField, 'not-a-real-key');
      expect(tester.widget<TextField>(keyField).obscureText, isTrue);
      final consent = find.byType(CheckboxListTile);
      await tester.ensureVisible(consent);
      await tester.tap(consent);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(consent).value, isTrue);
      final provider = find.byType(DropdownButtonFormField<String>).first;
      await tester.ensureVisible(provider);
      await tester.tap(provider);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ElevenLabs').last);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(keyField).controller!.text, isEmpty);
      expect(tester.widget<CheckboxListTile>(consent).value, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
