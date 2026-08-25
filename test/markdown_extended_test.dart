import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/models/library_document.dart';
import 'package:sepia_reader/services/document_sections.dart';
import 'package:sepia_reader/widgets/markdown_view.dart';

/// The extended-syntax tour: task lists, reference links, footnotes, aligned
/// tables and maths. Several of these only broke *because* the reader renders
/// one block at a time, so they cannot be caught by testing the constructs in
/// isolation.
String extended() => File('test/fixtures/markdown_extended.md').readAsStringSync();

LibraryDocument extendedDoc() => LibraryDocument(
  id: 'e',
  title: 'Dillinger',
  content: extended(),
  extension: 'md',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<void> render(WidgetTester tester, LibraryDocument document) async {
  tester.view.physicalSize = const Size(430, 950);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DocumentView(document: document, settings: const AppSettings()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('links de referência continuam resolvíveis apesar do fatiamento', () {
    // The definition lives many blocks away from the link that uses it.
    final definitions = collectLinkDefinitions(extended());
    expect(definitions, contains('[dillinger]: https://dillinger.io'));

    final chunks = chunksForDocument(extendedDoc());
    final linkChunk = chunks.firstWhere((c) => c.contains('[reference-style links][dillinger]'));
    expect(
      linkChunk.contains('[dillinger]:'),
      isFalse,
      reason: 'sanity: the definition really is in another chunk',
    );
    // Which is exactly why it gets appended at render time.
    expect('$linkChunk$definitions', contains('[dillinger]: https://dillinger.io'));
  });

  test('um bloco que só tem definições de link não vira texto solto', () {
    expect(isLinkDefinitionOnly('[dillinger]: https://dillinger.io'), isTrue);
    expect(isLinkDefinitionOnly('[a]: /x\n[b]: /y'), isTrue);
    expect(isLinkDefinitionOnly('Um parágrafo comum.'), isFalse);
    // A footnote definition is not a link definition.
    expect(isLinkDefinitionOnly('[^1]: uma nota.'), isFalse);
  });

  test('notas de rodapé viram sobrescrito legível, não colchetes', () {
    expect(
      rewriteFootnotes('Texto com nota[^1] no meio.'),
      'Texto com nota¹ no meio.',
    );
    expect(
      rewriteFootnotes('[^1]: Aparece no fim da prévia.'),
      '¹ *Aparece no fim da prévia.*',
    );
    expect(rewriteFootnotes('[^12]: nota'), '¹² *nota*');
    // A non-numeric label has no superscript form; leave it legible.
    expect(rewriteFootnotes('nota[^nota]'), 'notanota');
  });

  test('equação em bloco é reconhecida como equação', () {
    expect(isMathBlock(r'$$' '\n' r'\sum_{i=1}^{n} i' '\n' r'$$'), isTrue);
    expect(isMathBlock('Inline math: 	E = mc^2'), isFalse);
    expect(isMathBlock('Um parágrafo.'), isFalse);
  });

  testWidgets('o documento estendido inteiro renderiza sem erro', (
    tester,
  ) async {
    await render(tester, extendedDoc());
    expect(tester.takeException(), isNull);
    expect(find.text('Welcome to Dillinger'), findsOneWidget);
  });

  testWidgets('lista de tarefas mostra caixas, não colchetes', (tester) async {
    await render(
      tester,
      extendedDoc().copyWith(
        content: '- [x] Feito\n- [ ] Pendente\n',
      ),
    );
    expect(find.textContaining('[x]'), findsNothing);
    expect(find.textContaining('[ ]'), findsNothing);
    expect(find.text('Feito'), findsOneWidget);
    expect(find.text('Pendente'), findsOneWidget);
  });

  testWidgets('equação em bloco aparece emoldurada, sem os cifrões', (
    tester,
  ) async {
    await render(
      tester,
      extendedDoc().copyWith(
        content: 'Antes.\n\n' r'$$' '\n' r'E = mc^2' '\n' r'$$' '\n\nDepois.',
      ),
    );
    expect(find.byType(FormulaBlock), findsOneWidget);
    expect(find.text('E = mc^2'), findsOneWidget);
    expect(find.textContaining(r'$$'), findsNothing);
  });

  testWidgets('a definição de link não ocupa espaço na leitura', (
    tester,
  ) async {
    await render(
      tester,
      extendedDoc().copyWith(
        content: 'Veja [aqui][ref].\n\n[ref]: https://exemplo.com\n',
      ),
    );
    expect(find.textContaining('https://exemplo.com'), findsNothing);
    expect(find.textContaining('[ref]'), findsNothing);
  });

  group('o que a voz recebe do md estendido', () {
    test('tarefas, notas e equações não viram ruído', () {
      final spoken = speakableText(extended());
      for (final noise in ['[x]', '[ ]', '[^1]', '```', '|--', '~~']) {
        expect(spoken, isNot(contains(noise)), reason: 'a voz leria "$noise"');
      }
      expect(spoken, contains('Set up the editor'));
      expect(spoken, contains('Toggle zen mode'));
      expect(spoken, isNot(contains('def fibonacci')));
    });

    test('o texto tachado é lido, os tis não', () {
      expect(speakableText('Isto é ~~errado~~ certo.'), 'Isto é errado certo.');
    });
  });
}
