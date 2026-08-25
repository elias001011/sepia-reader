import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/models/library_document.dart';

void main() {
  test('calcula palavras e tempo de leitura', () {
    final now = DateTime(2026);
    final document = LibraryDocument(
      id: '1',
      title: 'Teste',
      content: List.filled(221, 'palavra').join(' '),
      extension: 'md',
      createdAt: now,
      updatedAt: now,
    );

    expect(document.wordCount, 221);
    expect(document.readingMinutes, 2);
    expect(document.isMarkdown, isTrue);
  });

  test('preserva o documento na serialização', () {
    final now = DateTime.utc(2026, 8, 24);
    final original = LibraryDocument(
      id: 'abc',
      title: 'Notas',
      content: '# Olá',
      extension: 'md',
      createdAt: now,
      updatedAt: now,
      isFavorite: true,
    );

    final restored = LibraryDocument.fromJson(original.toJson());
    expect(restored.title, original.title);
    expect(restored.content, original.content);
    expect(restored.isFavorite, isTrue);
  });
}
