import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_experience_library/models/work_entry.dart';
import 'package:work_experience_library/services/local_repository.dart';

void main() {
  late Directory directory;
  late File database;
  late LocalRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('work-library-test-');
    database = File('${directory.path}${Platform.pathSeparator}library.json');
    repository = LocalRepository(databaseFile: database);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  WorkEntry entry(String text, int version) => WorkEntry(
        id: 'entry-1',
        date: '2026-08-23',
        title: '',
        category: 'Work',
        tags: const ['test'],
        content: '',
        items: [text, 'line one\nline two'],
        summary: '',
        favorite: false,
        link: '',
        createdAt: 1,
        updatedAt: version,
        deleted: false,
      );

  LibrarySnapshot snapshot(String text, int version) => LibrarySnapshot(
        entries: [entry(text, version)],
        categories: const ['Work', 'Custom'],
        meta: {'lastSyncAt': version},
      );

  test('snapshot preserves records, multiline items, categories, and meta',
      () async {
    await repository.save(snapshot('current', 10));

    final restored = await repository.load();

    expect(restored.entries.single.contentItems,
        const ['current', 'line one\nline two']);
    expect(restored.categories, const ['Work', 'Custom']);
    expect(restored.meta['lastSyncAt'], 10);
  });

  test('serializes concurrent saves without corrupting the database', () async {
    final writes = <Future<void>>[];
    for (var version = 1; version <= 20; version++) {
      writes.add(repository.save(snapshot('version $version', version)));
    }

    await Future.wait(writes);
    final restored = await repository.load();

    expect(restored.entries.single.contentItems.first, 'version 20');
    expect(restored.meta['lastSyncAt'], 20);
    expect(await File('${database.path}.tmp').exists(), isFalse);
  });
  test('keeps five rotating backups and recovers the newest valid copy',
      () async {
    for (var version = 1; version <= 7; version++) {
      await repository.save(snapshot('version $version', version));
    }

    expect(await File('${database.path}.bak').exists(), isTrue);
    expect(await File('${database.path}.bak.5').exists(), isTrue);

    await database.writeAsString('{broken json', flush: true);
    final recovered = await repository.load();

    expect(recovered.entries.single.contentItems.first, 'version 6');
    expect(await database.readAsString(), contains('version 6'));
    expect(
      directory.listSync().whereType<File>().any(
            (file) => file.path.contains('.broken-'),
          ),
      isTrue,
    );
  });
}
