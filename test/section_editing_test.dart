import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sepia_reader/app.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/services/document_sections.dart';
import 'package:sepia_reader/state/app_controller.dart';

import 'support/offline_updates.dart';

String hugeWithChapters() {
  final buffer = StringBuffer();
  for (var chapter = 1; chapter <= 12; chapter++) {
    buffer.writeln('# Capítulo $chapter');
    buffer.writeln();
    for (var p = 0; p < 40; p++) {
      buffer.writeln(
        'Parágrafo $p do capítulo $chapter, com bastante texto para dar corpo.',
      );
      buffer.writeln();
    }
  }
  return buffer.toString();
}

void main() {
  group('editableSectionsOf', () {
    test('as fatias cobrem o texto inteiro, sem buraco nem sobreposição', () {
      final content = hugeWithChapters();
      final sections = editableSectionsOf(content);
      expect(sections.length, greaterThan(1));
      expect(sections.first.start, 0);
      expect(sections.last.end, content.length);
      final rebuilt = StringBuffer();
      for (var i = 0; i < sections.length; i++) {
        if (i > 0) expect(sections[i].start, sections[i - 1].end);
        rebuilt.write(content.substring(sections[i].start, sections[i].end));
      }
      expect(rebuilt.toString(), content);
    });

    test('usa os títulos do documento quando existem', () {
      final sections = editableSectionsOf(hugeWithChapters());
      expect(sections.map((s) => s.title).toList(), [
        for (var i = 1; i <= 12; i++) 'Capítulo $i',
      ]);
    });

    test('sem títulos, corta em linha em branco e nunca no meio de um parágrafo', () {
      final content = List.generate(
        400,
        (i) => 'Parágrafo $i com um punhado de palavras para dar corpo ao texto.',
      ).join('\n\n');
      final sections = editableSectionsOf(content);
      expect(sections.length, greaterThan(1));
      for (final section in sections.take(sections.length - 1)) {
        expect(
          content.substring(section.end - 2, section.end),
          '\n\n',
          reason: 'a slice must end on a paragraph boundary',
        );
      }
      final rebuilt = sections
          .map((s) => content.substring(s.start, s.end))
          .join();
      expect(rebuilt, content);
    });

    test('documento pequeno não é fatiado', () {
      expect('texto curto'.length, lessThan(sectionedEditingThreshold));
      final sections = editableSectionsOf('texto curto');
      expect(sections, hasLength(1));
    });
  });

  testWidgets(
    'editar uma parte de um documento gigante preserva o resto',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'sepia.settings.v1': jsonEncode(
          const AppSettings(localeCode: 'pt_BR').toJson(),
        ),
      });
      final controller = AppController(updateChecker: offlineUpdateChecker());
      await controller.initialize();
      final content = hugeWithChapters();
      final document = await controller.createDocument(
        title: 'Fic gigante',
        content: content,
      );

      await tester.pumpWidget(SepiaApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Fic gigante.md'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fic gigante.md'));
      await tester.pumpAndSettle();

      // The editor sliced it, and the field holds only the first chapter.
      expect(find.text('Capítulo 1'), findsWidgets);
      final editor = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.expands,
      );
      final inField = tester.widget<TextField>(editor).controller!.text;
      expect(inField.length, lessThan(content.length));
      expect(inField, startsWith('# Capítulo 1'));
      expect(inField, isNot(contains('# Capítulo 2')));

      // Type into it and let the debounced save land.
      await tester.enterText(editor, '# Capítulo 1\n\nTexto novo do capítulo.\n\n');
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      final stored = controller.documentById(document.id)!.content;
      expect(stored, contains('Texto novo do capítulo.'));
      // Everything after the edited slice survived untouched.
      for (var chapter = 2; chapter <= 12; chapter++) {
        expect(stored, contains('# Capítulo $chapter'));
        expect(stored, contains('Parágrafo 39 do capítulo $chapter,'));
      }
      expect(stored, isNot(contains('do capítulo 1, com bastante')));

      // Moving to another part loads that part, and still keeps the whole.
      await tester.tap(find.byTooltip('Próxima parte'));
      await tester.pumpAndSettle();
      final second = tester.widget<TextField>(editor).controller!.text;
      expect(second, startsWith('# Capítulo 2'));
      expect(controller.documentById(document.id)!.content, contains('# Capítulo 12'));
    },
  );
}
