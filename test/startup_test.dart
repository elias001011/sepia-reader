import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/app.dart';
import 'package:sepia_reader/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/offline_updates.dart';

class _DelayedController extends AppController {
  _DelayedController(this.ready) : super(updateChecker: offlineUpdateChecker());

  final Completer<void> ready;

  @override
  Future<void> initialize() => ready.future;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('o primeiro frame é uma tela Sépia, não a janela preta nativa', (
    tester,
  ) async {
    final ready = Completer<void>();
    final controller = _DelayedController(ready);

    await tester.pumpWidget(SepiaBootstrap(controller: controller));

    expect(find.text('Sépia'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    ready.complete();
    await tester.pumpAndSettle();
    expect(find.byType(SepiaApp), findsOneWidget);
  });
}
