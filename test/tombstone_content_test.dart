import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/models/library_document.dart';
import 'package:sepia_reader/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/offline_updates.dart';

LibraryDocument doc({DateTime? deletedAt, String content = 'texto longo'}) =>
    LibraryDocument(
      id: 'd',
      title: 'Fic',
      content: content,
      extension: 'md',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      deletedAt: deletedAt,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('um tombstone não leva o texto junto', () {
    expect(doc().toJson()['content'], 'texto longo');
    expect(
      doc(deletedAt: DateTime(2026)).toJson()['content'],
      '',
      reason: 'apagar tem que apagar o conteúdo do servidor, não só marcar',
    );
  });

  test('um tombstone antigo com texto é limpo ao ser reescrito', () {
    // A record tombstoned by a build that predates the rule, read back in.
    final legacy = LibraryDocument.fromJson({
      'id': 'x',
      'title': 'Antigo',
      'content': 'a' * 164641,
      'extension': 'md',
      'createdAt': '2026-08-01T00:00:00.000',
      'updatedAt': '2026-08-01T00:00:00.000',
      'deletedAt': '2026-08-02T00:00:00.000',
    });
    expect(legacy.content, isNotEmpty, reason: 'lido como veio');
    expect(legacy.toJson()['content'], '', reason: 'e escrito já limpo');
  });

  test('apagar um documento deixa só a marca, sem o corpo', () async {
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();
    final created = await controller.createDocument(
      title: 'Fic',
      content: 'a' * 5000,
    );

    await controller.deleteDocument(created.id);

    final stored = SharedPreferences.getInstance();
    final prefs = await stored;
    final raw = prefs.getString('sepia.documents.v1')!;
    expect(raw, contains(created.id));
    expect(
      raw.contains('a' * 200),
      isFalse,
      reason: 'o corpo do documento apagado continuou no payload',
    );
  });
}
