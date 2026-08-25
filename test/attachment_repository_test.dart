import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_experience_library/models/attachment_record.dart';
import 'package:work_experience_library/services/attachment_repository.dart';

void main() {
  late Directory temporaryDirectory;
  late AttachmentRepository repository;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('attachment_db');
    repository = AttachmentRepository(
      databaseFile: File('${temporaryDirectory.path}/attachments.sqlite'),
    );
    await repository.initialize();
  });

  tearDown(() async {
    await repository.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('stores attachment bytes and metadata in SQLite', () async {
    final bytes = Uint8List.fromList('%PDF-1.7 test'.codeUnits);
    final saved = await repository.addFile(
      entryId: 'entry_1',
      name: 'report.pdf',
      bytes: bytes,
    );

    final listed = await repository.listAll(includeDeleted: false);
    final payload = await repository.read(saved.id);

    expect(listed.single.name, 'report.pdf');
    expect(payload!.bytes, bytes);
    expect(payload.record.sha256, hasLength(64));
  });

  test('rejects unsupported and oversized attachments', () async {
    expect(
      () => AttachmentRepository.validateFile('program.exe', 10),
      throwsFormatException,
    );
    expect(
      () => AttachmentRepository.validateFile(
        'large.pdf',
        AttachmentRepository.maxAttachmentBytes + 1,
      ),
      throwsFormatException,
    );
  });

  test('keeps newer versions and deletion tombstones', () async {
    final bytes = Uint8List.fromList('hello'.codeUnits);
    final saved = await repository.addFile(
      entryId: 'entry_2',
      name: 'notes.txt',
      bytes: bytes,
    );
    final older = AttachmentRecord(
      id: saved.id,
      entryId: saved.entryId,
      name: saved.name,
      mimeType: saved.mimeType,
      size: saved.size,
      sha256: saved.sha256,
      createdAt: saved.createdAt,
      updatedAt: saved.updatedAt - 1,
    );

    await repository.upsert(older, bytes);
    await repository.markDeleted(saved.id, saved.updatedAt + 10);

    expect(await repository.read(saved.id), isNull);
    final tombstone = (await repository.listAll()).single;
    expect(tombstone.deleted, isTrue);
    expect(tombstone.deletedAt, saved.updatedAt + 10);
  });
}
