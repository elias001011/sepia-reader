import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/models/library_document.dart';
import 'package:sepia_reader/services/document_kind.dart';
import 'package:sepia_reader/widgets/markdown_view.dart';

Uint8List bytes(List<int> values) => Uint8List.fromList(values);

void main() {
  group('documentKindOf', () {
    test('separa prosa, marcação e código', () {
      expect(documentKindOf('md'), DocumentKind.prose);
      expect(documentKindOf('MARKDOWN'), DocumentKind.prose);
      expect(documentKindOf('txt'), DocumentKind.prose);
      expect(documentKindOf('html'), DocumentKind.markup);
      expect(documentKindOf('htm'), DocumentKind.markup);
      expect(documentKindOf('dart'), DocumentKind.code);
      expect(documentKindOf('json'), DocumentKind.code);
    });
  });

  group('isBinaryPayload', () {
    test('reconhece os formatos que a gente não lê', () {
      // .docx / .xlsx / .odt / .epub are all ZIP containers.
      expect(isBinaryPayload(bytes([0x50, 0x4B, 0x03, 0x04, 1, 2, 3])), isTrue);
      expect(isBinaryPayload(bytes([0x25, 0x50, 0x44, 0x46, 45])), isTrue);
      expect(isBinaryPayload(bytes([0x89, 0x50, 0x4E, 0x47, 13])), isTrue);
      expect(isBinaryPayload(bytes([0xFF, 0xD8, 0xFF, 0xE0])), isTrue);
      expect(isBinaryPayload(bytes([0xD0, 0xCF, 0x11, 0xE0])), isTrue);
    });

    test('pega um binário mesmo renomeado para .txt', () {
      final disguised = bytes([
        ...utf8.encode('quase texto '),
        0, 0, 0, 1, 2, 3,
        ...utf8.encode(' mais texto'),
      ]);
      expect(isBinaryPayload(disguised), isTrue);
    });

    test('deixa texto de verdade passar, com acento e emoji', () {
      expect(
        isBinaryPayload(
          Uint8List.fromList(
            utf8.encode('# Capítulo um\n\nEra uma vez… 🌙\n\tcom tab\r\n'),
          ),
        ),
        isFalse,
      );
      expect(isBinaryPayload(bytes([])), isFalse);
    });
  });

  testWidgets('documento de código usa o visualizador, não o leitor de prosa', (
    tester,
  ) async {
    final code = LibraryDocument(
      id: 'c',
      title: 'main',
      content: List.generate(30, (i) => 'final x\$i = $i;').join('\n'),
      extension: 'dart',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: DocumentView(document: code, settings: const AppSettings()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CodeViewer), findsOneWidget);
    // The gutter numbers the source lines.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('documento markdown continua no leitor de prosa', (tester) async {
    final prose = LibraryDocument(
      id: 'p',
      title: 'Fic',
      content: '# Capítulo\n\nTexto.',
      extension: 'md',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: DocumentView(document: prose, settings: const AppSettings()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CodeViewer), findsNothing);
  });
}

