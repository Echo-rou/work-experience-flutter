class WorkEntry {
  WorkEntry({
    required this.id,
    required this.date,
    required this.title,
    required this.category,
    required this.tags,
    required this.content,
    this.items = const [],
    required this.summary,
    required this.favorite,
    required this.link,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
    this.kind = 'record',
    this.completed = false,
    this.purged = false,
    this.deletedAt,
  });

  final String id;
  final String date;
  final String title;
  final String category;
  final List<String> tags;
  final String content;
  final List<String> items;
  final String summary;
  final bool favorite;
  final String link;
  final int createdAt;
  final int updatedAt;
  final bool deleted;
  final String kind;
  final bool completed;
  final bool purged;
  final int? deletedAt;

  bool get isTodo => kind == 'todo';

  /// New records store explicit items so line breaks inside an item survive.
  /// Legacy summary/content fields are still read for backward compatibility.
  List<String> get contentItems {
    final explicitItems = items.map((e) => e.trim()).where((e) => e.isNotEmpty);
    if (explicitItems.isNotEmpty) return explicitItems.toList();
    final values = <String>[];
    final oldSummary = summary.trim();
    if (oldSummary.isNotEmpty) values.add(oldSummary);
    for (final line in content.split(RegExp(r'\r?\n'))) {
      final value = line.trim();
      if (value.isNotEmpty && !values.contains(value)) values.add(value);
    }
    if (values.isEmpty && title.trim().isNotEmpty) values.add(title.trim());
    return values;
  }

  String get displayText {
    final items = contentItems;
    return items.isEmpty ? 'Empty item' : _plainText(items.first);
  }

  String get combinedText => contentItems.map(_plainText).join(' · ');

  String timelinePreview() {
    final text = combinedText;
    if (text.length <= 80) return text;
    final length = (text.length * .1).ceil().clamp(40, 120);
    return '${text.substring(0, length)}…';
  }

  static String _plainText(String value) => value
      .replaceFirst(RegExp(r'^\s*(?:[-*>#]+|\d+[.)])\s*'), '')
      .replaceAll(RegExp(r'[`*_]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  factory WorkEntry.fromJson(Map<String, dynamic> json) => WorkEntry(
        id: json['id']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        tags: (json['tags'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        content: json['content']?.toString() ?? '',
        items: (json['items'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        summary: json['summary']?.toString() ?? '',
        favorite: json['favorite'] == true,
        link: json['link']?.toString() ?? '',
        createdAt: _asInt(json['createdAt']),
        updatedAt: _asInt(json['updatedAt']),
        deleted: json['deleted'] == true,
        kind: json['kind']?.toString() ?? 'record',
        completed: json['completed'] == true,
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
        if (items.isNotEmpty) 'items': items,
        'summary': summary,
        'favorite': favorite,
        'link': link,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deleted': deleted,
        if (kind != 'record') 'kind': kind,
        if (completed) 'completed': true,
        if (purged) 'purged': true,
        if (deletedAt != null) 'deletedAt': deletedAt,
      };

  WorkEntry copyWith({
    String? date,
    String? title,
    String? category,
    List<String>? tags,
    String? content,
    List<String>? items,
    String? summary,
    bool? favorite,
    String? link,
    int? updatedAt,
    bool? deleted,
    String? kind,
    bool? completed,
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
        items: items ?? this.items,
        summary: summary ?? this.summary,
        favorite: favorite ?? this.favorite,
        link: link ?? this.link,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        kind: kind ?? this.kind,
        completed: completed ?? this.completed,
        purged: purged ?? this.purged,
        deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      );
}
