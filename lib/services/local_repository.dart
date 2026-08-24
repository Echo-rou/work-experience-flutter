import 'dart:async';
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
  LocalRepository({File? databaseFile}) : _file = databaseFile;

  static const backupCount = 5;

  File? _file;
  Future<void> _saveQueue = Future<void>.value();

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
      return await _readSnapshot(file);
    } catch (_) {
      final broken =
          File('${file.path}.broken-${DateTime.now().millisecondsSinceEpoch}');
      await file.copy(broken.path);
      for (final backup in _backupFiles(file)) {
        if (!await backup.exists()) continue;
        try {
          final recovered = await _readSnapshot(backup);
          await backup.copy(file.path);
          return recovered;
        } catch (_) {
          // Try the next older backup.
        }
      }
      rethrow;
    }
  }

  Future<void> save(LibrarySnapshot snapshot) {
    // Encode immediately so a queued save cannot observe collections that were
    // mutated by a later UI or LAN operation.
    final encoded = const JsonEncoder.withIndent('  ').convert({
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
    });
    final result = Completer<void>();
    _saveQueue = _saveQueue.then((_) async {
      try {
        await _saveEncoded(encoded);
        result.complete();
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<void> _saveEncoded(String encoded) async {
    final file = await _database;
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(encoded, flush: true);
    if (await file.exists()) {
      await _rotateBackups(file);
    }
    await temp.rename(file.path);
  }

  Future<LibrarySnapshot> _readSnapshot(File source) async {
    final decoded = jsonDecode(await source.readAsString());
    if (decoded is! Map) {
      throw const FormatException('Invalid data file format');
    }
    final raw = Map<String, dynamic>.from(decoded);
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
            (e.items.any((item) => item.trim().isNotEmpty) ||
                e.title.isNotEmpty ||
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
  }

  List<File> _backupFiles(File file) => [
        File('${file.path}.bak'),
        for (var i = 2; i <= backupCount; i++) File('${file.path}.bak.$i'),
      ];

  Future<void> _rotateBackups(File file) async {
    final backups = _backupFiles(file);
    if (await backups.last.exists()) await backups.last.delete();
    for (var i = backups.length - 2; i >= 0; i--) {
      if (await backups[i].exists()) {
        await backups[i].rename(backups[i + 1].path);
      }
    }
    await file.copy(backups.first.path);
  }

  static const List<String> defaultCategories = [
    'Work',
    'Learning',
    'Life',
    'Ideas',
    'Reading'
  ];
}
