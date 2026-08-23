import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/work_entry.dart';

class LibrarySnapshot {
  LibrarySnapshot({
    required this.entries,
    required this.categories,
    required this.meta,
  });

  final List<WorkEntry> entries;
  final List<String> categories;
  final Map<String, dynamic> meta;
}

class LocalRepository {
  File? _file;

  Future<File> get _database async {
    if (_file != null) return _file!;
    final directory = await getApplicationSupportDirectory();
    final dataDirectory = Directory(
        '${directory.path}${Platform.pathSeparator}work_experience_library');
    await dataDirectory.create(recursive: true);
    _file = File('${dataDirectory.path}${Platform.pathSeparator}library.json');
    return _file!;
  }

  Future<LibrarySnapshot> load() async {
    final file = await _database;
    if (!await file.exists()) {
      return LibrarySnapshot(
          entries: [], categories: defaultCategories, meta: {});
    }
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid data file format');
      }
      final entrySource = raw['entries'];
      final entryValues = entrySource is Map
          ? entrySource.values
          : entrySource is List
              ? entrySource
              : const [];
      final entries = entryValues
          .whereType<Map>()
          .map((e) => WorkEntry.fromJson(Map<String, dynamic>.from(e)))
          .where((e) =>
              e.id.isNotEmpty &&
              (e.title.isNotEmpty ||
                  e.summary.isNotEmpty ||
                  e.content.isNotEmpty))
          .toList();
      final categorySource = raw['categories'];
      final categories = categorySource is Map
          ? categorySource.values
              .whereType<Map>()
              .map((e) => e['name']?.toString() ?? '')
              .where((e) => e.isNotEmpty)
              .toList()
          : (categorySource as List? ?? const [])
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList();
      return LibrarySnapshot(
        entries: entries,
        categories: categories.isEmpty ? defaultCategories : categories,
        meta: Map<String, dynamic>.from(
            raw['meta'] is Map ? raw['meta'] as Map : const {}),
      );
    } catch (_) {
      final broken =
          File('${file.path}.broken-${DateTime.now().millisecondsSinceEpoch}');
      await file.copy(broken.path);
      rethrow;
    }
  }

  Future<void> save(LibrarySnapshot snapshot) async {
    final file = await _database;
    final temp = File('${file.path}.tmp');
    final payload = {
      'schemaVersion': 1,
      'entries': {
        for (final entry in snapshot.entries) entry.id: entry.toJson()
      },
      'categories': {
        for (final category in snapshot.categories)
          category: {
            'name': category,
            'createdAt': snapshot.meta['categoryCreatedAt.$category'] ?? 0
          },
      },
      'meta': snapshot.meta,
    };
    await temp.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
        flush: true);
    if (await file.exists()) {
      final backup = File('${file.path}.bak');
      await file.copy(backup.path);
    }
    await temp.rename(file.path);
  }

  static const List<String> defaultCategories = [
    'Work',
    'Learning',
    'Life',
    'Ideas',
    'Reading'
  ];
}
