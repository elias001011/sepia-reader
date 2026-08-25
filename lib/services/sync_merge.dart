import '../models/syncable.dart';

/// How long a tombstone is kept before it is dropped for good.
///
/// A tombstone has to outlive the longest plausible offline stretch of any
/// device: purge it too early and a device that was away longer than this
/// still holds the original record, which then resurrects on its next merge.
const Duration tombstoneRetention = Duration(days: 30);

/// Merges two copies of a collection, record by record.
///
/// The newest [SyncableRecord.updatedAt] wins for each id, so devices that
/// edited different records both keep their work — unlike replacing the whole
/// collection with whichever copy was fetched last. Ties resolve in favour of
/// a tombstone, which keeps the outcome deterministic on both sides of a sync
/// when two devices report the same timestamp.
List<T> mergeById<T extends SyncableRecord>(
  Iterable<T> local,
  Iterable<T> remote,
) {
  final byId = <String, T>{};
  for (final record in [...local, ...remote]) {
    final current = byId[record.id];
    if (current == null || _wins(record, current)) byId[record.id] = record;
  }
  return byId.values.toList(growable: false);
}

bool _wins(SyncableRecord candidate, SyncableRecord current) {
  final comparison = candidate.updatedAt.compareTo(current.updatedAt);
  if (comparison != 0) return comparison > 0;
  return candidate.isDeleted && !current.isDeleted;
}

/// Drops tombstones older than [tombstoneRetention] so the payload does not
/// grow without bound.
List<T> purgeExpiredTombstones<T extends SyncableRecord>(
  Iterable<T> records, {
  DateTime? now,
}) {
  final cutoff = (now ?? DateTime.now()).subtract(tombstoneRetention);
  return records
      .where((record) {
        final deletedAt = record.deletedAt;
        return deletedAt == null || deletedAt.isAfter(cutoff);
      })
      .toList(growable: false);
}

/// The records a user should actually see: everything that is not a tombstone.
List<T> live<T extends SyncableRecord>(Iterable<T> records) =>
    records.where((record) => !record.isDeleted).toList(growable: false);
