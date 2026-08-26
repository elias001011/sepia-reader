import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/models/library_document.dart';
import 'package:sepia_reader/services/document_sections.dart';
import 'package:sepia_reader/widgets/markdown_view.dart';

/// Everything awkward in one document: setext headings, hard breaks,
/// escapes, autolinks, inline HTML, lists with paragraphs and code inside
/// them, quotes containing lists and code, indented code, tilde fences,
/// tables with escaped pipes, and an unbreakable URL.
///
/// The reader builds one block at a time, so the interesting failures are
/// all about where the blocks are cut — and those only show up when the
/// constructs sit next to each other, which is the whole point of this
/// fixture.
String torture() => File('test/fixtures/markdown_torture.md').readAsStringSync();

LibraryDocument tortureDoc() => LibraryDocument(
  id: 't',
  title: 'Tortura',
  content: torture(),
  extension: 'md',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group('fatiamento', () {
    late List<String> chunks;
    setUpAll(() => chunks = chunksForDocument(tortureDoc()));

    test('nada se perde nem se duplica', () {
      List<String> words(String source) =>
          source.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      expect(words(chunks.join('\n')), words(torture()));
    });

    test('toda cerca de código fica inteira', () {
      for (final chunk in chunks) {
        final fences = RegExp(r'^\s*(```|~~~)', multiLine: true)
            .allMatches(chunk)
            .length;
        expect(
          fences.isEven,
          isTrue,
          reason: 'cerca cortada ao meio:\n$chunk',
        );
      }
    });

    test('o código dentro de um item de lista fica com o item', () {
      final listChunk = chunks.firstWhere((c) => c.contains('Item com código'));
      expect(listChunk, contains('```dart'));
      expect(listChunk, contains('final x = 1;'));
      expect(
        listChunk,
        contains('- Próximo item.'),
        reason: 'a lista foi partida em pedaços que renderizam como listas '
            'separadas, cada uma recomeçando a numeração',
      );
    });

    test('uma lista não se funde com a citação seguinte', () {
      final quote = chunks.firstWhere((c) => c.trimLeft().startsWith('>'));
      expect(quote, isNot(contains('- Próximo item.')));
      // And the quote keeps everything that belongs to it.
      expect(quote, contains('### Citação com título'));
      expect(quote, contains('- e uma lista dentro'));
      expect(quote, contains('const a = 1;'));
    });

    test('uma lista aninhada em quatro níveis fica num bloco só', () {
      final nested = chunks.firstWhere((c) => c.contains('Nível um'));
      for (final level in ['dois', 'três', 'quatro']) {
        expect(nested, contains('Nível $level'));
      }
    });

    test('um item com dois parágrafos não vira duas listas', () {
      final loose = chunks.firstWhere((c) => c.contains('Primeiro item'));
      expect(loose, contains('Segundo parágrafo do mesmo item.'));
      expect(loose, contains('2. Item dois.'));
    });

    test('títulos por sublinhado ficam junto do seu texto', () {
      expect(
        chunks.any(
          (c) => c.startsWith('Título por sublinhado') && c.contains('====='),
        ),
        isTrue,
      );
      expect(
        chunks.any(
          (c) => c.startsWith('Subtítulo por sublinhado') && c.contains('-----'),
        ),
        isTrue,
      );
    });
  });

  testWidgets('o documento inteiro renderiza sem estourar', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentView(
            document: tortureDoc(),
            settings: const AppSettings(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Escapes are honoured rather than shown.
    expect(find.textContaining(r'\*isto'), findsNothing);
  });

  group('o que a voz recebe', () {
    test('nem sintaxe, nem código, nem a URL enorme', () {
      final spoken = speakableText(torture());
      for (final noise in ['```', '~~~', '<b>', '<br>', '|---', '===', '* * *']) {
        expect(spoken, isNot(contains(noise)), reason: 'a voz leria "$noise"');
      }
      expect(spoken, isNot(contains('print("ok")')));
      expect(spoken, isNot(contains('const a = 1;')));
      expect(spoken, contains('Fim.'));
    });

    test('o escape some e o texto que ele protegia fica', () {
      expect(
        speakableText(r'Escape: \*isto não é itálico\*.'),
        'Escape: *isto não é itálico*.',
      );
    });
  });
}
