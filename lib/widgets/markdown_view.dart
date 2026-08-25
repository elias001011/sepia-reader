import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:highlight/highlight.dart' as hl;

import '../models/app_settings.dart';
import '../models/library_document.dart';

class DocumentView extends StatelessWidget {
  const DocumentView({
    super.key,
    required this.document,
    required this.settings,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 44),
    this.scrollController,
  });
  final LibraryDocument document;
  final AppSettings settings;
  final EdgeInsets padding;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
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
    return ColoredBox(
      color: readerBackground,
      child: SelectionArea(
        child: document.isMarkdown
            ? Padding(
                padding: EdgeInsets.only(left: padding.left, right: padding.right),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: settings.readerWidth),
                    child: Markdown(
                      // `Markdown` (unlike `MarkdownBody`) renders through a
                      // real ListView/Sliver, so only on-screen blocks are
                      // built/laid out/painted. MarkdownBody eagerly builds
                      // everything into a single Column with no viewport
                      // culling, which is what made big documents (~16k
                      // words) drop to ~15 FPS in reading mode.
                      controller: scrollController,
                      padding: EdgeInsets.only(
                        top: padding.top,
                        bottom: padding.bottom,
                      ),
                      data: document.content,
                      selectable: false,
                      softLineBreak: true,
                      syntaxHighlighter: SepiaSyntaxHighlighter(
                        baseColor: readerText,
                      ),
                      styleSheet: MarkdownStyleSheet(
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
                          border: Border(
                            left: BorderSide(color: accent, width: 4),
                          ),
                          color: panelColor,
                        ),
                        blockquotePadding: const EdgeInsets.fromLTRB(
                          20,
                          12,
                          16,
                          12,
                        ),
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
                          border: Border.all(
                            color: readerText.withValues(alpha: .14),
                          ),
                        ),
                        codeblockPadding: const EdgeInsets.all(18),
                        listBullet: base.copyWith(
                          color: accent,
                          fontWeight: FontWeight.bold,
                        ),
                        tableHead: base.copyWith(fontWeight: FontWeight.w800),
                        tableBody: base.copyWith(
                          fontSize: settings.readerFontSize * .86,
                        ),
                        tableBorder: TableBorder.all(
                          color: readerText.withValues(alpha: .22),
                        ),
                        tableCellsDecoration: BoxDecoration(color: panelColor),
                        tableHeadCellsDecoration: BoxDecoration(
                          color: strongerPanelColor,
                        ),
                        tableCellsPadding: const EdgeInsets.all(10),
                        horizontalRuleDecoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: readerText.withValues(alpha: .25),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : document.content.length > _virtualizeThreshold
            ? _VirtualizedPlainText(
                content: document.content,
                extension: document.extension,
                baseStyle: base,
                readerText: readerText,
                fontSize: settings.readerFontSize,
                padding: padding,
                maxWidth: settings.readerWidth,
                scrollController: scrollController,
              )
            : SingleChildScrollView(
                controller: scrollController,
                padding: padding,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: settings.readerWidth),
                    child: SelectableText.rich(
                      isCodeExtension(document.extension)
                          ? highlightedSpan(
                              document.content,
                              document.extension,
                              readerText,
                              settings.readerFontSize,
                            )
                          : TextSpan(text: document.content, style: base),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Above this size the plain-text/code reader switches to a virtualized,
/// lazily highlighted view. Smaller files keep the simpler single-span path,
/// which preserves continuous text selection across the whole document.
const int _virtualizeThreshold = 50000;

/// Number of source lines rendered per chunk.
const int _chunkLines = 120;

/// Virtualized reader for large plain-text and source files.
///
/// The eager path builds one span for the entire file (running the syntax
/// highlighter over all of it) inside a non-culling scroll view — the same
/// shape that made large markdown documents crawl. Here the file is split
/// into chunks rendered through a `ListView.builder`, so only on-screen
/// chunks are built, highlighted and painted; results are memoized so
/// scrolling back is free.
///
/// Trade-off: highlighting runs per chunk, so a construct spanning a chunk
/// boundary (a very long block comment or string) can lose its colour after
/// the boundary, and selection cannot extend into chunks that have been
/// scrolled out of the tree. Both only apply above the size threshold.
class _VirtualizedPlainText extends StatefulWidget {
  const _VirtualizedPlainText({
    required this.content,
    required this.extension,
    required this.baseStyle,
    required this.readerText,
    required this.fontSize,
    required this.padding,
    required this.maxWidth,
    this.scrollController,
  });

  final String content;
  final String extension;
  final TextStyle baseStyle;
  final Color readerText;
  final double fontSize;
  final EdgeInsets padding;
  final double maxWidth;
  final ScrollController? scrollController;

  @override
  State<_VirtualizedPlainText> createState() => _VirtualizedPlainTextState();
}

class _VirtualizedPlainTextState extends State<_VirtualizedPlainText> {
  late List<String> _chunks;
  final Map<int, TextSpan> _spans = {};

  @override
  void initState() {
    super.initState();
    _chunks = _split(widget.content);
  }

  @override
  void didUpdateWidget(_VirtualizedPlainText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.content != oldWidget.content ||
        widget.extension != oldWidget.extension ||
        widget.baseStyle != oldWidget.baseStyle ||
        widget.readerText != oldWidget.readerText ||
        widget.fontSize != oldWidget.fontSize) {
      _chunks = _split(widget.content);
      _spans.clear();
    }
  }

  static List<String> _split(String content) {
    final lines = content.split('\n');
    final chunks = <String>[];
    for (var i = 0; i < lines.length; i += _chunkLines) {
      final end = (i + _chunkLines).clamp(0, lines.length);
      chunks.add(lines.sublist(i, end).join('\n'));
    }
    return chunks.isEmpty ? [''] : chunks;
  }

  TextSpan _spanFor(int index) => _spans.putIfAbsent(index, () {
    final chunk = _chunks[index];
    if (!isCodeExtension(widget.extension)) {
      return TextSpan(text: chunk, style: widget.baseStyle);
    }
    return highlightedSpan(
      chunk,
      widget.extension,
      widget.readerText,
      widget.fontSize,
    );
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: widget.padding.left,
      right: widget.padding.right,
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: ListView.builder(
          controller: widget.scrollController,
          padding: EdgeInsets.only(
            top: widget.padding.top,
            bottom: widget.padding.bottom,
          ),
          itemCount: _chunks.length,
          itemBuilder: (context, index) => Text.rich(_spanFor(index)),
        ),
      ),
    ),
  );
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
