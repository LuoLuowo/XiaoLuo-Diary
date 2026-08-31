import 'dart:convert';

class OutlineNote {
  const OutlineNote({
    required this.id,
    required this.title,
    required this.content,
    this.richContent = '',
    this.level = 0,
    this.tags = const [],
    this.titleColor = '',
  });
  final String id;
  final String title;
  final String content;
  final String richContent;
  final int level;
  final List<String> tags;
  final String titleColor;
  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'richContent': richContent,
    'level': level,
    'tags': tags,
    'titleColor': titleColor,
  };
  factory OutlineNote.fromMap(Map<String, Object?> map) => OutlineNote(
    id: map['id'] as String,
    title: map['title'] as String? ?? '',
    content: map['content'] as String? ?? '',
    richContent: map['richContent'] as String? ?? '',
    level: map['level'] as int? ?? 0,
    tags: List<String>.from(map['tags'] as List? ?? const []),
    titleColor: map['titleColor'] as String? ?? '',
  );
}

class ReadingBook {
  const ReadingBook({
    this.id,
    required this.title,
    required this.author,
    required this.coverPath,
    required this.notes,
    this.review = '',
    required this.createdAt,
    required this.updatedAt,
  });
  final int? id;
  final String title;
  final String author;
  final String coverPath;
  final List<OutlineNote> notes;
  final String review;
  final DateTime createdAt;
  final DateTime updatedAt;
  ReadingBook copyWith({
    int? id,
    String? title,
    String? author,
    String? coverPath,
    List<OutlineNote>? notes,
    String? review,
    DateTime? updatedAt,
  }) => ReadingBook(
    id: id ?? this.id,
    title: title ?? this.title,
    author: author ?? this.author,
    coverPath: coverPath ?? this.coverPath,
    notes: notes ?? this.notes,
    review: review ?? this.review,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'title': title,
    'author': author,
    'cover_path': coverPath,
    'notes': jsonEncode(notes.map((e) => e.toMap()).toList()),
    'review': review,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };
  factory ReadingBook.fromMap(Map<String, Object?> map) => ReadingBook(
    id: map['id'] as int,
    title: map['title'] as String,
    author: map['author'] as String? ?? '',
    coverPath: map['cover_path'] as String? ?? '',
    notes: (jsonDecode(map['notes'] as String? ?? '[]') as List)
        .map((e) => OutlineNote.fromMap(Map<String, Object?>.from(e as Map)))
        .toList(),
    review: map['review'] as String? ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
  );
}
