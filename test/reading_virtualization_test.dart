import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/models/library_document.dart';
import 'package:sepia_reader/widgets/markdown_view.dart';

void main() {
  testWidgets('markdown reading view only builds on-screen paragraphs', (
    tester,
  ) async {
    final paragraphs = List.generate(
      400,
      (i) => 'Paragraph number $i. ' * 12,
    ).join('\n\n');
    final document = LibraryDocument(
      id: 'd1',
      title: 'Big doc',
      content: paragraphs,
      extension: 'md',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: DocumentView(document: document, settings: const AppSettings()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final builtTexts = find.textContaining('Paragraph number');
    final count = builtTexts.evaluate().length;
    // ignore: avoid_print
    print('BUILT_PARAGRAPH_WIDGETS=$count (of 400 total)');
    expect(
      count,
      lessThan(100),
      reason:
          'If ~all 400 paragraphs are built while only a handful fit on '
          'screen, the view is not actually virtualized.',
    );
  });
}
