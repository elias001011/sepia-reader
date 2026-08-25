import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:highlight/highlight.dart' as hl;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../models/app_settings.dart';
import '../models/library_document.dart';
import '../services/document_kind.dart';

/// Splits a document's content into the same fixed, index-addressable chunks
/// used both to render it (via [ScrollablePositionedList]) and to anchor
/// bookmarks. An index into this list is stable regardless of how much of
/// the list has actually been laid out, unlike a scroll-pixel fraction — see
/// [splitMarkdownBlocks] and [splitPlainTextChunks] for why that matters.
List<String> chunksForDocument(LibraryDocument document) =>
    document.isMarkdown
    ? splitMarkdownBlocks(document.content)
    : splitPlainTextChunks(document.content);

final _fence = RegExp(r'^(```|~~~)');
final _listOrQuote = RegExp(r'^(\s*([-*+]|\d+[.)])\s+|\s*>)');

/// Splits markdown source into block-level chunks separated by blank lines,
/// without ever cutting inside a fenced code block, and without treating a
/// blank line inside a loose list or a multi-paragraph blockquote as a real
/// separator (a line before or after the blank that looks like a list/quote
/// continuation keeps the block together).
List<String> splitMarkdownBlocks(String content) {
  final lines = content.split('\n');
  final blocks = <String>[];
  final current = <String>[];
  var inFence = false;
  String? fenceMarker;
  var pendingBlanks = 0;

  void flush() {
    if (current.isNotEmpty) {
      blocks.add(current.join('\n'));
      current.clear();
    }
  }

  for (final line in lines) {
    final fenceMatch = _fence.firstMatch(line.trimLeft());
    if (fenceMatch != null &&
        (!inFence || line.trimLeft().startsWith(fenceMarker!))) {
      inFence = !inFence;
      fenceMarker = inFence ? fenceMatch.group(1) : null;
      current.add(line);
      pendingBlanks = 0;
      continue;
    }
    if (inFence) {
      current.add(line);
      continue;
    }
    if (line.trim().isEmpty) {
      pendingBlanks++;
      continue;
    }
    if (pendingBlanks > 0) {
      // Only the line *after* the blank decides whether it continues the
      // block: a list/quote marker or an indented continuation keeps a
      // loose list or multi-paragraph quote together, but a plain new
      // paragraph after a list must start its own block, even though the
      // list item before the blank line also matches this pattern.
      final continues =
          _listOrQuote.hasMatch(line) ||
          line.startsWith('  ') ||
          line.startsWith('\t');
      if (!continues) {
        flush();
      } else {
        current.addAll(List.filled(pendingBlanks, ''));
      }
      pendingBlanks = 0;
    }
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
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: readerText.withValues(alpha: .25))),
      ),
    );
    final syntaxHighlighter = SepiaSyntaxHighlighter(baseColor: readerText);

    Widget itemFor(int index) {
      final chunk = chunks[index];
      if (document.isMarkdown) {
        return MarkdownBody(
          data: chunk,
          selectable: false,
          softLineBreak: true,
          syntaxHighlighter: syntaxHighlighter,
          styleSheet: markdownStyle,
        );
      }
      return Text.rich(
        isCodeExtension(document.extension)
            ? highlightedSpan(
                chunk,
                document.extension,
                readerText,
                settings.readerFontSize,
              )
            : TextSpan(text: chunk, style: base),
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

TextStyle readerTextStyle(AppSettings settings) => TextStyle(
  fontFamily: switch (settings.readerFont) {
    'Merriweather' => 'Merriweather',
    'Lora' => 'Lora',
    'Inter' => 'Inter',
    'Roboto Mono' => 'Roboto Mono',
    _ => null,
  },
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
