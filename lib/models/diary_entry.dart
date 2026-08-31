import 'dart:convert';

class DiaryEntry {
  const DiaryEntry({
    this.id,
    required this.title,
    required this.content,
    this.richContent = '',
    required this.diaryDate,
    required this.createdAt,
    required this.updatedAt,
    required this.category,
    required this.tags,
    required this.images,
    this.videos = const [],
    required this.attachments,
  });
  final int? id;
  final String title;
  final String content;
  final String richContent;
  final DateTime diaryDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String category;
  final List<String> tags;
  final List<String> images;
  final List<String> videos;
  final List<String> attachments;
  String get displayTitle => title.trim();
  String get displayContent => content
      .replaceAll('\uFFFC', '')
      .replaceAll(RegExp(r'\bOBJ\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  DiaryEntry copyWith({
    int? id,
    String? title,
    String? content,
    String? richContent,
    DateTime? diaryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? category,
    List<String>? tags,
    List<String>? images,
    List<String>? videos,
    List<String>? attachments,
  }) => DiaryEntry(
    id: id ?? this.id,
    title: title ?? this.title,
    content: content ?? this.content,
    richContent: richContent ?? this.richContent,
    diaryDate: diaryDate ?? this.diaryDate,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    category: category ?? this.category,
    tags: tags ?? this.tags,
    images: images ?? this.images,
    videos: videos ?? this.videos,
    attachments: attachments ?? this.attachments,
  );
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'title': title,
    'content': content,
    'rich_content': richContent,
    'diary_date': diaryDate.millisecondsSinceEpoch,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'category': category,
    'tags': jsonEncode(tags),
    'images': jsonEncode(images),
    'videos': jsonEncode(videos),
    'attachments': jsonEncode(attachments),
  };
  factory DiaryEntry.fromMap(Map<String, Object?> map) => DiaryEntry(
    id: map['id'] as int,
    title: map['title'] as String? ?? '',
    content: map['content'] as String? ?? '',
    richContent: map['rich_content'] as String? ?? '',
    diaryDate: DateTime.fromMillisecondsSinceEpoch(map['diary_date'] as int),
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    category: map['category'] as String? ?? '生活',
    tags: List<String>.from(jsonDecode(map['tags'] as String? ?? '[]')),
    images: List<String>.from(jsonDecode(map['images'] as String? ?? '[]')),
    videos: List<String>.from(jsonDecode(map['videos'] as String? ?? '[]')),
    attachments: List<String>.from(
      jsonDecode(map['attachments'] as String? ?? '[]'),
    ),
  );
}

class TrashedDiary {
  const TrashedDiary({required this.diary, required this.deletedAt});
  final DiaryEntry diary;
  final DateTime deletedAt;
}
