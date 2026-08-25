import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../models/attachment_record.dart';

class AttachmentRepository {
  AttachmentRepository({File? databaseFile}) : _databaseFile = databaseFile;

  static const int maxAttachmentBytes = 25 * 1024 * 1024;
  static const int maxAttachmentsPerEntry = 10;
  static const allowedExtensions = <String>{
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'heic',
  };

  final File? _databaseFile;
  final _uuid = const Uuid();
  Database? _database;
  Future<void> _queue = Future<void>.value();

  Future<void> initialize() async {
    if (_database != null) return;
    final file = _databaseFile ?? await _defaultDatabaseFile();
    await file.parent.create(recursive: true);
    final db = sqlite3.open(file.path);
    db.execute('PRAGMA journal_mode=WAL');
    db.execute('PRAGMA synchronous=FULL');
    db.execute('''
      CREATE TABLE IF NOT EXISTS attachments (
        id TEXT PRIMARY KEY,
        entry_id TEXT NOT NULL,
        name TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        size INTEGER NOT NULL,
        sha256 TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        data BLOB
      )
    ''');
    db.execute(
        'CREATE INDEX IF NOT EXISTS attachments_entry_id ON attachments(entry_id)');
    db.execute(
        'CREATE INDEX IF NOT EXISTS attachments_updated_at ON attachments(updated_at)');
    _database = db;
  }

  Future<void> close() async {
    await _serialized(() async {
      _database?.close();
      _database = null;
    });
  }

  Future<List<AttachmentRecord>> listAll({bool includeDeleted = true}) async {
    await initialize();
    final rows = _database!.select('''
      SELECT id, entry_id, name, mime_type, size, sha256, created_at,
             updated_at, deleted, deleted_at
      FROM attachments ${includeDeleted ? '' : 'WHERE deleted = 0'}
      ORDER BY created_at ASC
    ''');
    return rows.map(_fromRow).toList();
  }

  Future<AttachmentPayload?> read(String id) async {
    await initialize();
    final rows = _database!.select(
      '''SELECT id, entry_id, name, mime_type, size, sha256, created_at,
                updated_at, deleted, deleted_at, data
         FROM attachments WHERE id = ? LIMIT 1''',
      [id],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    if (row['deleted'] == 1 || row['data'] == null) return null;
    return AttachmentPayload(
      _fromRow(row),
      Uint8List.fromList((row['data'] as List).cast<int>()),
    );
  }

  Future<AttachmentRecord> addFile({
    required String entryId,
    required String name,
    required Uint8List bytes,
  }) async {
    final cleanName = validateFile(name, bytes.length);
    final now = DateTime.now().millisecondsSinceEpoch;
    final record = AttachmentRecord(
      id: _uuid.v4(),
      entryId: entryId,
      name: cleanName,
      mimeType: mimeTypeFor(cleanName),
      size: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      createdAt: now,
      updatedAt: now,
    );
    await upsert(record, bytes);
    return record;
  }

  Future<void> upsert(AttachmentRecord record, Uint8List? bytes) async {
    _validateRecord(record, bytes);
    await _serialized(() async {
      await initialize();
      final current = _selectMetadata(record.id);
      if (current != null && current.version >= record.version) return;
      _database!.execute('''
        INSERT INTO attachments
          (id, entry_id, name, mime_type, size, sha256, created_at,
           updated_at, deleted, deleted_at, data)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          entry_id=excluded.entry_id, name=excluded.name,
          mime_type=excluded.mime_type, size=excluded.size,
          sha256=excluded.sha256, created_at=excluded.created_at,
          updated_at=excluded.updated_at, deleted=excluded.deleted,
          deleted_at=excluded.deleted_at, data=excluded.data
      ''', [
        record.id,
        record.entryId,
        record.name,
        record.mimeType,
        record.size,
        record.sha256,
        record.createdAt,
        record.updatedAt,
        record.deleted ? 1 : 0,
        record.deletedAt,
        record.deleted ? null : bytes,
      ]);
    });
  }

  Future<void> markDeleted(String id, int updatedAt) async {
    await _serialized(() async {
      await initialize();
      final current = _selectMetadata(id);
      if (current == null || current.version >= updatedAt) return;
      _database!.execute('''
        UPDATE attachments SET deleted = 1, deleted_at = ?, updated_at = ?,
          data = NULL WHERE id = ?
      ''', [updatedAt, updatedAt, id]);
    });
  }

  Future<void> deleteForEntry(String entryId, int updatedAt) async {
    await _serialized(() async {
      await initialize();
      _database!.execute('''
        UPDATE attachments SET deleted = 1, deleted_at = ?, updated_at = ?,
          data = NULL
        WHERE entry_id = ? AND deleted = 0
      ''', [updatedAt, updatedAt, entryId]);
    });
  }

  Future<int> activeCountForEntry(String entryId) async {
    await initialize();
    return _database!.select(
      'SELECT COUNT(*) AS count FROM attachments WHERE entry_id = ? AND deleted = 0',
      [entryId],
    ).single['count'] as int;
  }

  AttachmentRecord? _selectMetadata(String id) {
    final rows = _database!.select('''
      SELECT id, entry_id, name, mime_type, size, sha256, created_at,
             updated_at, deleted, deleted_at
      FROM attachments WHERE id = ? LIMIT 1
    ''', [id]);
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  static String validateFile(String name, int size) {
    final clean = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (clean.isEmpty || clean.length > 180) {
      throw const FormatException('Attachment file name is invalid');
    }
    final extension =
        clean.contains('.') ? clean.split('.').last.toLowerCase() : '';
    if (!allowedExtensions.contains(extension)) {
      throw const FormatException('This attachment type is not supported');
    }
    if (size <= 0 || size > maxAttachmentBytes) {
      throw const FormatException(
          'Each attachment must be between 1 byte and 25 MiB');
    }
    return clean;
  }

  static String mimeTypeFor(String name) {
    final extension = name.split('.').last.toLowerCase();
    return switch (extension) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt' => 'text/plain',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'application/octet-stream',
    };
  }

  void _validateRecord(AttachmentRecord record, Uint8List? bytes) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(record.id) ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(record.entryId)) {
      throw const FormatException('Attachment identity is invalid');
    }
    final cleanName = validateFile(record.name, record.size);
    if (cleanName != record.name ||
        record.mimeType != mimeTypeFor(record.name)) {
      throw const FormatException('Attachment metadata is invalid');
    }
    if (!record.deleted) {
      if (bytes == null || bytes.length != record.size) {
        throw const FormatException('Attachment size does not match metadata');
      }
      final digest = sha256.convert(bytes).toString();
      if (record.sha256.isEmpty || digest != record.sha256) {
        throw const FormatException('Attachment checksum does not match');
      }
    }
  }

  static AttachmentRecord _fromRow(Row row) => AttachmentRecord(
        id: row['id'] as String,
        entryId: row['entry_id'] as String,
        name: row['name'] as String,
        mimeType: row['mime_type'] as String,
        size: row['size'] as int,
        sha256: row['sha256'] as String,
        createdAt: row['created_at'] as int,
        updatedAt: row['updated_at'] as int,
        deleted: row['deleted'] == 1,
        deletedAt: row['deleted_at'] as int?,
      );

  static Future<File> _defaultDatabaseFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}'
        'work_experience_library${Platform.pathSeparator}attachments.sqlite');
  }
}
