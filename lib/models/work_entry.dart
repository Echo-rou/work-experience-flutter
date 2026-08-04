class WorkEntry {
  WorkEntry({
    required this.id,
    required this.date,
    required this.title,
    required this.category,
    required this.tags,
    required this.content,
    required this.summary,
    required this.favorite,
    required this.link,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
    this.purged = false,
    this.deletedAt,
  });

  final String id;
  final String date;
  final String title;
  final String category;
  final List<String> tags;
  final String content;
  final String summary;
  final bool favorite;
  final String link;
  final int createdAt;
  final int updatedAt;
  final bool deleted;
  final bool purged;
  final int? deletedAt;

  factory WorkEntry.fromJson(Map<String, dynamic> json) => WorkEntry(
        id: json['id']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        tags: (json['tags'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        content: json['content']?.toString() ?? '',
        summary: json['summary']?.toString() ?? '',
        favorite: json['favorite'] == true,
        link: json['link']?.toString() ?? '',
        createdAt: _asInt(json['createdAt']),
        updatedAt: _asInt(json['updatedAt']),
        deleted: json['deleted'] == true,
        purged: json['purged'] == true,
        deletedAt: json['deletedAt'] == null ? null : _asInt(json['deletedAt']),
      );

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'title': title,
        'category': category,
        'tags': tags,
        'content': content,
        'summary': summary,
        'favorite': favorite,
        'link': link,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deleted': deleted,
        if (purged) 'purged': true,
        if (deletedAt != null) 'deletedAt': deletedAt,
      };

  WorkEntry copyWith({
    String? date,
    String? title,
    String? category,
    List<String>? tags,
    String? content,
    String? summary,
    bool? favorite,
    String? link,
    int? updatedAt,
    bool? deleted,
    bool? purged,
    int? deletedAt,
    bool clearDeletedAt = false,
  }) =>
      WorkEntry(
        id: id,
        date: date ?? this.date,
        title: title ?? this.title,
        category: category ?? this.category,
        tags: tags ?? this.tags,
        content: content ?? this.content,
        summary: summary ?? this.summary,
        favorite: favorite ?? this.favorite,
        link: link ?? this.link,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        purged: purged ?? this.purged,
        deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      );
}
