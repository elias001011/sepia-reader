import 'syncable.dart';

class LibraryFolder implements SyncableRecord {
  const LibraryFolder({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.deletedAt,
  });

  @override
  final String id;
  final String name;
  final String? parentId;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  /// Set when the folder was deleted; kept as a tombstone so the deletion
  /// reaches other devices instead of being undone by their copy.
  @override
  final DateTime? deletedAt;

  LibraryFolder copyWith({
    String? name,
    String? parentId,
    bool moveToRoot = false,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) => LibraryFolder(
    id: id,
    name: name ?? this.name,
    parentId: moveToRoot ? null : parentId ?? this.parentId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt ?? this.deletedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parentId': parentId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
  };

  factory LibraryFolder.fromJson(Map<String, dynamic> json) => LibraryFolder(
    id: json['id'] as String,
    name: json['name'] as String,
    parentId: json['parentId'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    deletedAt: switch (json['deletedAt']) {
      final String value => DateTime.tryParse(value),
      _ => null,
    },
  );
}
