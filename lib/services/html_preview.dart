/// Converts HTML into markdown for the reader's simple preview.
///
/// Sépia renders markdown, and it renders it well. Teaching it a second
/// document language would mean a second renderer (`flutter_html` and its
/// own layout engine) or, on the web only, an iframe — a heavier dependency
/// and a different set of bugs on every platform. Lowering HTML into the
/// markdown the reader already draws gets a readable page out of an `.html`
/// file with no new rendering path, and everything downstream — chunking,
/// bookmarks, reading aloud — keeps working unchanged.
///
/// This is deliberately a *preview*, not a browser: layout, CSS, scripts and
/// forms are all dropped. The source is always one tap away in the viewer.
library;

final _comment = RegExp(r'<!--.*?-->', dotAll: true);
final _dropped = RegExp(
  r'<(script|style|noscript|template|svg|head)\b[^>]*>.*?</\1\s*>',
  caseSensitive: false,
  dotAll: true,
);
final _preBlock = RegExp(
  r'<pre\b[^>]*>(.*?)</pre\s*>',
  caseSensitive: false,
  dotAll: true,
);
final _anyTag = RegExp(r'<[^>]*>');

String htmlToMarkdown(String html) {
  var text = html.replaceAll(_comment, '');
  text = text.replaceAll(_dropped, '');

  // Pull code blocks out first and put them back at the end, so the tag
  // stripping below cannot eat the code's own angle brackets.
  final codeBlocks = <String>[];
  text = text.replaceAllMapped(_preBlock, (match) {
    final body = _decodeEntities(
      match.group(1)!.replaceAll(RegExp(r'</?code\b[^>]*>', caseSensitive: false), ''),
    ).trimRight();
    codeBlocks.add(body);
    return '\n\n\u0000CODE${codeBlocks.length - 1}\u0000\n\n';
  });

  text = text
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<hr\s*/?>', caseSensitive: false), '\n\n---\n\n');

  // Images and links keep their text; everything else about them goes.
  text = text.replaceAllMapped(
    RegExp(r'<img\b[^>]*>', caseSensitive: false),
    (match) {
      final alt = _attribute(match.group(0)!, 'alt') ?? '';
      final src = _attribute(match.group(0)!, 'src') ?? '';
      return '![$alt]($src)';
    },
  );
  text = text.replaceAllMapped(
    RegExp(r'<a\b([^>]*)>(.*?)</a\s*>', caseSensitive: false, dotAll: true),
    (match) {
      final href = _attribute('<a${match.group(1)}>', 'href') ?? '';
      final label = match.group(2)!.replaceAll(_anyTag, '').trim();
      if (label.isEmpty) return '';
      return href.isEmpty ? label : '[$label]($href)';
    },
  );

  for (var level = 6; level >= 1; level--) {
    text = text.replaceAllMapped(
      RegExp(
        '<h$level\\b[^>]*>(.*?)</h$level\\s*>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) =>
          '\n\n${'#' * level} ${_inline(match.group(1)!)}\n\n',
    );
  }

  text = _wrap(text, 'strong', '**');
  text = _wrap(text, 'b', '**');
  text = _wrap(text, 'em', '_');
  text = _wrap(text, 'i', '_');
  text = _wrap(text, 'code', '`');
  text = _wrap(text, 'del', '~~');
  text = _wrap(text, 's', '~~');

  text = text.replaceAllMapped(
    RegExp(r'<blockquote\b[^>]*>(.*?)</blockquote\s*>',
        caseSensitive: false, dotAll: true),
    (match) {
      final body = _inline(match.group(1)!).trim();
      final quoted = body
          .split('\n')
          .map((line) => '> ${line.trim()}')
          .join('\n');
      return '\n\n$quoted\n\n';
    },
  );

  // Ordered lists get real numbers; unordered ones a dash. Nesting is
  // flattened — a preview, not a faithful reproduction.
  text = text.replaceAllMapped(
    RegExp(r'<ol\b[^>]*>(.*?)</ol\s*>', caseSensitive: false, dotAll: true),
    (match) => '\n\n${_listItems(match.group(1)!, ordered: true)}\n\n',
  );
  text = text.replaceAllMapped(
    RegExp(r'<ul\b[^>]*>(.*?)</ul\s*>', caseSensitive: false, dotAll: true),
    (match) => '\n\n${_listItems(match.group(1)!, ordered: false)}\n\n',
  );

  for (final block in ['p', 'div', 'section', 'article', 'header', 'footer',
      'main', 'nav', 'aside', 'tr', 'li']) {
    text = text.replaceAll(
      RegExp('</$block\\s*>', caseSensitive: false),
      '\n\n',
    );
  }
  text = text.replaceAll(
    RegExp(r'</t[dh]\s*>', caseSensitive: false),
    ' · ',
  );

  text = text.replaceAll(_anyTag, '');
  text = _decodeEntities(text);

  for (var i = 0; i < codeBlocks.length; i++) {
    text = text.replaceAll(
      '\u0000CODE$i\u0000',
      '```\n${codeBlocks[i]}\n```',
    );
  }

  return text
      .split('\n')
      .map((line) => line.trimRight())
      .join('\n')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

String _listItems(String source, {required bool ordered}) {
  final items = RegExp(
    r'<li\b[^>]*>(.*?)(?=<li\b|</[ou]l\s*>|$)',
    caseSensitive: false,
    dotAll: true,
  ).allMatches(source);
  final lines = <String>[];
  var number = 1;
  for (final item in items) {
    final body = _inline(item.group(1)!).replaceAll('\n', ' ').trim();
    if (body.isEmpty) continue;
    lines.add(ordered ? '${number++}. $body' : '- $body');
  }
  return lines.join('\n');
}

String _wrap(String source, String tag, String marker) => source.replaceAllMapped(
  RegExp('<$tag\\b[^>]*>(.*?)</$tag\\s*>', caseSensitive: false, dotAll: true),
  (match) {
    final body = match.group(1)!.trim();
    return body.isEmpty ? '' : '$marker$body$marker';
  },
);

String _inline(String source) => source.replaceAll(_anyTag, '');

String? _attribute(String tag, String name) {
  final match = RegExp(
    '$name\\s*=\\s*("([^"]*)"|\'([^\']*)\'|([^\\s>]+))',
    caseSensitive: false,
  ).firstMatch(tag);
  if (match == null) return null;
  return match.group(2) ?? match.group(3) ?? match.group(4);
}

const _entities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'hellip': '…',
  'mdash': '—',
  'ndash': '–',
  'laquo': '«',
  'raquo': '»',
  'ldquo': '“',
  'rdquo': '”',
  'lsquo': '‘',
  'rsquo': '’',
  'aacute': 'á',
  'eacute': 'é',
  'iacute': 'í',
  'oacute': 'ó',
  'uacute': 'ú',
  'atilde': 'ã',
  'otilde': 'õ',
  'ccedil': 'ç',
  'acirc': 'â',
  'ecirc': 'ê',
  'ocirc': 'ô',
  'agrave': 'à',
};

String _decodeEntities(String input) => input.replaceAllMapped(
  RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);'),
  (match) {
    final body = match.group(1)!;
    if (body.startsWith('#')) {
      final isHex = body.length > 1 && (body[1] == 'x' || body[1] == 'X');
      final digits = isHex ? body.substring(2) : body.substring(1);
      final code = int.tryParse(digits, radix: isHex ? 16 : 10);
      if (code == null || code < 0 || code > 0x10FFFF) return match.group(0)!;
      return String.fromCharCode(code);
    }
    final lower = body.toLowerCase();
    final replacement = _entities[lower];
    if (replacement == null) return match.group(0)!;
    // A capitalised named entity is the uppercase letter (&Ccedil;).
    return body[0] == body[0].toUpperCase() && lower != body
        ? replacement.toUpperCase()
        : replacement;
  },
);
