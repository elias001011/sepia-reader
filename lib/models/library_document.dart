class LibraryDocument {
  const LibraryDocument({
    required this.id,
    required this.title,
    required this.content,
    required this.extension,
    required this.createdAt,
    required this.updatedAt,
    this.isFavorite = false,
    this.folderId,
  });
  final String id;
  final String title;
  final String content;
  final String extension;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFavorite;
  final String? folderId;

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
  }) => LibraryDocument(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    extension: extension ?? this.extension,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isFavorite: isFavorite ?? this.isFavorite,
    folderId: moveToRoot ? null : folderId ?? this.folderId,
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
      );
}
