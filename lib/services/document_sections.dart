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

/// A code fence, capturing the whole run of markers.
///
/// Capturing only three characters made a four-backtick fence indexed as a
/// three-backtick one, so an inner ```` ``` ```` — the ordinary way to show a
/// code block inside a code block — closed the outer fence.
final _fencedCode = RegExp(r'^(`{3,}|~{3,})');
final _imagePattern = RegExp(r'!\[([^\]]*)\]\([^)]*\)');
final _linkPattern = RegExp(r'\[([^\]]+)\]\([^)]*\)');
final _emphasis = RegExp(r'(\*{1,3}|_{1,3})(\S(?:.*?\S)?)\1');
final _inlineCode = RegExp(r'`([^`]+)`');
final _htmlTag = RegExp(r'<[^>]+>');
final _leadingMarker = RegExp(r'^\s*(#{1,6}\s+|[-*+]\s+|\d+[.)]\s+)');
final _quoteMarker = RegExp(r'^\s*(>\s?)+');
final _tableRow = RegExp(r'^\s*\|.*\|\s*$');
final _tableDivider = RegExp(r'^\s*\|[\s:|-]+\|\s*$');
final _taskMarker = RegExp(r'^\s*\[[ xX]\]\s+');
final _strikethrough = RegExp(r'~~(.+?)~~');
final _footnoteRef = RegExp(r'\[\^([^\]]+)\]');
final _footnoteDef = RegExp(r'^\s{0,3}\[\^[^\]]+\]:\s*');
final _linkDef = RegExp(r'^\s{0,3}\[[^\]^][^\]]*\]:\s*\S+\s*$');
final _mathFence = RegExp(r'^\s*\$\$\s*$');
/// The `====` / `----` rule under a setext heading. It carries no words, and
/// read aloud it is a stream of "equals equals equals".
final _setextUnderline = RegExp(r'^\s{0,3}(=+|-{2,})\s*$');
final _horizontalRule = RegExp(r'^\s*([-*_])(\s*\1){2,}\s*$');

/// Turns markdown source into something worth reading out loud.
///
/// A speech engine given raw markdown says "hash hash Capítulo um" or spells
/// out a URL, so the syntax has to go before the text does. Fenced code
/// blocks are dropped entirely rather than read character by character;
/// alt text is kept, because that is exactly the text meant to stand in for
/// an image someone cannot see.
String speakableText(String markdown) {
  final lines = markdown.split('\n');
  final output = <String>[];
  var inFence = false;
  String? fenceMarker;
  var fenceWasQuoted = false;
  var inMath = false;
  for (final rawLine in lines) {
    if (inFence) {
      // Only a fence written the way this block was opened can close it.
      // Quote-stripping every line while inside an unquoted fence let a
      // line like "> ```dart" — ordinary content in a markdown tutorial —
      // close the block early and leak the rest of the code into the
      // spoken text.
      final candidate = fenceWasQuoted
          ? rawLine.replaceFirst(_quoteMarker, '')
          : rawLine;
      final closing = _fencedCode.firstMatch(candidate.trimLeft());
      // A fence closes only on a run of the same character at least as long
      // as the one that opened it — anything shorter is content.
      if (closing != null &&
          closing.group(1)![0] == fenceMarker![0] &&
          closing.group(1)!.length >= fenceMarker.length) {
        inFence = false;
        fenceMarker = null;
      }
      continue;
    }
    // Outside a fence the quote marker comes off at every level: a fenced
    // block inside a blockquote is still a fenced block, and a `>>` line
    // kept its second marker and was read aloud.
    final line = rawLine.replaceFirst(_quoteMarker, '');
    final opening = _fencedCode.firstMatch(line.trimLeft());
    if (opening != null) {
      inFence = true;
      fenceMarker = opening.group(1);
      fenceWasQuoted = line.length != rawLine.length;
      continue;
    }
    // A display equation read aloud is a stream of backslashes and braces.
    if (_mathFence.hasMatch(line)) {
      inMath = !inMath;
      continue;
    }
    if (inMath) continue;
    // A link reference definition is machinery, not prose.
    if (_linkDef.hasMatch(line)) continue;
    if (_horizontalRule.hasMatch(line) || _setextUnderline.hasMatch(line)) {
      output.add('');
      continue;
    }
    // A table read literally becomes "pipe left columns pipe right columns
    // pipe, dash dash dash…". The alignment row carries no words at all, so
    // it goes; the rest becomes the cells, separated by pauses.
    if (_tableDivider.hasMatch(line)) continue;
    if (_tableRow.hasMatch(line)) {
      // Split on unescaped pipes only: `\|` is a literal pipe inside a
      // cell, and splitting there cut the cell in half and left the
      // backslash behind to be read out.
      final cells = line
          .trim()
          .split(RegExp(r'(?<!\\)\|'))
          .map((cell) => _stripInlineMarkdown(cell).trim())
          .where((cell) => cell.isNotEmpty)
          .toList();
      if (cells.isNotEmpty) {
        output.add("${cells.join(', ')}.");
      }
      continue;
    }
    var text = line;
    // The footnote's marker goes; the note itself is content and stays.
    text = text.replaceFirst(_footnoteDef, '');
    text = text.replaceFirst(_leadingMarker, '');
    // "[x] Set up the editor" must not be read as "bracket x bracket".
    text = text.replaceFirst(_taskMarker, '');
    text = _stripInlineMarkdown(text);
    output.add(text.trim());
  }
  return output
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// Placeholder for a backslash-escaped character while the markdown syntax
/// around it is stripped, so `\*` survives as a literal asterisk instead of
/// being read as emphasis — or worse, half-eaten into a stray backslash.
const _escapeSentinel = '\u0000';

String _stripInlineMarkdown(String input) {
  final escaped = <String>[];
  var text = input.replaceAllMapped(
    RegExp(r'\\([\\`*_{}\[\]()#+\-.!~|<>])'),
    (match) {
      escaped.add(match.group(1)!);
      return '$_escapeSentinel${escaped.length - 1}$_escapeSentinel';
    },
  );
  text = text.replaceAllMapped(_strikethrough, (m) => m.group(1) ?? '');
  text = text.replaceAll(_footnoteRef, '');
  text = text.replaceAllMapped(_imagePattern, (m) => m.group(1) ?? '');
  text = text.replaceAllMapped(_linkPattern, (m) => m.group(1) ?? '');
  text = text.replaceAllMapped(_inlineCode, (m) => m.group(1) ?? '');
  // Emphasis can nest (`***bold italic***`), so peel it until it stops
  // changing instead of assuming a single pass is enough.
  for (var i = 0; i < 3; i++) {
    final peeled = text.replaceAllMapped(_emphasis, (m) => m.group(2) ?? '');
    if (peeled == text) break;
    text = peeled;
  }
  text = text.replaceAll(_htmlTag, '');
  for (var i = 0; i < escaped.length; i++) {
    text = text.replaceAll('$_escapeSentinel$i$_escapeSentinel', escaped[i]);
  }
  return text;
}

/// Breaks a section's text into utterances short enough for a speech engine
/// to start quickly and for playback to resume near where it stopped.
///
/// Handing a whole chapter to the engine in one call means a long silence
/// before the first word, no way to track progress, and a resume that can
/// only start from the top. Sentence-sized pieces make all three work, and
/// they are also the natural unit to pre-render for a neural engine later.
List<String> utterancesFor(String text) {
  final result = <String>[];
  for (final paragraph in text.split(RegExp(r'\n\s*\n'))) {
    final trimmed = paragraph.replaceAll('\n', ' ').trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.length <= 240) {
      result.add(trimmed);
      continue;
    }
    // Split after sentence-ending punctuation followed by a space, keeping
    // the punctuation with the sentence it ends.
    final sentences = trimmed.split(RegExp(r'(?<=[.!?…])\s+'));
    final buffer = StringBuffer();
    for (final sentence in sentences) {
      if (buffer.isNotEmpty && buffer.length + sentence.length > 240) {
        result.add(buffer.toString().trim());
        buffer.clear();
      }
      if (sentence.length > 240) {
        // A single sentence longer than the budget: fall back to commas, and
        // failing that let it through whole rather than cutting mid-word.
        if (buffer.isNotEmpty) {
          result.add(buffer.toString().trim());
          buffer.clear();
        }
        for (final clause in sentence.split(RegExp(r'(?<=[,;:])\s+'))) {
          result.add(clause.trim());
        }
        continue;
      }
      buffer.write(buffer.isEmpty ? sentence : ' $sentence');
    }
    if (buffer.isNotEmpty) result.add(buffer.toString().trim());
  }
  return result.where((item) => item.isNotEmpty).toList(growable: false);
}

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
List<EditableSection> editableSectionsOf(String content, {String? fallbackTitle}) {
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
        EditableSection(
          title: '$index',
          start: start,
          end: content.length,
        ),
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
