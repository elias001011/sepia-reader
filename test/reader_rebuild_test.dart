import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sepia_reader/app.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/models/library_document.dart';
import 'package:sepia_reader/state/app_controller.dart';
import 'package:sepia_reader/widgets/markdown_view.dart';

import 'support/offline_updates.dart';

/// Showing and hiding the reader's controls used to rebuild the document
/// with them: the visibility flag was plain state, so every tap, and every
/// firing of the auto-hide timer, rebuilt the whole reader. Measured on a
/// ~180 kB document that rebuild cost about 18 ms — most of a frame, spent
/// redrawing text that had not changed. The chrome listens to a notifier
/// now, and the document is not in that subtree.
void main() {
  testWidgets('mostrar e esconder os controles não reconstrói o documento', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'sepia.settings.v1': jsonEncode(
        const AppSettings(
          localeCode: 'pt_BR',
          autoHideReaderControls: true,
        ).toJson(),
      ),
    });
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();
    await controller.createDocument(
      title: 'Fic',
      content: List.generate(200, (i) => 'Parágrafo $i da fic.').join('\n\n'),
    );

    await tester.pumpWidget(SepiaApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Fic.md'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fic.md'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Modo leitura',
      ),
    );
    await tester.pumpAndSettle();

    DocumentView view() => tester.widget<DocumentView>(find.byType(DocumentView));
    final before = view();

    // Let the auto-hide timer fire, then reveal the controls again.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300));
    final afterHide = view();
    await tester.tapAt(const Offset(210, 20));
    await tester.pump(const Duration(milliseconds: 300));
    final afterShow = view();

    expect(
      identical(before, afterHide) && identical(before, afterShow),
      isTrue,
      reason: 'the reader rebuilt the document just to move its own chrome',
    );
  });

  test('a divisão em blocos é reaproveitada em vez de refeita', () {
    final document = LibraryDocument(
      id: 'd',
      title: 'Fic',
      content: List.generate(400, (i) => 'Parágrafo $i.').join('\n\n'),
      extension: 'md',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final first = chunksForDocument(document);
    final second = chunksForDocument(document);
    expect(
      identical(first, second),
      isTrue,
      reason: 'splitting the whole document again per rebuild is a full pass '
          'over it, and the answer has not changed',
    );

    // A different document is genuinely re-split.
    final other = document.copyWith(content: 'outro texto');
    expect(identical(chunksForDocument(other), first), isFalse);
    expect(chunksForDocument(other), ['outro texto']);
  });
}
