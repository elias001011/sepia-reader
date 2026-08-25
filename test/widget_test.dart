import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sepia_reader/app.dart';
import 'package:sepia_reader/state/app_controller.dart';

void main() {
  testWidgets('exibe a biblioteca e o documento inicial', (tester) async {
    SharedPreferences.setMockInitialValues({});
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
    SharedPreferences.setMockInitialValues({});
    final controller = AppController();
    await controller.initialize();

    await tester.pumpWidget(SepiaApp(controller: controller));
    await tester.pump();

    expect(find.text('Sua biblioteca,\nno seu ritmo.'), findsOneWidget);
    expect(find.text('Novo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
