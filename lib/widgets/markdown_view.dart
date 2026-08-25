import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:highlight/highlight.dart' as hl;

import '../models/app_settings.dart';
import '../models/library_document.dart';

class DocumentView extends StatelessWidget {
  const DocumentView({
    super.key,
    required this.document,
    required this.settings,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 44),
  });
  final LibraryDocument document;
  final AppSettings settings;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final base = readerTextStyle(settings).copyWith(
      color: settings.readerText,
      fontSize: settings.readerFontSize,
      height: settings.readerLineHeight,
    );
    return ColoredBox(
      color: settings.readerBackground,
      child: SelectionArea(
        child: SingleChildScrollView(
          padding: padding,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: settings.readerWidth),
              child: document.isMarkdown
                  ? MarkdownBody(
                      data: document.content,
                      selectable: false,
                      softLineBreak: true,
                      syntaxHighlighter: SepiaSyntaxHighlighter(
                        baseColor: settings.readerText,
                      ),
                      styleSheet: MarkdownStyleSheet(
                        p: base,
                        a: base.copyWith(
                          color: _accent(settings.readerBackground),
                          decoration: TextDecoration.underline,
                          decorationColor: _accent(settings.readerBackground),
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
                        strong: base.copyWith(fontWeight: FontWeight.w800),
                        em: base.copyWith(fontStyle: FontStyle.italic),
                        blockquote: base.copyWith(
                          color: settings.readerText.withValues(alpha: .82),
                          fontStyle: FontStyle.italic,
                        ),
                        blockquoteDecoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: _accent(settings.readerBackground),
                              width: 4,
                            ),
                          ),
                          color: settings.readerText.withValues(alpha: .06),
                        ),
                        blockquotePadding: const EdgeInsets.fromLTRB(
                          20,
                          12,
                          16,
                          12,
                        ),
                        code: GoogleFonts.robotoMono(
                          color: settings.readerText,
                          fontSize: settings.readerFontSize * .76,
                          height: 1.55,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .22),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: settings.readerText.withValues(alpha: .12),
                          ),
                        ),
                        codeblockPadding: const EdgeInsets.all(18),
                        listBullet: base.copyWith(
                          color: _accent(settings.readerBackground),
                          fontWeight: FontWeight.bold,
                        ),
                        tableHead: base.copyWith(fontWeight: FontWeight.w800),
                        tableBody: base.copyWith(
                          fontSize: settings.readerFontSize * .86,
                        ),
                        tableBorder: TableBorder.all(
                          color: settings.readerText.withValues(alpha: .22),
                        ),
                        tableCellsPadding: const EdgeInsets.all(10),
                        horizontalRuleDecoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: settings.readerText.withValues(alpha: .25),
                            ),
                          ),
                        ),
                      ),
                    )
                  : SelectableText.rich(
                      isCodeExtension(document.extension)
                          ? highlightedSpan(
                              document.content,
                              document.extension,
                              settings.readerText,
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

TextStyle readerTextStyle(AppSettings settings) =>
    switch (settings.readerFont) {
      'Merriweather' => GoogleFonts.merriweather(),
      'Lora' => GoogleFonts.lora(),
      'Inter' => GoogleFonts.inter(),
      'Roboto Mono' => GoogleFonts.robotoMono(),
      _ => const TextStyle(),
    };

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
    style: GoogleFonts.robotoMono(
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
    'keyword' || 'selector-tag' || 'title' => const Color(0xFFFF9DCD),
    'string' || 'attribute' || 'addition' => const Color(0xFFB8E986),
    'number' || 'literal' || 'variable' => const Color(0xFFFFC875),
    'comment' || 'quote' => base.withValues(alpha: .52),
    'built_in' || 'type' || 'class' => const Color(0xFF8DD8FF),
    'meta' || 'tag' => const Color(0xFFC8B6FF),
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
    final result = hl.highlight.parse(source, autoDetection: true);
    return TextSpan(
      style: GoogleFonts.robotoMono(color: baseColor),
      children: _nodes(result.nodes ?? const [], baseColor),
    );
  }
}
