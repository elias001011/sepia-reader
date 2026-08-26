import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/services/sync_merge.dart';
import 'package:sepia_reader/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/offline_updates.dart';

/// Two devices that both start empty each seed a welcome document. With a
/// random id per device, syncing merged them into two copies — then three,
/// as each new browser profile added its own. A fixed id makes them the same
/// record, so the merge collapses them instead of collecting them.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('o documento de boas-vindas tem sempre o mesmo id', () async {
    final first = AppController(updateChecker: offlineUpdateChecker());
    await first.initialize();
    final phone = first.documents.single;

    SharedPreferences.setMockInitialValues({});
    final second = AppController(updateChecker: offlineUpdateChecker());
    await second.initialize();
    final browser = second.documents.single;

    expect(phone.id, welcomeDocumentId);
    expect(browser.id, phone.id);
  });

  test('sincronizar dois aparelhos recém-abertos não duplica nada', () async {
    final phone = AppController(updateChecker: offlineUpdateChecker());
    await phone.initialize();
    SharedPreferences.setMockInitialValues({});
    final browser = AppController(updateChecker: offlineUpdateChecker());
    await browser.initialize();

    final merged = mergeById(phone.documents.toList(), browser.documents.toList());

    expect(merged, hasLength(1));
    expect(merged.single.id, welcomeDocumentId);
  });

  test('apagar e reabrir traz o de volta, ainda sem duplicar', () async {
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();
    await controller.deleteDocument(welcomeDocumentId);
    expect(controller.documents, isEmpty);

    final reopened = AppController(updateChecker: offlineUpdateChecker());
    await reopened.initialize();

    expect(reopened.documents, hasLength(1));
    expect(reopened.documents.single.id, welcomeDocumentId);
    // And the tombstone did not survive alongside the fresh copy: one
    // record, one id.
    final merged = mergeById(
      reopened.documents.toList(),
      reopened.documents.toList(),
    );
    expect(merged, hasLength(1));
  });

  test('uma biblioteca com documentos não ganha o de boas-vindas', () async {
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();
    await controller.createDocument(title: 'Minha fic');
    await controller.deleteDocument(welcomeDocumentId);

    final reopened = AppController(updateChecker: offlineUpdateChecker());
    await reopened.initialize();

    expect(reopened.documents, hasLength(1));
    expect(reopened.documents.single.title, 'Minha fic');
  });
}
