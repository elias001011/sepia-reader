class ReadingBookmark {
  const ReadingBookmark({
    required this.id,
    required this.documentId,
    required this.scrollFraction,
    required this.excerpt,
    required this.createdAt,
  });

  final String id;
  final String documentId;
  final double scrollFraction;
  final String excerpt;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'documentId': documentId,
    'scrollFraction': scrollFraction,
    'excerpt': excerpt,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ReadingBookmark.fromJson(Map<String, dynamic> json) =>
      ReadingBookmark(
        id: json['id'] as String,
        documentId: json['documentId'] as String,
        scrollFraction: (json['scrollFraction'] as num).toDouble(),
        excerpt: json['excerpt'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
