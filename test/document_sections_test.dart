import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/models/library_document.dart';
import 'package:sepia_reader/services/document_sections.dart';

LibraryDocument doc(String content, {String extension = 'md'}) =>
    LibraryDocument(
      id: 'd',
      title: 'Minha fic',
      content: content,
      extension: extension,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  group('sectionsOf', () {
    test('divide por # e ## e ignora títulos mais profundos', () {
      final sections = sectionsOf(
        doc('''
# Capítulo um

Texto.

### Uma cena

Mais texto.

## Capítulo dois

Fim.
'''),
      );
      expect(
        sections.map((s) => s.title).toList(),
        ['Capítulo um', 'Capítulo dois'],
      );
      expect(hasChapters(sections), isTrue);
      expect(sections.first.startChunk, 0);
      expect(sections.first.endChunk, sections.last.startChunk);
    });

    test('texto antes do primeiro título vira uma seção de abertura', () {
      final sections = sectionsOf(
        doc('Nota do autor.\n\n# Capítulo um\n\nTexto.'),
      );
      expect(sections.first.level, 0);
      expect(sections.first.title, 'Minha fic');
      expect(sections[1].title, 'Capítulo um');
    });

    test('documento sem títulos vira uma seção única', () {
      final sections = sectionsOf(doc('Só texto corrido.\n\nOutro parágrafo.'));
      expect(sections, hasLength(1));
      expect(hasChapters(sections), isFalse);
      expect(sections.single.startChunk, 0);
    });

    test('as seções cobrem o documento inteiro sem buracos', () {
      final sections = sectionsOf(
        doc('# A\n\nx\n\n# B\n\ny\n\n# C\n\nz'),
      );
      for (var i = 0; i + 1 < sections.length; i++) {
        expect(sections[i].endChunk, sections[i + 1].startChunk);
      }
      expect(sections.first.startChunk, 0);
    });

    test('marcação no título é removida', () {
      final sections = sectionsOf(doc('## **Capítulo _sete_**\n\nx'));
      expect(sections.single.title, 'Capítulo sete');
    });
  });

  group('speakableText', () {
    test('remove sintaxe em vez de soletrá-la', () {
      final spoken = speakableText('''
# Capítulo um

Ele disse **muito** alto, com um [link](https://exemplo.com) no meio.

- primeiro
- segundo

> uma citação

![um gato dormindo](gato.png)
''');
      expect(spoken, contains('Capítulo um'));
      expect(spoken, contains('Ele disse muito alto, com um link no meio.'));
      expect(spoken, contains('primeiro'));
      expect(spoken, contains('uma citação'));
      expect(spoken, contains('um gato dormindo'));
      expect(spoken, isNot(contains('#')));
      expect(spoken, isNot(contains('**')));
      expect(spoken, isNot(contains('https://')));
      expect(spoken, isNot(contains('![')));
    });

    test('blocos de código não são lidos', () {
      final spoken = speakableText('Antes.\n\n```dart\nvoid main() {}\n```\n\nDepois.');
      expect(spoken, contains('Antes.'));
      expect(spoken, contains('Depois.'));
      expect(spoken, isNot(contains('void main')));
    });
  });

  group('utterancesFor', () {
    test('parágrafos curtos viram uma fala cada', () {
      expect(utterancesFor('Um.\n\nDois.\n\nTrês.'), ['Um.', 'Dois.', 'Três.']);
    });

    test('parágrafo longo é quebrado em frases, sem cortar palavra', () {
      final long = List.filled(40, 'Uma frase de teste aqui.').join(' ');
      final parts = utterancesFor(long);
      expect(parts.length, greaterThan(1));
      for (final part in parts) {
        expect(part.length, lessThanOrEqualTo(260));
      }
      // Nothing is lost: every word survives the split.
      final rejoined = parts.join(' ');
      expect(rejoined.split(' ').length, long.split(' ').length);
    });

    test('não devolve falas vazias', () {
      expect(utterancesFor('\n\n   \n\n'), isEmpty);
    });
  });
}
