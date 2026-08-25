import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sepia_reader/app.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/state/app_controller.dart';

void main() {
  testWidgets('exibe a biblioteca e o documento inicial', (tester) async {
    _useLocale('pt_BR');
    final controller = AppController();
    await controller.initialize();

    await tester.pumpWidget(SepiaApp(controller: controller));
    await tester.pump();

    expect(find.text('Sépia'), findsOneWidget);
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Bem-vindo ao Sépia.md'), findsOneWidget);
  });

  testWidgets('biblioteca se adapta a uma tela mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _useLocale('pt_BR');
    final controller = AppController();
    await controller.initialize();

    await tester.pumpWidget(SepiaApp(controller: controller));
    await tester.pump();

    expect(find.text('Sua biblioteca,\nno seu ritmo.'), findsOneWidget);
    expect(find.text('Novo'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Bem-vindo ao Sépia.md'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Modo leitura',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Modo leitura'), findsNothing);
    final mobileException = tester.takeException();
    expect(
      mobileException,
      isNull,
      reason: mobileException is FlutterError
          ? mobileException.toStringDeep()
          : '$mobileException',
    );
  });

  testWidgets('exibe a interface e o documento inicial em inglês', (
    tester,
  ) async {
    _useLocale('en');
    final controller = AppController();
    await controller.initialize();

    await tester.pumpWidget(SepiaApp(controller: controller));
    await tester.pump();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Welcome to Sépia.md'), findsOneWidget);
    expect(find.text('Your library,\nat your pace.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desfaz e refaz mudanças durante a sessão do editor', (
    tester,
  ) async {
    _useLocale('pt_BR');
    final controller = AppController();
    await controller.initialize();

    await tester.pumpWidget(SepiaApp(controller: controller));
    await tester.pump();
    await tester.tap(find.text('Bem-vindo ao Sépia.md'));
    await tester.pumpAndSettle();

    final editorFinder = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.expands,
    );
    final initialText = tester.widget<TextField>(editorFinder).controller!.text;
    await tester.tap(editorFinder);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(editorFinder, 'texto novo');
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(
      find.byTooltip('Desfazer · histórico desta sessão'),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(editorFinder).controller!.text,
      initialText,
    );

    await tester.tap(
      find.byTooltip('Refazer · histórico desta sessão'),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(editorFinder).controller!.text,
      'texto novo',
    );
    await tester.pump(const Duration(milliseconds: 800));
  });
}

void _useLocale(String localeCode) {
  SharedPreferences.setMockInitialValues({
    'sepia.settings.v1': jsonEncode(
      AppSettings(localeCode: localeCode).toJson(),
    ),
  });
}
