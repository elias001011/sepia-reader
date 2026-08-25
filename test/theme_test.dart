import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/models/library_document.dart';
import 'package:sepia_reader/theme/sepia_theme.dart';
import 'package:sepia_reader/widgets/markdown_view.dart';

void main() {
  test('fundo claro alimenta todas as superfícies Material', () {
    const background = Color(0xFFE1F0E8);
    final theme = buildSepiaTheme(
      const AppSettings(appBackground: background),
      Brightness.light,
    );

    expect(theme.scaffoldBackgroundColor, background);
    expect(theme.colorScheme.surface, background);
    expect(theme.cardTheme.color, theme.colorScheme.surfaceContainerLow);
    expect(
      theme.inputDecorationTheme.fillColor,
      theme.colorScheme.surfaceContainerLow,
    );
    expect(theme.cardTheme.color, isNot(const Color(0xFFFFFBF5)));
  });

  test('fundo escuro personalizado substitui os marrons fixos', () {
    const background = Color(0xFF102030);
    final theme = buildSepiaTheme(
      const AppSettings(darkAppBackground: background),
      Brightness.dark,
    );

    expect(theme.scaffoldBackgroundColor, background);
    expect(theme.colorScheme.surface, background);
    expect(theme.cardTheme.color, isNot(const Color(0xFF211C18)));
  });

  test('luminosidade efetiva acompanha um fundo personalizado extremo', () {
    final theme = buildSepiaTheme(
      const AppSettings(appBackground: Color(0xFF6B3948)),
      Brightness.light,
    );

    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.brightness, Brightness.dark);
    expect(theme.colorScheme.onSurface.computeLuminance(), greaterThan(.8));
  });

  test('AMOLED usa preto puro em todas as superfícies', () {
    final theme = buildSepiaTheme(
      const AppSettings(amoledTheme: true),
      Brightness.dark,
    );

    expect(theme.scaffoldBackgroundColor, Colors.black);
    expect(theme.colorScheme.surface, Colors.black);
    expect(theme.colorScheme.surfaceContainerLowest, Colors.black);
    expect(theme.colorScheme.surfaceContainerLow, Colors.black);
    expect(theme.colorScheme.surfaceContainer, Colors.black);
    expect(theme.colorScheme.surfaceContainerHigh, Colors.black);
    expect(theme.cardTheme.color, Colors.black);
    expect(theme.inputDecorationTheme.fillColor, Colors.black);
  });

  testWidgets('leitor pode seguir as superfícies do tema', (tester) async {
    const background = Color(0xFFE1F0E8);
    const settings = AppSettings(
      appBackground: background,
      readerBackground: Color(0xFF6B4933),
      readerFollowsTheme: true,
    );
    final now = DateTime(2026);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSepiaTheme(settings, Brightness.light),
        home: DocumentView(
          settings: settings,
          document: LibraryDocument(
            id: 'theme-document',
            title: 'Tema',
            content: '# Tema',
            extension: 'md',
            createdAt: now,
            updatedAt: now,
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == background,
      ),
      findsOneWidget,
    );
  });
}
