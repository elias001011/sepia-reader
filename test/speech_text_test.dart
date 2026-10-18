import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/services/document_sections.dart';

void main() {
  test(
    'reference links, entities, nested parentheses and HTML leave prose',
    () {
      final text = speakableText('''
# **Ação &amp; atenção**

[Uma referência][doc] e [um endereço](https://example.org/a(b)).

![Descrição](a.png "foto")

<!-- não ler isto -->

<script>não ler script</script>

[doc]: https://example.org
''');
      expect(text, contains('Ação & atenção'));
      expect(text, contains('Uma referência e um endereço.'));
      expect(text, contains('Descrição'));
      for (final noise in ['https', '[', ']', 'script', 'não ler', 'a.png']) {
        expect(text, isNot(contains(noise)));
      }
    },
  );

  test(
    'tables without outer pipes and code indentation do not leak syntax',
    () {
      final text = speakableText(
        'Nome | Valor\n--- | ---\nCafé | 12\n\n    código secreto\n\nFim.',
      );
      expect(text, contains('Nome, Valor'));
      expect(text, contains('Café, 12'));
      expect(text, isNot(contains('|')));
      expect(text, isNot(contains('código secreto')));
    },
  );

  test(
    'normalizes ellipses and decoration but preserves accents and decimals',
    () {
      expect(
        normalizeSpeechText('Espere... Agora… sim, café! 3.14.\n─────\n— Olá.'),
        'Espere. Agora, sim, café! 3.14.\n\nOlá.',
      );
      expect(utterancesFor('...\n\n***\n\n…\n\n___'), isEmpty);
      expect(
        normalizeSpeechText('pa\u00adlavra\u200b com\u00a0espaço'),
        'palavra com espaço',
      );
    },
  );

  test(
    'dialogue dashes do not create punctuation-only speech or double pauses',
    () {
      final pieces = utterancesFor(
        speakableText(
          '— Oi — disse, em inglês. — Oi. Eu… sim.\n\n'
          '— Não, eu… eu perguntei se ele *podia*. É diferente. — Tá.',
        ),
      );
      expect(pieces, [
        'Oi, disse, em inglês. Oi. Eu, sim.',
        'Não, eu, eu perguntei se ele podia. É diferente. Tá.',
      ]);
    },
  );

  test(
    'long clauses without punctuation stay bounded without losing words',
    () {
      final text = List.filled(2000, 'acentuação').join(' ');
      final pieces = utterancesFor(text);
      expect(pieces.every((piece) => piece.length <= 240), isTrue);
      expect(pieces.join(' '), text);
    },
  );

  test('quoted punctuation does not drop text across boundaries', () {
    final text = List.filled(
      40,
      'Ele disse: “Espere…” Então voltou.',
    ).join(' ');
    final pieces = utterancesFor(text);
    expect(pieces.join(' '), normalizeSpeechText(text));
    expect(pieces.every((piece) => piece.length <= 240), isTrue);
  });
}
