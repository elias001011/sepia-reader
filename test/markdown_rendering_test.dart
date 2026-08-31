import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/models/library_document.dart';
import 'package:sepia_reader/services/document_sections.dart';
import 'package:sepia_reader/widgets/markdown_view.dart';

/// A full tour of markdown, rendered end to end. Covers the reader against a
/// document that uses every construct at once rather than one feature at a
/// time — which is how the chunking bugs below got in: each rule was right
/// on its own and wrong next to the others.
String guide() => File('test/fixtures/markdown_syntax_guide.md').readAsStringSync();

LibraryDocument guideDoc() => LibraryDocument(
  id: 'g',
  title: 'Guia',
  content: guide(),
  extension: 'md',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group('fatiamento', () {
    test('mantém a semântica Setext da v1 e separa uma régua explícita', () {
      // A v1 entregava o documento inteiro ao mesmo MarkdownBody usado hoje.
      // Sem linha em branco, `---` é legitimamente um título Setext e precisa
      // continuar no mesmo bloco para conservar essa semântica.
      expect(splitMarkdownBlocks('Subtítulo\n---'), ['Subtítulo\n---']);

      // O editor, por outro lado, deve produzir este segundo formato ao tocar
      // no botão de régua: dois blocos, nunca um sublinhado Setext acidental.
      expect(
        splitMarkdownBlocks('- Diálogo.\n\n---\n'),
        ['- Diálogo.', '---'],
      );
    });

    test('um título nunca engole a lista ou a citação que vem depois', () {
      final chunks = chunksForDocument(guideDoc());
      for (final chunk in chunks) {
        final lines = chunk.split('\n');
        if (!RegExp(r'^\s{0,3}#{1,6}\s').hasMatch(lines.first)) continue;
        // A heading chunk may hold further headings, never a list or quote.
        for (final line in lines.skip(1)) {
          if (line.trim().isEmpty) continue;
          expect(
            RegExp(r'^\s*([-*+]|\d+[.)])\s+|^\s*>').hasMatch(line),
            isFalse,
            reason: 'heading chunk swallowed a list/quote:\n$chunk',
          );
        }
      }
    });

    test('uma cerca de código depois de linha em branco começa um bloco novo', () {
      final chunks = chunksForDocument(guideDoc());
      final codeChunk = chunks.firstWhere((c) => c.startsWith('```\nlet message'));
      expect(codeChunk, isNot(contains('Blocks of code')));
    });

    test('listas aninhadas e citações aninhadas ficam inteiras', () {
      final chunks = chunksForDocument(guideDoc());
      expect(
        chunks.any((c) => c.contains('* Item 1') && c.contains('* Item 3b')),
        isTrue,
      );
      expect(
        chunks.any((c) => c.contains('1. Item 1') && c.contains('2. Item 3b')),
        isTrue,
      );
      expect(
        chunks.any((c) => c.startsWith('> Markdown is a lightweight') &&
            c.contains('>> Markdown is often used')),
        isTrue,
      );
    });

    test('nada se perde: os pedaços reconstroem o documento', () {
      final chunks = chunksForDocument(guideDoc());
      List<String> words(String source) =>
          source.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      expect(words(chunks.join('\n')), words(guide()));
    });
  });

  testWidgets('o guia inteiro renderiza sem estouro e com respiro', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentView(
            document: guideDoc(),
            settings: const AppSettings(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Every chunk carries vertical breathing room; without it the blocks
    // butted straight into each other.
    final paddings = tester
        .widgetList<Padding>(
          find.ancestor(
            of: find.byType(MarkdownBody),
            matching: find.byType(Padding),
          ),
        )
        .where((p) => p.padding.vertical > 0);
    expect(
      paddings,
      isNotEmpty,
      reason: 'markdown chunks must be spaced apart from one another',
    );
  });

  testWidgets('um diagrama mermaid aparece rotulado, não como código solto', (
    tester,
  ) async {
    final doc = LibraryDocument(
      id: 'm',
      title: 'D',
      content: '# Fluxo\n\n```mermaid\ngraph TD\n  A[Start] --> B{Decision}\n```\n',
      extension: 'md',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: DocumentView(document: doc, settings: const AppSettings()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('mermaid'), findsOneWidget);
    expect(find.textContaining('A[Start] --> B{Decision}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('o que a voz recebe', () {
    test('nenhuma sintaxe de markdown sobra para ser soletrada', () {
      final spoken = speakableText(guide());
      for (final noise in ['#', '**', '__', '```', '![', '](', '|---', '> ']) {
        expect(
          spoken,
          isNot(contains(noise)),
          reason: 'a voz leria "$noise" em voz alta',
        );
      }
      expect(spoken, isNot(contains('https://')));
      expect(spoken, isNot(contains('`')));
    });

    test('o texto de verdade sobrevive, com acento e pontuação', () {
      final spoken = speakableText(
        '# Capítulo\n\nEle disse: **"não vá"** — e ela foi, às 3h.\n',
      );
      expect(spoken, contains('Capítulo'));
      expect(spoken, contains('Ele disse: "não vá" — e ela foi, às 3h.'));
    });

    test('o alt de uma imagem é lido, o caminho e o título não', () {
      final spoken = speakableText(
        '![Um gato dormindo](/image/gato.svg "Uma foto de exemplo.")',
      );
      expect(spoken, 'Um gato dormindo');
    });

    test('código e diagrama não são lidos em voz alta', () {
      final spoken = speakableText(guide());
      expect(spoken, isNot(contains('alert(message)')));
      expect(spoken, isNot(contains('graph TD')));
    });

    test('a tabela vira texto legível, sem os canos', () {
      final spoken = speakableText(guide());
      expect(spoken, contains('left foo'));
      expect(spoken, isNot(contains('|')));
    });
  });
}
