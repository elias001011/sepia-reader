import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/services/html_preview.dart';

void main() {
  test('converte uma página simples em markdown legível', () {
    final markdown = htmlToMarkdown('''
<!doctype html>
<html><head><title>x</title><style>p{color:red}</style></head>
<body>
  <h1>Capítulo um</h1>
  <p>Ele disse <strong>muito</strong> alto, com um <a href="https://exemplo.com">link</a>.</p>
  <ul><li>primeiro</li><li>segundo</li></ul>
  <ol><li>um</li><li>dois</li></ol>
  <blockquote>uma cita&ccedil;&atilde;o</blockquote>
  <img src="gato.png" alt="um gato">
  <hr>
  <script>alert('nope')</script>
</body></html>
''');
    expect(markdown, contains('# Capítulo um'));
    expect(markdown, contains('Ele disse **muito** alto'));
    expect(markdown, contains('[link](https://exemplo.com)'));
    expect(markdown, contains('- primeiro'));
    expect(markdown, contains('1. um'));
    expect(markdown, contains('2. dois'));
    expect(markdown, contains('> uma citação'));
    expect(markdown, contains('![um gato](gato.png)'));
    expect(markdown, contains('---'));
    expect(markdown, isNot(contains('alert')));
    expect(markdown, isNot(contains('color:red')));
    expect(markdown, isNot(contains('<')));
  });

  test('preserva o conteúdo de <pre> sem comer os sinais de menor/maior', () {
    final markdown = htmlToMarkdown(
      '<p>antes</p><pre><code>if (a &lt; b) { x(); }</code></pre><p>depois</p>',
    );
    expect(markdown, contains('```'));
    expect(markdown, contains('if (a < b) { x(); }'));
    expect(markdown, contains('antes'));
    expect(markdown, contains('depois'));
  });

  test('decodifica entidades numéricas e nomeadas', () {
    expect(htmlToMarkdown('<p>caf&eacute; &amp; p&#227;o &#x2014; ok</p>'),
        'café & pão — ok');
  });

  test('não deixa linhas em branco em excesso', () {
    final markdown = htmlToMarkdown('<div><div><p>a</p></div></div><p>b</p>');
    expect(markdown, 'a\n\nb');
  });
}
