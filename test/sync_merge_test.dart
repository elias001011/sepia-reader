import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/models/library_document.dart';
import 'package:sepia_reader/services/sync_merge.dart';

LibraryDocument doc(
  String id, {
  String title = 'doc',
  String content = '',
  required DateTime updatedAt,
  DateTime? deletedAt,
}) => LibraryDocument(
  id: id,
  title: title,
  content: content,
  extension: 'md',
  createdAt: DateTime(2026),
  updatedAt: updatedAt,
  deletedAt: deletedAt,
);

void main() {
  final t0 = DateTime(2026, 8, 1);
  final t1 = DateTime(2026, 8, 2);
  final t2 = DateTime(2026, 8, 3);

  group('mergeById', () {
    test('the most recently updated copy of a record wins', () {
      final merged = mergeById(
        [doc('a', title: 'local', updatedAt: t2)],
        [doc('a', title: 'remote', updatedAt: t1)],
      );

      expect(merged, hasLength(1));
      expect(merged.single.title, 'local');
    });

    test('takes the remote copy when it is the newer one', () {
      final merged = mergeById(
        [doc('a', title: 'local', updatedAt: t0)],
        [doc('a', title: 'remote', updatedAt: t2)],
      );

      expect(merged.single.title, 'remote');
    });

    test('keeps records that only exist on one side', () {
      final merged = mergeById(
        [doc('local-only', updatedAt: t1)],
        [doc('remote-only', updatedAt: t1)],
      );

      expect(
        merged.map((document) => document.id),
        containsAll(['local-only', 'remote-only']),
      );
      expect(merged, hasLength(2));
    });

    test('a deletion is not undone by an older copy from another device', () {
      final merged = mergeById(
        [doc('a', updatedAt: t2, deletedAt: t2)],
        [doc('a', title: 'still here', updatedAt: t1)],
      );

      expect(merged.single.deletedAt, isNotNull);
      expect(live(merged), isEmpty);
    });

    test('an edit made after a deletion brings the record back', () {
      final merged = mergeById(
        [doc('a', updatedAt: t1, deletedAt: t1)],
        [doc('a', title: 'edited later', updatedAt: t2)],
      );

      expect(merged.single.deletedAt, isNull);
      expect(live(merged).single.title, 'edited later');
    });

    test('a tie resolves to the deletion, so both sides agree', () {
      final asLocal = mergeById(
        [doc('a', updatedAt: t1, deletedAt: t1)],
        [doc('a', updatedAt: t1)],
      );
      final asRemote = mergeById(
        [doc('a', updatedAt: t1)],
        [doc('a', updatedAt: t1, deletedAt: t1)],
      );

      expect(asLocal.single.deletedAt, isNotNull);
      expect(asRemote.single.deletedAt, isNotNull);
    });
  });

  group('purgeExpiredTombstones', () {
    test('drops tombstones past the retention window', () {
      final now = DateTime(2026, 8, 1);
      final expired = now.subtract(tombstoneRetention + const Duration(days: 1));

      final kept = purgeExpiredTombstones([
        doc('gone', updatedAt: expired, deletedAt: expired),
      ], now: now);

      expect(kept, isEmpty);
    });

    test('keeps recent tombstones, so the deletion still propagates', () {
      final now = DateTime(2026, 8, 1);
      final recent = now.subtract(const Duration(days: 1));

      final kept = purgeExpiredTombstones([
        doc('gone', updatedAt: recent, deletedAt: recent),
      ], now: now);

      expect(kept, hasLength(1));
    });

    test('never drops live records, however old', () {
      final now = DateTime(2026, 8, 1);
      final ancient = now.subtract(const Duration(days: 900));

      final kept = purgeExpiredTombstones([
        doc('old', updatedAt: ancient),
      ], now: now);

      expect(kept, hasLength(1));
    });
  });

  test('the offline-then-reconnect case no longer loses work', () {
    // The bug this replaces: a week of local edits was overwritten by the
    // server's older copy the moment syncing was turned back on.
    final server = [
      doc('a', title: 'week-old', updatedAt: t0),
      doc('b', title: 'from another device', updatedAt: t1),
    ];
    final local = [
      doc('a', title: 'a week of edits', updatedAt: t2),
      doc('c', title: 'written while offline', updatedAt: t2),
    ];

    final merged = live(purgeExpiredTombstones(mergeById(local, server)));

    expect(merged, hasLength(3));
    expect(
      merged.firstWhere((document) => document.id == 'a').title,
      'a week of edits',
    );
    expect(
      merged.map((document) => document.id),
      containsAll(['a', 'b', 'c']),
    );
  });
}
