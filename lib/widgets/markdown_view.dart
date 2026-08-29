import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:highlight/highlight.dart' as hl;
import 'package:markdown/markdown.dart' as md;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../models/app_settings.dart';
import '../models/library_document.dart';
import '../services/document_kind.dart';

/// Splits a document's content into the same fixed, index-addressable chunks
/// used both to render it (via [ScrollablePositionedList]) and to anchor
/// bookmarks. An index into this list is stable regardless of how much of
/// the list has actually been laid out, unlike a scroll-pixel fraction — see
/// [splitMarkdownBlocks] and [splitPlainTextChunks] for why that matters.
List<String> chunksForDocument(LibraryDocument document) {
  final cached = _chunkCache;
  if (cached != null &&
      cached.markdown == document.isMarkdown &&
      identical(cached.content, document.content)) {
    return cached.chunks;
  }
  final chunks = document.isMarkdown
      ? splitMarkdownBlocks(document.content)
      : splitPlainTextChunks(document.content);
  _chunkCache = (
    content: document.content,
    markdown: document.isMarkdown,
    chunks: chunks,
  );
  return chunks;
}

/// Last split, kept because splitting is a full pass over the document and
/// the same one is asked for repeatedly: once per reader rebuild, again to
/// place a bookmark, again to build a chapter's utterances. On a 180 kB
/// document that pass costs about 4 ms, which is most of a frame's budget
/// to spend on an answer that has not changed.
///
/// Keyed by identity rather than equality on purpose — comparing two 180 kB
/// strings would cost as much as redoing the work.
///
/// One entry, deliberately: the reader shows one document at a time, and a
/// cache that grew would keep every document ever opened alive in memory.
({String content, bool markdown, List<String> chunks})? _chunkCache;

/// Drops the cached split and link definitions.
///
/// Nothing in the app needs this — the entries are replaced as soon as
/// another document is rendered — but a test that measures splitting must
/// be able to start from a known state rather than from whatever the
/// previous test in the file left behind.
@visibleForTesting
void clearMarkdownCaches() {
  _chunkCache = null;
  _definitionCache = null;
}

/// Same reasoning for the link definitions, which are also a full pass and
/// are needed on every reader rebuild.
({String content, String definitions})? _definitionCache;

final _fence = RegExp(r'^(```|~~~)');
final _listItem = RegExp(r'^\s*([-*+]|\d+[.)])\s+');
final _quoteLine = RegExp(r'^\s*>');
final _indented = RegExp(r'^(\s{2,}|\t)');

/// What kind of block a line opens, for deciding what may continue it.
enum _BlockKind { list, quote, other }

_BlockKind _kindOf(String line) {
  if (_quoteLine.hasMatch(line)) return _BlockKind.quote;
  if (_listItem.hasMatch(line)) return _BlockKind.list;
  return _BlockKind.other;
}

/// Splits markdown source into block-level chunks separated by blank lines.
///
/// Three things have to survive the split, and each one was learned the hard
/// way from a document that used them together:
///
///  * a fenced code block is never cut, and a fence indented inside a list
///    item stays with that item rather than becoming a block of its own;
///  * a blank line inside a loose list or a multi-paragraph quote is not a
///    real separator — but only the *same* kind continues, so a list
///    followed by a quote, or a heading followed by a list, still separate;
///  * everything else splits on the blank line, so the reader can build one
///    block at a time.
List<String> splitMarkdownBlocks(String content) {
  final lines = content.split('\n');
  final blocks = <String>[];
  final current = <String>[];
  var inFence = false;
  String? fenceMarker;
  var fenceIsIndented = false;
  var pendingBlanks = 0;
  var blockKind = _BlockKind.other;

  void flush() {
    if (current.isNotEmpty) {
      blocks.add(current.join('\n'));
      current.clear();
      blockKind = _BlockKind.other;
    }
  }

  /// The last line that actually carries content, which is what decides
  /// whether the block can keep going across a blank line.
  String lastMeaningful() => current.lastWhere(
    (candidate) => candidate.trim().isNotEmpty,
    orElse: () => '',
  );

  for (final line in lines) {
    final trimmedLeft = line.trimLeft();
    final fenceMatch = _fence.firstMatch(trimmedLeft);

    if (inFence) {
      current.add(line);
      if (fenceMatch != null && trimmedLeft.startsWith(fenceMarker!)) {
        inFence = false;
        fenceMarker = null;
        // A fence that belongs to a list item leaves the item open; a
        // top-level one ends its block right here.
        if (!(fenceIsIndented && blockKind == _BlockKind.list)) flush();
      }
      continue;
    }

    if (fenceMatch != null) {
      final indented = line.length != trimmedLeft.length;
      // A fence opening after a blank line starts its own block — unless it
      // is indented under a list item that is still open, in which case it
      // is part of that item.
      if (pendingBlanks > 0) {
        if (indented && blockKind == _BlockKind.list) {
          current.addAll(List.filled(pendingBlanks, ''));
        } else {
          flush();
        }
      }
      pendingBlanks = 0;
      if (current.isEmpty) blockKind = _kindOf(line);
      fenceIsIndented = indented;
      inFence = true;
      fenceMarker = fenceMatch.group(1);
      current.add(line);
      continue;
    }

    if (line.trim().isEmpty) {
      pendingBlanks++;
      continue;
    }

    if (pendingBlanks > 0) {
      final previous = lastMeaningful();
      final previousKind = previous.isEmpty ? blockKind : _kindOf(previous);
      final continues = switch (blockKind) {
        // An indented line under a list is a continuation paragraph of the
        // item it sits under; another marker is the next item.
        _BlockKind.list =>
          (previousKind == _BlockKind.list || _indented.hasMatch(previous)) &&
              (_listItem.hasMatch(line) || _indented.hasMatch(line)),
        _BlockKind.quote => _quoteLine.hasMatch(line),
        // An indented code block keeps going across a blank line, as long
        // as what follows is still indented: splitting there rendered one
        // block of code as two boxes with a gap between them.
        _BlockKind.other =>
          _indented.hasMatch(previous) && _indented.hasMatch(line),
      };
      if (continues) {
        current.addAll(List.filled(pendingBlanks, ''));
      } else {
        flush();
      }
      pendingBlanks = 0;
    }

    if (current.isEmpty) blockKind = _kindOf(line);
    current.add(line);
  }
  flush();
  return blocks.isEmpty ? [''] : blocks;
}

/// Number of source lines rendered per chunk for plain-text/code documents.
const int plainTextChunkLines = 120;

/// Splits plain-text/code source into fixed-size line chunks. Highlighting a
/// construct that spans a chunk boundary (a long block comment or string)
/// can lose its colour after the boundary — an accepted trade-off for
/// virtualizing files of any size and giving every document, large or
/// small, the same index-addressable chunks that bookmarks rely on.
List<String> splitPlainTextChunks(String content) {
  final lines = content.split('\n');
  final chunks = <String>[];
  for (var i = 0; i < lines.length; i += plainTextChunkLines) {
    final end = (i + plainTextChunkLines).clamp(0, lines.length);
    chunks.add(lines.sublist(i, end).join('\n'));
  }
  return chunks.isEmpty ? [''] : chunks;
}


/// Matches a link reference definition line: `[label]: https://…`.
final _linkDefinition = RegExp(r'^\s{0,3}\[([^\]^][^\]]*)\]:\s*\S+');

/// Matches a footnote definition line: `[^1]: text`.
final _footnoteDefinition = RegExp(r'^\s{0,3}\[\^([^\]]+)\]:\s*(.*)$');

/// Matches an inline footnote reference: `[^1]`.
final _footnoteReference = RegExp(r'\[\^([^\]]+)\]');

/// Matches a `$$ … $$` display-math block.
final _mathBlock = RegExp(r'^\s*\$\$[\s\S]*\$\$\s*$');

/// Every link reference definition in the document, as markdown source.
///
/// Reference-style links (`[text][label]` with `[label]: url` elsewhere)
/// broke the moment the reader started rendering one block at a time: the
/// definition almost always lives in a different chunk from the link that
/// uses it, and a markdown parser given only the link renders it as literal
/// brackets. Collecting the definitions once and appending them to every
/// chunk puts them back within reach — they render as nothing on their own,
/// so the cost is only in the parse.
String collectLinkDefinitions(String content) {
  final cached = _definitionCache;
  if (cached != null && identical(cached.content, content)) {
    return cached.definitions;
  }
  final result = _scanLinkDefinitions(content);
  _definitionCache = (content: content, definitions: result);
  return result;
}

String _scanLinkDefinitions(String content) {
  final definitions = <String>[];
  for (final line in content.split('\n')) {
    if (_linkDefinition.hasMatch(line)) definitions.add(line.trim());
  }
  return definitions.isEmpty ? '' : '\n\n${definitions.join('\n')}';
}

const _superscripts = {
  '0': '\u2070', '1': '\u00b9', '2': '\u00b2', '3': '\u00b3',
  '4': '\u2074', '5': '\u2075', '6': '\u2076', '7': '\u2077',
  '8': '\u2078', '9': '\u2079',
};

String _superscript(String label) {
  final buffer = StringBuffer();
  for (final char in label.split('')) {
    final mapped = _superscripts[char];
    if (mapped == null) return label;
    buffer.write(mapped);
  }
  return buffer.toString();
}

/// Rewrites footnotes into something the markdown renderer can show.
///
/// `flutter_markdown_plus` has no notion of footnotes, so `[^1]` came out as
/// literal brackets and `[^1]: …` as a stray paragraph of punctuation. A
/// numeric label becomes a real superscript, and the definition becomes an
/// italic note introduced by that same superscript — not the bottom-of-page
/// treatment a typesetter would give it, but readable, and unmistakably a
/// note rather than a typo.
String rewriteFootnotes(String chunk) {
  final definition = _footnoteDefinition.firstMatch(chunk);
  if (definition != null) {
    final label = _superscript(definition.group(1)!);
    final body = definition.group(2)!.trim();
    return body.isEmpty ? '' : '$label *$body*';
  }
  return chunk.replaceAllMapped(
    _footnoteReference,
    (match) => _superscript(match.group(1)!),
  );
}

/// Whether a chunk holds nothing but link reference definitions, which are
/// metadata rather than content and should occupy no space in the reader.
bool isLinkDefinitionOnly(String chunk) {
  final lines = chunk.split('\n').where((l) => l.trim().isNotEmpty);
  return lines.isNotEmpty && lines.every(_linkDefinition.hasMatch);
}

bool isMathBlock(String chunk) => _mathBlock.hasMatch(chunk);

class DocumentView extends StatelessWidget {
  const DocumentView({
    super.key,
    required this.document,
    required this.settings,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 44),
    this.itemScrollController,
    this.itemPositionsListener,
    this.asSource = false,
  });
  final LibraryDocument document;
  final AppSettings settings;
  final EdgeInsets padding;
  final ItemScrollController? itemScrollController;
  final ItemPositionsListener? itemPositionsListener;

  /// Forces the monospace viewer even for a kind that would normally be
  /// rendered — how "show me the HTML source" is expressed.
  final bool asSource;

  @override
  Widget build(BuildContext context) {
    // Source code is not prose, and the prose reader was never right for it:
    // a serif face at 20pt in a 760px column, with the reader's paper
    // colours, makes a stylesheet harder to read than a plain editor would.
    // Code gets its own viewer instead — monospace, full width, numbered
    // lines, theme colours.
    if (asSource || documentKindOf(document.extension) == DocumentKind.code) {
      return CodeViewer(
        document: document,
        itemScrollController: itemScrollController,
        itemPositionsListener: itemPositionsListener,
        padding: padding,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final readerBackground = settings.readerFollowsTheme
        ? scheme.surface
        : settings.readerBackground;
    final readerText = settings.readerFollowsTheme
        ? scheme.onSurface
        : settings.readerText;
    final accent = settings.readerFollowsTheme
        ? scheme.primary
        : _accent(readerBackground);
    final panelColor = Color.alphaBlend(
      readerText.withValues(alpha: .075),
      readerBackground,
    );
    final strongerPanelColor = Color.alphaBlend(
      readerText.withValues(alpha: .12),
      readerBackground,
    );
    final base = readerTextStyle(settings).copyWith(
      color: readerText,
      fontSize: settings.readerFontSize,
      height: settings.readerLineHeight,
    );
    final chunks = chunksForDocument(document);
    final linkDefinitions = document.isMarkdown
        ? collectLinkDefinitions(document.content)
        : '';
    final markdownStyle = MarkdownStyleSheet(
      p: base,
      a: base.copyWith(
        color: accent,
        decoration: TextDecoration.underline,
        decorationColor: accent,
      ),
      h1: base.copyWith(
        fontSize: settings.readerFontSize * 2,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
      h2: base.copyWith(
        fontSize: settings.readerFontSize * 1.55,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      h3: base.copyWith(
        fontSize: settings.readerFontSize * 1.25,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      h4: base.copyWith(fontWeight: FontWeight.w700),
      h5: base.copyWith(fontWeight: FontWeight.w700),
      h6: base.copyWith(fontWeight: FontWeight.w700),
      strong: base.copyWith(fontWeight: FontWeight.w800),
      em: base.copyWith(fontStyle: FontStyle.italic),
      del: base.copyWith(
        decoration: TextDecoration.lineThrough,
        decorationColor: readerText,
      ),
      img: base,
      checkbox: base.copyWith(color: accent),
      blockquote: base.copyWith(
        color: readerText.withValues(alpha: .82),
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: accent, width: 4)),
        color: panelColor,
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      code: TextStyle(
        fontFamily: 'Roboto Mono',
        color: readerText,
        backgroundColor: panelColor,
        fontSize: settings.readerFontSize * .76,
        height: 1.55,
      ),
      codeblockDecoration: BoxDecoration(
        color: readerText.withValues(alpha: .075),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: readerText.withValues(alpha: .14)),
      ),
      codeblockPadding: const EdgeInsets.all(18),
      listBullet: base.copyWith(color: accent, fontWeight: FontWeight.bold),
      tableHead: base.copyWith(fontWeight: FontWeight.w800),
      tableBody: base.copyWith(fontSize: settings.readerFontSize * .86),
      tableBorder: TableBorder.all(color: readerText.withValues(alpha: .22)),
      tableCellsDecoration: BoxDecoration(color: panelColor),
      tableHeadCellsDecoration: BoxDecoration(color: strongerPanelColor),
      tableCellsPadding: const EdgeInsets.all(10),
      blockSpacing: settings.readerFontSize * 0.55,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: readerText.withValues(alpha: .25))),
      ),
    );
    final syntaxHighlighter = SepiaSyntaxHighlighter(baseColor: readerText);

    // Each chunk is its own widget in the list, so the vertical rhythm that
    // a single markdown widget would have produced between its blocks has
    // to be put back by hand — without it every paragraph, heading and list
    // butted straight up against the next one.
    final blockSpacing = settings.readerFontSize * 0.8;

    Widget itemFor(int index) {
      final chunk = chunks[index];
      if (document.isMarkdown) {
        if (isLinkDefinitionOnly(chunk)) return const SizedBox.shrink();
        if (isMathBlock(chunk)) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: blockSpacing / 2),
            child: FormulaBlock(
              source: chunk,
              textColor: readerText,
              fontSize: settings.readerFontSize,
            ),
          );
        }
        // A heading opens a section, and wants more air above it than
        // between two paragraphs — but not at the very top of the document.
        final startsSection =
            index > 0 && RegExp(r'^\s{0,3}#{1,6}\s').hasMatch(chunk);
        return Padding(
          padding: EdgeInsets.only(
            top: startsSection ? blockSpacing * 1.6 : 0,
            bottom: blockSpacing,
          ),
          child: MarkdownBody(
            data: '${rewriteFootnotes(chunk)}$linkDefinitions',
            selectable: false,
            softLineBreak: true,
            syntaxHighlighter: syntaxHighlighter,
            styleSheet: markdownStyle,
            builders: {'code': DiagramAwareCodeBuilder(
              textColor: readerText,
              fontSize: settings.readerFontSize,
            )},
          ),
        );
      }
      return Padding(
        padding: EdgeInsets.only(bottom: blockSpacing / 2),
        child: Text.rich(
          isCodeExtension(document.extension)
              ? highlightedSpan(
                  chunk,
                  document.extension,
                  readerText,
                  settings.readerFontSize,
                )
              : TextSpan(text: chunk, style: base),
        ),
      );
    }

    return ColoredBox(
      color: readerBackground,
      child: SelectionArea(
        child: Padding(
          padding: EdgeInsets.only(left: padding.left, right: padding.right),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: settings.readerWidth),
              // Each document chunk (a markdown block, or a fixed-size line
              // range for plain text/code) is its own list item. Unlike the
              // old single MarkdownBody/SelectableText — which built the
              // whole document into one non-culling widget, dropping large
              // documents (~16k words) to ~15 FPS in reading mode —
              // ScrollablePositionedList only builds on-screen items, *and*
              // gives every chunk a stable integer index that bookmarks can
              // jump to directly. That index never drifts: a pixel-fraction
              // anchor computed against this list's scroll extent would,
              // because that extent is only an estimate extrapolated from
              // whichever chunks happen to be realized right now, and it
              // measurably shifts (~20% in testing) between a freshly opened
              // document and one that has been scrolled through.
              child: ScrollablePositionedList.builder(
                itemScrollController: itemScrollController,
                itemPositionsListener: itemPositionsListener,
                padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
                itemCount: chunks.length,
                itemBuilder: (context, index) => itemFor(index),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The reading font names offered in the reader settings. The stored value is
/// the font family exactly as declared in `pubspec.yaml`, so a new face only
/// needs adding here and there — [readerTextStyle] passes it straight through.
/// `'Sistema'` (and any unknown value) falls back to the platform font.
const readerFontChoices = <String>[
  'Merriweather',
  'Newsreader',
  'Merriweather Sans',
  'Literata',
  'Lora',
  'Bitter',
  'Source Serif 4',
  'EB Garamond',
  'Atkinson Hyperlegible',
  'Inter',
  'Roboto Mono',
  'JetBrains Mono',
  'Sistema',
];

TextStyle readerTextStyle(AppSettings settings) => TextStyle(
  fontFamily: settings.readerFont == 'Sistema' || settings.readerFont.isEmpty
      ? null
      : settings.readerFont,
);

bool isCodeExtension(String extension) => const {
  'dart',
  'js',
  'ts',
  'json',
  'yaml',
  'yml',
  'html',
  'css',
  'py',
  'java',
  'kt',
  'swift',
  'sh',
  'sql',
  'xml',
}.contains(extension);

TextSpan highlightedSpan(
  String source,
  String language,
  Color baseColor,
  double fontSize,
) {
  final normalized = switch (language) {
    'js' => 'javascript',
    'ts' => 'typescript',
    'py' => 'python',
    'sh' => 'bash',
    'yml' => 'yaml',
    'kt' => 'kotlin',
    _ => language,
  };
  final result = hl.highlight.parse(source, language: normalized);
  return TextSpan(
    style: TextStyle(
      fontFamily: 'Roboto Mono',
      color: baseColor,
      fontSize: fontSize * .82,
      height: 1.65,
    ),
    children: _nodes(result.nodes ?? const [], baseColor),
  );
}

List<TextSpan> _nodes(List<hl.Node> nodes, Color baseColor) =>
    nodes.map((node) {
      final style = _tokenStyle(node.className, baseColor);
      if (node.value != null) return TextSpan(text: node.value, style: style);
      return TextSpan(
        style: style,
        children: _nodes(node.children ?? const [], baseColor),
      );
    }).toList();

TextStyle _tokenStyle(String? token, Color base) => TextStyle(
  color: switch (token) {
    'keyword' || 'selector-tag' || 'title' =>
      base.computeLuminance() > .5
          ? const Color(0xFFFF9DCD)
          : const Color(0xFF9C1A63),
    'string' || 'attribute' || 'addition' =>
      base.computeLuminance() > .5
          ? const Color(0xFFB8E986)
          : const Color(0xFF3B6F1D),
    'number' || 'literal' || 'variable' =>
      base.computeLuminance() > .5
          ? const Color(0xFFFFC875)
          : const Color(0xFF925600),
    'comment' || 'quote' => base.withValues(alpha: .52),
    'built_in' || 'type' || 'class' =>
      base.computeLuminance() > .5
          ? const Color(0xFF8DD8FF)
          : const Color(0xFF00658A),
    'meta' || 'tag' =>
      base.computeLuminance() > .5
          ? const Color(0xFFC8B6FF)
          : const Color(0xFF5B3A9B),
    _ => base,
  },
);

Color _accent(Color background) => background.computeLuminance() < .4
    ? const Color(0xFFFFC987)
    : const Color(0xFF85552F);

class SepiaSyntaxHighlighter extends SyntaxHighlighter {
  SepiaSyntaxHighlighter({required this.baseColor});
  final Color baseColor;
  @override
  TextSpan format(String source) {
    final style = TextStyle(fontFamily: 'Roboto Mono', color: baseColor);
    final language = _detectMarkdownCodeLanguage(source);
    if (language == null) return TextSpan(text: source, style: style);
    try {
      final result = hl.highlight.parse(source, language: language);
      return TextSpan(
        style: style,
        children: _nodes(result.nodes ?? const [], baseColor),
      );
    } catch (_) {
      return TextSpan(text: source, style: style);
    }
  }
}

String? _detectMarkdownCodeLanguage(String source) {
  final trimmed = source.trimLeft();
  if (RegExp(r'^\s*[\[{]').hasMatch(trimmed)) return 'json';
  if (RegExp(r'^\s*<[/!?A-Za-z]').hasMatch(trimmed)) return 'xml';
  if (RegExp(
    r'\b(SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP)\b',
    caseSensitive: false,
  ).hasMatch(source)) {
    return 'sql';
  }
  if (trimmed.startsWith('#!') ||
      RegExp(r'\b(echo|fi|done|esac)\b').hasMatch(source)) {
    return 'bash';
  }
  if (RegExp(
    r'^\s*(def|from|import)\s+\w+',
    multiLine: true,
  ).hasMatch(source)) {
    return 'python';
  }
  if (RegExp(
    r'\b(void main|Widget build|Future<|StatelessWidget|StatefulWidget)\b',
  ).hasMatch(source)) {
    return 'dart';
  }
  if (RegExp(r'\b(function|let|const|var)\b|=>').hasMatch(source)) {
    return 'javascript';
  }
  if (RegExp(r'^[\w.-]+:\s*\S+', multiLine: true).hasMatch(source)) {
    return 'yaml';
  }
  if (RegExp(r'[^{}]+\{\s*[\w-]+\s*:', multiLine: true).hasMatch(source)) {
    return 'css';
  }
  return null;
}


/// Monospace viewer for source code and structured data.
///
/// Shares the chunked, index-addressable list the prose reader uses, so
/// bookmarks and "read from here" keep working identically — only the
/// presentation differs.
class CodeViewer extends StatelessWidget {
  const CodeViewer({
    super.key,
    required this.document,
    this.itemScrollController,
    this.itemPositionsListener,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 44),
  });

  final LibraryDocument document;
  final ItemScrollController? itemScrollController;
  final ItemPositionsListener? itemPositionsListener;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chunks = splitPlainTextChunks(document.content);
    final totalLines = document.content.split('\n').length;
    final gutterWidth = 14.0 + '$totalLines'.length * 8.5;

    return ColoredBox(
      color: scheme.surface,
      child: SelectionArea(
        child: ScrollablePositionedList.builder(
          itemScrollController: itemScrollController,
          itemPositionsListener: itemPositionsListener,
          padding: EdgeInsets.fromLTRB(
            padding.left / 2,
            padding.top,
            padding.right / 2,
            padding.bottom,
          ),
          itemCount: chunks.length,
          itemBuilder: (context, index) {
            final firstLine = index * plainTextChunkLines + 1;
            final lines = highlightedLines(
              chunks[index],
              document.extension,
              scheme.onSurface,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lines.length; i++)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: gutterWidth,
                        child: Text(
                          '${firstLine + i}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: 'Roboto Mono',
                            fontSize: 12.5,
                            height: 1.6,
                            color: scheme.onSurfaceVariant.withValues(alpha: .55),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text.rich(lines[i])),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Highlights a chunk and then cuts the result into one span per source
/// line, so a numbered gutter stays aligned even when a long line wraps.
///
/// Highlighting the whole chunk first and splitting afterwards (rather than
/// highlighting each line on its own) keeps the parser's context across
/// lines, which is what a multi-line string or block comment needs to stay
/// one colour.
List<TextSpan> highlightedLines(
  String source,
  String extension,
  Color baseColor,
) {
  const style = TextStyle(
    fontFamily: 'Roboto Mono',
    fontSize: 13.5,
    height: 1.6,
  );
  final pieces = <({String text, TextStyle? style})>[];
  if (isCodeExtension(extension)) {
    _flatten(
      highlightedSpan(source, extension, baseColor, 16.5).children ?? const [],
      pieces,
    );
  } else {
    pieces.add((text: source, style: null));
  }

  final lines = <TextSpan>[];
  var current = <TextSpan>[];
  for (final piece in pieces) {
    final parts = piece.text.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        lines.add(TextSpan(style: style.copyWith(color: baseColor), children: current));
        current = <TextSpan>[];
      }
      if (parts[i].isEmpty) continue;
      current.add(TextSpan(text: parts[i], style: piece.style));
    }
  }
  lines.add(TextSpan(style: style.copyWith(color: baseColor), children: current));
  return lines;
}

void _flatten(
  List<InlineSpan> spans,
  List<({String text, TextStyle? style})> out, [
  TextStyle? inherited,
]) {
  for (final span in spans) {
    if (span is! TextSpan) continue;
    final style = span.style ?? inherited;
    if (span.text != null) out.add((text: span.text!, style: style));
    if (span.children != null) _flatten(span.children!, out, style);
  }
}

/// Renders fenced blocks that describe a *diagram* differently from code.
///
/// A ```mermaid block is not source anybody wants to read: dropped into the
/// default code block it reads as a wall of arrows and braces with no hint
/// that it was meant to be a picture. Until the diagram itself can be drawn
/// (see the note below), it is at least labelled as one, so the reader knows
/// what they are looking at instead of assuming the document is broken.
///
/// Drawing it for real needs a renderer on every platform this ships to:
/// `webview_flutter` covers Android and iOS but not Flutter web, and a
/// platform view with mermaid.js covers web but neither of the others. That
/// is a feature of its own, not a builder.
class DiagramAwareCodeBuilder extends MarkdownElementBuilder {
  DiagramAwareCodeBuilder({required this.textColor, required this.fontSize});

  final Color textColor;
  final double fontSize;

  static const _diagramLanguages = {
    'mermaid',
    'graphviz',
    'dot',
    'plantuml',
    'puml',
  };

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final language = _languageOf(element);
    if (language == null || !_diagramLanguages.contains(language)) return null;
    final source = element.textContent.trimRight();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: textColor.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_tree_rounded,
                size: fontSize * .8,
                color: textColor.withValues(alpha: .7),
              ),
              const SizedBox(width: 8),
              Text(
                language,
                style: TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: fontSize * .62,
                  letterSpacing: 1.1,
                  color: textColor.withValues(alpha: .7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              source,
              style: TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize: fontSize * .72,
                height: 1.5,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _languageOf(md.Element element) {
    // flutter_markdown_plus hands over the <code> element; the language is
    // the "language-x" class markdown puts on it.
    final classes = element.attributes['class'];
    if (classes == null) return null;
    for (final name in classes.split(RegExp(r'\s+'))) {
      if (name.startsWith('language-')) {
        return name.substring('language-'.length).toLowerCase();
      }
    }
    return null;
  }
}

/// A `$$ … $$` display equation.
///
/// Rendering LaTeX properly needs a maths typesetter, which is a dependency
/// and a feature of its own. Until then the equation is at least presented
/// as one — centred, monospaced, framed — instead of as a paragraph that
/// happens to start and end with dollar signs.
class FormulaBlock extends StatelessWidget {
  const FormulaBlock({
    super.key,
    required this.source,
    required this.textColor,
    required this.fontSize,
  });

  final String source;
  final Color textColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final body = source
        .trim()
        .replaceAll(RegExp(r'^\$\$|\$\$$'), '')
        .trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: textColor.withValues(alpha: .18)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Roboto Mono',
            fontSize: fontSize * .8,
            height: 1.5,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
