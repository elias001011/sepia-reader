import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/services/tts/voice_catalog.dart';
import 'package:sepia_reader/theme/sepia_theme.dart';
import 'package:sepia_reader/widgets/markdown_view.dart';
import 'package:sepia_reader/widgets/sheet_scaffold.dart';

/// Regressions found by review rather than by use. Each of these shipped
/// working code that was quietly wrong.
void main() {
  group('idioma de fonética por voz', () {
    test('cada voz do Kokoro fonetiza no próprio idioma', () {
      final kokoro = voicePacks.firstWhere((pack) => pack.isKokoro);
      // The pack holds speakers of eight languages. Handing all of them one
      // language — as a pack-level setting did — makes an English or
      // Chinese voice pronounce its text with Portuguese rules.
      final languages = kokoro.voices.map((v) => v.espeakLanguage).toSet();
      expect(languages.length, greaterThan(3));
      expect(
        kokoro.voices
            .firstWhere((v) => v.language == 'pt-BR')
            .espeakLanguage,
        'pt-br',
      );
      expect(
        kokoro.voices.firstWhere((v) => v.language == 'en-US').espeakLanguage,
        'en-us',
      );
      expect(
        kokoro.voices.firstWhere((v) => v.language == 'zh-CN').espeakLanguage,
        'cmn',
      );
    });

    test('toda voz do catálogo tem um idioma de fonética', () {
      for (final voice in allNeuralVoices) {
        expect(voice.espeakLanguage, isNotEmpty, reason: voice.id);
        expect(voice.espeakLanguage, isNot(contains('_')), reason: voice.id);
      }
    });
  });

  group('densidade visual', () {
    test('a escala parte do padrão da plataforma, não de zero', () {
      final base = VisualDensity.adaptivePlatformDensity;
      final atDefault = buildSepiaTheme(
        const AppSettings(),
        Brightness.light,
      ).visualDensity;
      expect(
        atDefault,
        base,
        reason: 'no tamanho padrão a interface tem que ficar exatamente como '
            'a plataforma define — em desktop isso é compact',
      );

      final larger = buildSepiaTheme(
        const AppSettings(uiScale: 1.4),
        Brightness.light,
      ).visualDensity;
      expect(larger.vertical, greaterThan(base.vertical));
      expect(larger.vertical, lessThanOrEqualTo(VisualDensity.maximumDensity));
    });
  });

  test('bloco de código indentado sobrevive a uma linha em branco', () {
    clearMarkdownCaches();
    final blocks = splitMarkdownBlocks(
      'Texto:\n\n    linha um\n\n    linha dois\n\nFim.',
    );
    final code = blocks.firstWhere((b) => b.contains('linha um'));
    expect(
      code,
      contains('linha dois'),
      reason: 'partir aqui renderiza um bloco de código como duas caixas',
    );
    expect(blocks.any((b) => b.trim() == 'Fim.'), isTrue);
  });

  testWidgets('a folha abre numa janela mais baixa que o mínimo', (
    tester,
  ) async {
    // `clamp` throws outright when the lower limit exceeds the upper, so a
    // very short viewport used to crash every sheet on open.
    tester.view.physicalSize = const Size(300, 180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showAppSheet<void>(
                  context: context,
                  builder: (_) => const SheetScaffold(
                    title: 'Teste',
                    children: [Text('conteúdo')],
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SheetScaffold), findsOneWidget);
  });

  test('o cache de blocos é de uma entrada só e pode ser limpo', () {
    clearMarkdownCaches();
    const source = 'um\n\ndois';
    final first = splitMarkdownBlocks(source);
    expect(first, ['um', 'dois']);
    clearMarkdownCaches();
    expect(splitMarkdownBlocks(source), first);
  });
}
