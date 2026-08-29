import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/services/document_sections.dart';
import 'package:sepia_reader/services/tts/voice_catalog.dart';
import 'package:sepia_reader/services/update_checker.dart';
import 'package:sepia_reader/theme/sepia_theme.dart';
import 'package:sepia_reader/widgets/markdown_view.dart';
import 'package:sepia_reader/widgets/sheet_scaffold.dart';

/// Regressions found by review rather than by use. Each of these shipped
/// working code that was quietly wrong.
void main() {
  test('a fonte padrão continua sendo a Merriweather original', () {
    const settings = AppSettings();
    expect(settings.readerFont, 'Merriweather');
    expect(readerTextStyle(settings).fontFamily, 'Merriweather');
    expect(settings.readerFontSize, 20);
    expect(settings.readerLineHeight, 1.75);
  });

  group('idioma de fonética por voz', () {
    test('cada voz do Kokoro fonetiza no próprio idioma', () {
      final kokoro = voicePacks.firstWhere((pack) => pack.isKokoro);
      // The pack holds speakers of eight languages. Handing all of them one
      // language — as a pack-level setting did — makes an English or
      // Chinese voice pronounce its text with Portuguese rules.
      final languages = kokoro.voices.map((v) => v.espeakLanguage).toSet();
      expect(languages.length, greaterThan(3));
      expect(
        kokoro.voices.firstWhere((v) => v.language == 'pt-BR').espeakLanguage,
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
        reason:
            'no tamanho padrão a interface tem que ficar exatamente como '
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

  testWidgets('diálogo nunca pede mais largura do que a tela oferece', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late double width;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            width = appDialogWidth(context, 360);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(width, 160);
  });

  group('cercas de código na fala (segunda rodada de review)', () {
    test('uma cerca dentro de outra não fecha a de fora', () {
      // A markdown tutorial quoting markdown: the inner "> ```dart" is
      // content, not a fence. Treating it as one closed the outer block and
      // let the code leak into what the voice reads.
      final spoken = speakableText(
        'Antes.\n\n'
        '````markdown\n'
        '> ```dart\n'
        '> final x = 1;\n'
        '> ```\n'
        '````\n\n'
        'Depois.',
      );
      expect(spoken, contains('Antes.'));
      expect(spoken, contains('Depois.'));
      expect(spoken, isNot(contains('final x = 1')));
      expect(spoken, isNot(contains('```')));
    });

    test('uma cerca dentro de citação continua sendo pulada', () {
      final spoken = speakableText(
        'Antes.\n\n> ```js\n> const a = 1;\n> ```\n\nDepois.',
      );
      expect(spoken, contains('Antes.'));
      expect(spoken, contains('Depois.'));
      expect(spoken, isNot(contains('const a = 1')));
    });

    test('uma cerca aninhada sem citação também não fecha a de fora', () {
      // Showing a code block inside a code block is the ordinary way to
      // write about markdown, and the outer fence is longer for exactly
      // that reason.
      final spoken = speakableText(
        'Antes.\n\n````markdown\n```dart\nfinal x = 1;\n```\n````\n\nDepois.',
      );
      expect(spoken, contains('Antes.'));
      expect(spoken, contains('Depois.'));
      expect(spoken, isNot(contains('final x = 1')));
    });

    test('uma cerca de til não é fechada por crase', () {
      final spoken = speakableText(
        'Antes.\n\n~~~py\n```\nx = 1\n~~~\n\nDepois.',
      );
      expect(spoken, isNot(contains('x = 1')));
      expect(spoken, contains('Depois.'));
    });
  });

  test('cano escapado não parte a célula da tabela', () {
    final spoken = speakableText('| a \\| b | c |\n|---|---|\n| d | e |');
    expect(spoken, contains('a | b'));
    expect(spoken, isNot(contains('\\')));
  });

  group('escolha de APK', () {
    const published = {
      'sepia-2.0.0-android-arm64-v8a.apk': 'u/arm64',
      'sepia-2.0.0-android-armeabi-v7a.apk': 'u/v7a',
      'sepia-2.0.0-android-x86_64.apk': 'u/x64',
      'sepia-2.0.0-android-universal.apk': 'u/universal',
    };

    test('cada arquitetura recebe o seu', () {
      expect(pickApkFor(published, ['arm64-v8a', 'universal']), 'u/arm64');
      expect(pickApkFor(published, ['armeabi-v7a', 'universal']), 'u/v7a');
      expect(pickApkFor(published, ['x86_64', 'universal']), 'u/x64');
    });

    test('x86 de 32 bits não recebe o APK de 64', () {
      // 'x86' is contained in 'x86_64'; a substring match handed a 32-bit
      // device an APK the installer rejects outright.
      expect(pickApkFor(published, ['x86', 'universal']), 'u/universal');
    });

    test('arquitetura desconhecida cai no universal', () {
      expect(pickApkFor(published, ['riscv64', 'universal']), 'u/universal');
    });

    test('sem universal e sem correspondência, não oferece nada', () {
      const partial = {'sepia-2.0.0-android-arm64-v8a.apk': 'u/arm64'};
      expect(
        pickApkFor(partial, ['x86_64', 'universal']),
        isNull,
        reason: 'um link para a release é mais útil que um APK que não instala',
      );
      expect(pickApkFor(partial, ['arm64-v8a']), 'u/arm64');
    });

    test('cada sabor recebe só o seu APK', () {
      const both = {
        'sepia-2.2.0-android-arm64-v8a.apk': 'full/arm64',
        'sepia-2.2.0-android-universal.apk': 'full/universal',
        'sepia-lite-2.2.0-android-arm64-v8a.apk': 'lite/arm64',
        'sepia-lite-2.2.0-android-universal.apk': 'lite/universal',
      };
      expect(pickApkFor(both, ['arm64-v8a', 'universal']), 'full/arm64');
      expect(
        pickApkFor(both, ['arm64-v8a', 'universal'], lite: true),
        'lite/arm64',
      );
      // A Lite build on a device the Lite APK does not cover still must not
      // fall through to the full universal one.
      expect(
        pickApkFor(both, ['riscv64', 'universal'], lite: true),
        'lite/universal',
      );
    });
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
