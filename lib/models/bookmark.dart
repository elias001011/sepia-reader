import 'syncable.dart';

class ReadingBookmark implements SyncableRecord {
  const ReadingBookmark({
    required this.id,
    required this.documentId,
    required this.scrollFraction,
    required this.excerpt,
    required this.createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  @override
  final String id;
  final String documentId;
  final double scrollFraction;
  final String excerpt;
  final DateTime createdAt;

  /// Bookmarks are not edited in place, so before tombstones existed they
  /// only carried [createdAt]. Falling back to it keeps records written by
  /// older versions mergeable without a migration.
  @override
  final DateTime updatedAt;

  /// Set when the bookmark was removed; kept as a tombstone so the removal
  /// reaches other devices.
  @override
  final DateTime? deletedAt;

  ReadingBookmark copyWith({DateTime? updatedAt, DateTime? deletedAt}) =>
      ReadingBookmark(
        id: id,
        documentId: documentId,
        scrollFraction: scrollFraction,
        excerpt: excerpt,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'documentId': documentId,
    'scrollFraction': scrollFraction,
    'excerpt': excerpt,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
  };

  factory ReadingBookmark.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['createdAt'] as String);
    return ReadingBookmark(
      id: json['id'] as String,
      documentId: json['documentId'] as String,
      scrollFraction: (json['scrollFraction'] as num).toDouble(),
      excerpt: json['excerpt'] as String,
      createdAt: createdAt,
      updatedAt: switch (json['updatedAt']) {
        final String value => DateTime.tryParse(value) ?? createdAt,
        _ => createdAt,
      },
      deletedAt: switch (json['deletedAt']) {
        final String value => DateTime.tryParse(value),
        _ => null,
      },
    );
  }
}
