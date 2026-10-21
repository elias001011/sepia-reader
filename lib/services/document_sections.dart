import 'package:markdown/markdown.dart' as md;

import '../models/library_document.dart';
import '../widgets/markdown_view.dart';

/// A chapter of a document: a `#` or `##` heading and everything under it,
/// expressed as a range over the same chunk list the reader renders and
/// bookmarks point into.
///
/// Reusing that list is the whole point. The chunk index is already the one
/// position anchor in this app that does not drift (a scroll fraction does —
/// see the bookmark notes in [DocumentView]), so "start reading from chapter
/// 4" and "jump to this bookmark" end up being the same operation.
class DocumentSection {
  const DocumentSection({
    required this.title,
    required this.level,
    required this.startChunk,
    required this.endChunk,
  });

  final String title;

  /// 1 for `#`, 2 for `##`, and 0 for the implicit section that covers a
  /// document with no headings at all (or the text before the first one).
  final int level;

  /// Inclusive index of the first chunk of this section.
  final int startChunk;

  /// Exclusive index of the chunk that starts the next section.
  final int endChunk;
}

final _headingPattern = RegExp(r'^(#{1,2})\s+(.*)$');

/// Splits a document into chapters.
///
/// Only `#` and `##` count: deeper headings are structure *inside* a chapter
/// (scene breaks, notes), and promoting them would turn a single chapter into
/// a list of fragments nobody thinks of as chapters. A document with no
/// headings comes back as one section covering the whole thing, so callers
/// never have to special-case the empty list.
List<DocumentSection> sectionsOf(LibraryDocument document) {
  final chunks = chunksForDocument(document);
  if (!document.isMarkdown) {
    return [
      DocumentSection(
        title: document.title,
        level: 0,
        startChunk: 0,
        endChunk: chunks.length,
      ),
    ];
  }

  final headings = <({int chunk, int level, String title})>[];
  for (var i = 0; i < chunks.length; i++) {
    final firstLine = chunks[i].split('\n').first.trimLeft();
    final match = _headingPattern.firstMatch(firstLine);
    if (match == null) continue;
    final title = _stripInlineMarkdown(match.group(2)!).trim();
    if (title.isEmpty) continue;
    headings.add((chunk: i, level: match.group(1)!.length, title: title));
  }

  if (headings.isEmpty) {
    return [
      DocumentSection(
        title: document.title,
        level: 0,
        startChunk: 0,
        endChunk: chunks.length,
      ),
    ];
  }

  final sections = <DocumentSection>[];
  // Text sitting above the first heading is its own opening section, so
  // starting from the top does not silently skip an author's note.
  if (headings.first.chunk > 0) {
    sections.add(
      DocumentSection(
        title: document.title,
        level: 0,
        startChunk: 0,
        endChunk: headings.first.chunk,
      ),
    );
  }
  for (var i = 0; i < headings.length; i++) {
    sections.add(
      DocumentSection(
        title: headings[i].title,
        level: headings[i].level,
        startChunk: headings[i].chunk,
        endChunk: i + 1 < headings.length
            ? headings[i + 1].chunk
            : chunks.length,
      ),
    );
  }
  return sections;
}

/// Whether the document actually has chapters, as opposed to the single
/// whole-document section [sectionsOf] falls back to.
bool hasChapters(List<DocumentSection> sections) =>
    sections.any((section) => section.level > 0);

/// Extracts prose with the same Markdown grammar as the reader. In
/// particular, reference links, nested emphasis, tables without outer pipes,
/// code blocks and entities cannot be handled reliably by stripping markers.
String speakableText(String markdown, {String linkDefinitions = ''}) {
  var source = markdown
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
      .replaceAll(
        RegExp(
          r'<(script|style|noscript)\b[^>]*>.*?</\1\s*>',
          caseSensitive: false,
          dotAll: true,
        ),
        '',
      )
      .replaceAll(RegExp(r'^\s*\$\$[\s\S]*?\$\$\s*$', multiLine: true), '')
      .replaceAll(RegExp(r'^\s{0,3}\[\^[^\]]+\]:\s*', multiLine: true), '')
      .replaceAll(RegExp(r'\[\^[^\]]+\]'), '');
  source += linkDefinitions;
  final parser = md.Document(
    extensionSet: md.ExtensionSet.gitHubWeb,
    encodeHtml: false,
  );
  final voice = _SpeechVisitor();
  for (final node in parser.parse(source)) {
    node.accept(voice);
  }
  return voice.text;
}

String _stripInlineMarkdown(String input) {
  final voice = _SpeechVisitor();
  for (final node in md.Document(encodeHtml: false).parseInline(input)) {
    node.accept(voice);
  }
  return voice.text;
}

class _SpeechVisitor implements md.NodeVisitor {
  final _output = StringBuffer();
  bool _firstCell = true;
  static const _blocks = {
    'p',
    'li',
    'blockquote',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
  };

  String get text => _output
      .toString()
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  @override
  bool visitElementBefore(md.Element element) {
    if (element.tag == 'pre' || element.tag == 'hr') {
      _output.write('\n\n');
      return false;
    }
    if (element.tag == 'input') return false;
    if (element.tag == 'tr') _firstCell = true;
    if (element.tag == 'td' || element.tag == 'th') {
      if (!_firstCell) _output.write(', ');
      _firstCell = false;
    }
    if (element.tag == 'img') {
      _output.write(element.attributes['alt'] ?? '');
      return false;
    }
    if (element.tag == 'br') _output.write('\n');
    return true;
  }

  @override
  void visitElementAfter(md.Element element) {
    if (_blocks.contains(element.tag)) _output.write('\n\n');
    if (element.tag == 'tr') _output.write('\n\n');
  }

  @override
  void visitText(md.Text text) {
    // Raw HTML is a text node in Markdown's AST. Tags carry no spoken words.
    _output.write(text.text.replaceAll(RegExp(r'<[^>]+>'), ''));
  }
}

/// Common typographic punctuation is normalized once for every backend,
/// including Lite's system voice. Never remove accents or meaningful symbols
/// from prose; only decoration-only lines and invisible layout characters go.
String _cleanSpeechLayout(String text) => text
    .replaceAll(
      RegExp(r'^[ \t]*[-_*═─━=•·. …]{3,}[ \t]*$', multiLine: true),
      '',
    )
    .replaceAll(RegExp('[\u00ad\u200b\ufeff]'), '')
    .replaceAll(RegExp('[\u00a0\u202f]'), ' ')
    .trim();

String normalizeSpeechText(String text) => _cleanSpeechLayout(text)
    // A hesitation followed by a lowercase continuation is a pause inside
    // the sentence ('Eu… sim', 'O… o nosso'), not a one-letter sentence that
    // a phonemizer may spell out. Sentence endings keep a full stop.
    .replaceAll(RegExp(r'(?:\.{2,}|…+)(?=\s+\p{Ll})', unicode: true), ',')
    .replaceAll(RegExp(r'\.{2,}|…+'), '.')
    .replaceAll(RegExp(r'[—–]'), ', ')
    .replaceAll(RegExp(r'^[ \t]*,[ \t]+', multiLine: true), '')
    .replaceAllMapped(RegExp(r'([.!?;:,])[ \t]*,[ \t]*'), (m) => '${m[1]} ')
    .replaceAll(RegExp(r'[ \t]+(?=[,.;:!?])'), '')
    .replaceAll(RegExp(r'[ \t]+'), ' ')
    .trim();

/// Bounded utterances keep synthesis, cancellation and resume responsive even
/// for a long unpunctuated paragraph. Split on sentence/clause boundaries when
/// possible, otherwise on whitespace, never inside a word or surrogate pair.
List<String> utterancesFor(
  String text, {
  bool preservePunctuation = false,
  int limit = 240,
}) {
  if (limit < 60) throw ArgumentError.value(limit, 'limit');
  final prepared = preservePunctuation
      ? _cleanSpeechLayout(text)
      : normalizeSpeechText(text);
  final result = <String>[];
  for (final paragraph in prepared.split(RegExp(r'\n\s*\n'))) {
    final rest = paragraph.replaceAll(RegExp(r'\s+'), ' ').trim();
    var start = 0;
    while (rest.length - start > limit) {
      final window = rest.substring(start, start + limit + 1);
      var cut = -1;
      for (final match in RegExp(
        r'[.!?;:]["”’»)]?\s+|,\s+',
      ).allMatches(window)) {
        final end = match.end - 1;
        final before = window.substring(0, end).trimRight();
        // Keep abbreviations and initials with the following word.
        if (RegExp(
          r'(?:\b(?:Dr|Dra|Sr|Sra|Prof|Profa|Mr|Mrs|Ms|St|etc)|\b[A-ZÀ-Ý])\.$',
          caseSensitive: false,
        ).hasMatch(before)) {
          continue;
        }
        if (end >= 60) cut = end;
      }
      if (cut >= 0) {
        cut += start;
      } else {
        cut = rest.lastIndexOf(' ', start + limit);
      }
      if (cut <= start) cut = rest.indexOf(' ', start + limit);
      if (cut < 0) break; // one exceptionally long token: never cut its word
      final piece = rest.substring(start, cut).trim();
      if (_hasWords(piece)) result.add(piece);
      start = cut;
      while (start < rest.length && rest[start] == ' ') {
        start++;
      }
    }
    final tail = rest.substring(start);
    if (_hasWords(tail)) result.add(tail);
  }
  return result;
}

bool _hasWords(String text) =>
    RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(text);

/// A slice of a document that can be edited on its own, addressed by
/// character offsets into the full content.
class EditableSection {
  const EditableSection({
    required this.title,
    required this.start,
    required this.end,
  });

  final String title;

  /// Inclusive character offset of the first character of the slice.
  final int start;

  /// Exclusive character offset of the end of the slice.
  final int end;
}

/// Documents at or above this many characters are edited a section at a
/// time. Measured on this app's own editor: a keystroke in a TextField
/// holding ~90 000 characters costs ~42 ms, against ~10 ms for an ~8 000
/// character slice of the same text — Flutter's EditableText re-lays out the
/// entire string on every change and has no viewport culling to fall back
/// on, so the only way to make a long document type at full speed is to stop
/// putting all of it in the field at once.
const int sectionedEditingThreshold = 20000;

/// Target size of a slice when a document has no headings to cut along.
const int _windowTarget = 8000;

/// Splits content into editable slices.
///
/// Prefers the document's own `#`/`##` headings, so the slices line up with
/// chapters the author already thinks in. Falls back to blank-line-aligned
/// windows of roughly [_windowTarget] characters when there are no headings
/// — never cutting mid-paragraph, so an edit never straddles a boundary.
List<EditableSection> editableSectionsOf(
  String content, {
  String? fallbackTitle,
}) {
  if (content.isEmpty) {
    return [EditableSection(title: fallbackTitle ?? '1', start: 0, end: 0)];
  }
  final headingStarts = <({int offset, String title})>[];
  var offset = 0;
  for (final line in content.split('\n')) {
    final match = _headingPattern.firstMatch(line.trimLeft());
    if (match != null) {
      final title = _stripInlineMarkdown(match.group(2)!).trim();
      if (title.isNotEmpty) {
        headingStarts.add((offset: offset, title: title));
      }
    }
    offset += line.length + 1;
  }

  if (headingStarts.length >= 2) {
    final sections = <EditableSection>[];
    if (headingStarts.first.offset > 0) {
      sections.add(
        EditableSection(
          title: fallbackTitle ?? '…',
          start: 0,
          end: headingStarts.first.offset,
        ),
      );
    }
    for (var i = 0; i < headingStarts.length; i++) {
      sections.add(
        EditableSection(
          title: headingStarts[i].title,
          start: headingStarts[i].offset,
          end: i + 1 < headingStarts.length
              ? headingStarts[i + 1].offset
              : content.length,
        ),
      );
    }
    return sections;
  }

  // No usable headings: cut on blank lines near the target size.
  final sections = <EditableSection>[];
  var start = 0;
  var index = 1;
  while (start < content.length) {
    if (content.length - start <= _windowTarget + _windowTarget ~/ 2) {
      sections.add(
        EditableSection(title: '$index', start: start, end: content.length),
      );
      break;
    }
    var cut = content.indexOf('\n\n', start + _windowTarget);
    if (cut == -1) {
      cut = content.length;
    } else {
      cut += 2;
    }
    sections.add(EditableSection(title: '$index', start: start, end: cut));
    start = cut;
    index++;
  }
  return sections.isEmpty
      ? [EditableSection(title: '1', start: 0, end: content.length)]
      : sections;
}
