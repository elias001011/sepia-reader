/// A record that can be merged across devices.
///
/// Every synced collection is reconciled per record rather than by replacing
/// the whole payload, so two devices that edited different items both keep
/// their work. [updatedAt] is the merge clock and [deletedAt] marks a
/// tombstone: a deletion has to travel as a record of its own, otherwise an
/// item deleted on one device simply reappears from another device's copy.
abstract interface class SyncableRecord {
  String get id;
  DateTime get updatedAt;
  DateTime? get deletedAt;
}

extension SyncableRecordX on SyncableRecord {
  bool get isDeleted => deletedAt != null;
}
