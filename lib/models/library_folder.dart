class LibraryFolder {
  const LibraryFolder({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
  });

  final String id;
  final String name;
  final String? parentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  LibraryFolder copyWith({
    String? name,
    String? parentId,
    bool moveToRoot = false,
    DateTime? updatedAt,
  }) => LibraryFolder(
    id: id,
    name: name ?? this.name,
    parentId: moveToRoot ? null : parentId ?? this.parentId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parentId': parentId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory LibraryFolder.fromJson(Map<String, dynamic> json) => LibraryFolder(
    id: json['id'] as String,
    name: json['name'] as String,
    parentId: json['parentId'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}
