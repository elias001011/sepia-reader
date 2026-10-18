import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/models/library_document.dart';
import 'package:sepia_reader/models/library_folder.dart';
import 'package:sepia_reader/services/library_index.dart';
import 'package:sepia_reader/services/json_work.dart';
import 'package:sepia_reader/services/sync_merge.dart';
import 'package:sepia_reader/services/storage_service.dart';
import 'package:sepia_reader/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/offline_updates.dart';

LibraryDocument document(String id, {DateTime? stamp, String content = ''}) =>
    LibraryDocument(
      id: id,
      title: id,
      content: content,
      extension: 'md',
      folderId: 'f999',
      createdAt: DateTime.utc(2026),
      updatedAt: stamp ?? DateTime.utc(2026),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('index counts a deep library without walking every ancestor for each document', () {
    final folders = List.generate(
      1000,
      (i) => LibraryFolder(
        id: 'f$i',
        name: '$i',
        parentId: i == 0 ? null : 'f${i - 1}',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    final docs = List.generate(10000, (i) => document('$i'));
    final watch = Stopwatch()..start();
    final index = LibraryIndex(docs, folders);
    watch.stop();
    expect(index.folderDocumentCounts['f0'], 10000);
    expect(index.folderDocumentCounts['f999'], 10000);
    expect(index.documentsByFolder['f999'], hasLength(10000));
    // Diagnostic timing, not a flaky hardware-dependent assertion.
    // ignore: avoid_print
    print(
      'Index: 10000 documents / 1000 nested folders: ${watch.elapsedMicroseconds} us',
    );
  });
  test('revision comparison ignores order and detects deletion and later revisions', () {
    final a = document('a');
    final b = document('b');
    expect(sameRecordVersions([a, b], [b, a]), isTrue);
    expect(
      sameRecordVersions(
        [a],
        [a.copyWith(content: 'edit', updatedAt: DateTime.utc(2027))],
      ),
      isFalse,
    );
    expect(
      sameRecordVersions([a], [a.copyWith(deletedAt: DateTime.utc(2026))]),
      isFalse,
    );
  });
  test('large JSON round trips escapes, Unicode and empty metadata', () async {
    final content = '${'á\\\n"🙂' * 50000}end';
    final value = {'content': content};
    expect(await decodeStoredJson(await encodeStoredJson(value)), value);
    expect(jsonDecode((await encodeJsonRecords([value])).single), value);
  });
  test('large asynchronous snapshots preserve save order and cached list invalidation', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final first = document(
      'a',
      stamp: DateTime.utc(2099),
      content: 'large ' * 60000,
    );
    final second = first.copyWith(
      content: 'latest',
      updatedAt: DateTime.utc(2099, 1, 2),
    );
    await Future.wait([
      storage.saveDocumentsLocally([first]),
      storage.saveDocumentsLocally([second]),
    ]);
    expect((await storage.loadLocalDocuments()).single.content, 'latest');
    final controller = AppController(
      storage: storage,
      updateChecker: offlineUpdateChecker(),
    );
    await controller.initialize();
    final snapshot = controller.documents;
    expect(identical(snapshot, controller.documents), isTrue);
    await controller.toggleFavorite('a');
    expect(identical(snapshot, controller.documents), isFalse);
    expect(controller.documents.single.isFavorite, isTrue);
    expect(
      controller.documents.single.updatedAt.isAfter(second.updatedAt),
      isTrue,
    );
    await storage.waitForPendingSync();
  });
}
