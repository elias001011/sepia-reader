import 'syncable.dart';

class LibraryDocument implements SyncableRecord {
  const LibraryDocument({
    required this.id,
    required this.title,
    required this.content,
    required this.extension,
    required this.createdAt,
    required this.updatedAt,
    this.isFavorite = false,
    this.folderId,
    this.deletedAt,
  });
  @override
  final String id;
  final String title;
  final String content;
  final String extension;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isFavorite;
  final String? folderId;

  /// Set when the document was deleted; the record is kept around as a
  /// tombstone so the deletion can reach other devices.
  @override
  final DateTime? deletedAt;

  bool get isMarkdown => extension == 'md' || extension == 'markdown';
  int get wordCount =>
      content.trim().isEmpty ? 0 : content.trim().split(RegExp(r'\s+')).length;
  int get readingMinutes => wordCount == 0 ? 0 : (wordCount / 220).ceil();

  LibraryDocument copyWith({
    String? title,
    String? content,
    String? extension,
    DateTime? updatedAt,
    bool? isFavorite,
    String? folderId,
    bool moveToRoot = false,
    DateTime? deletedAt,
  }) => LibraryDocument(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    extension: extension ?? this.extension,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isFavorite: isFavorite ?? this.isFavorite,
    folderId: moveToRoot ? null : folderId ?? this.folderId,
    deletedAt: deletedAt ?? this.deletedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'extension': extension,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isFavorite': isFavorite,
    'folderId': folderId,
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
  };

  factory LibraryDocument.fromJson(Map<String, dynamic> json) =>
      LibraryDocument(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        extension: (json['extension'] as String? ?? 'md').toLowerCase(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        isFavorite: json['isFavorite'] as bool? ?? false,
        folderId: json['folderId'] as String?,
        deletedAt: switch (json['deletedAt']) {
          final String value => DateTime.tryParse(value),
          _ => null,
        },
      );
}
