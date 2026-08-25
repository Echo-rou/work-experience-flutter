import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'models/attachment_record.dart';
import 'models/work_entry.dart';
import 'services/attachment_repository.dart';
import 'services/lan_host_service.dart';
import 'services/lan_sync_service.dart';
import 'services/local_repository.dart';

enum LibraryView {
  home,
  timeline,
  favorites,
  tags,
  categories,
  trash,
  settings
}

class WorkLibraryState extends ChangeNotifier {
  WorkLibraryState(this._repository,
      {AttachmentRepository? attachmentRepository})
      : _attachmentRepository = attachmentRepository ?? AttachmentRepository();

  final LocalRepository _repository;
  final AttachmentRepository _attachmentRepository;
  final _uuid = const Uuid();
  final List<WorkEntry> _entries = [];
  final List<String> _categories = [];
  final List<AttachmentRecord> _attachments = [];
  final Map<String, dynamic> _meta = {};
  LanHostService? _hostService;

  bool loading = true;
  bool saving = false;
  bool syncing = false;
  String? error;
  String? syncMessage;
  String searchQuery = '';
  String? selectedTag;
  LibraryView view = LibraryView.home;

  List<WorkEntry> get entries => List.unmodifiable(_entries);
  List<String> get categories => List.unmodifiable(_categories);
  List<AttachmentRecord> attachmentsForEntry(String entryId) => _attachments
      .where(
          (attachment) => attachment.entryId == entryId && !attachment.deleted)
      .toList(growable: false);
  List<WorkEntry> get activeEntries =>
      _entries.where((e) => !e.isTodo && !e.deleted && !e.purged).toList();
  List<WorkEntry> get trashEntries =>
      _entries.where((e) => !e.isTodo && e.deleted && !e.purged).toList();
  List<WorkEntry> get todayTodos {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _entries
        .where((e) => e.isTodo && !e.deleted && !e.purged && e.date == today)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  String get serverUrl => _meta['serverUrl']?.toString() ?? '';
  String get serverToken => _meta['serverToken']?.toString() ?? '';
  int get lastBackupAt => _asInt(_meta['lastBackupAt']);
  int get lastSyncAt => _asInt(_meta['lastSyncAt']);
  bool get pwaHosting => _hostService?.running == true;
  String get pwaAddress => _hostService?.address ?? '';
  String get pwaSetupAddress => _hostService?.setupAddress ?? '';
  String get pwaPairingCode => _hostService?.pairingCode ?? '';
  String get pwaToken => _meta['hostToken']?.toString() ?? '';
  String? pwaHostError;

  Future<void> initialize() async {
    try {
      final snapshot = await _repository.load();
      _entries
        ..clear()
        ..addAll(snapshot.entries);
      _categories
        ..clear()
        ..addAll(snapshot.categories);
      _meta
        ..clear()
        ..addAll(snapshot.meta);
      await _attachmentRepository.initialize();
      await _reloadAttachments(notify: false);
      if (pwaToken.length < 32) {
        _meta['hostToken'] = _uuid.v4().replaceAll('-', '');
        await _repository.save(LibrarySnapshot(
            entries: _entries, categories: _categories, meta: _meta));
      }
      if (Platform.isWindows || Platform.isMacOS) {
        try {
          await startPwaHost();
        } catch (e) {
          pwaHostError = 'LAN service failed to start: $e';
        }
      }
    } catch (e) {
      error =
          'Local data could not be read. The damaged file was preserved: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void changeView(LibraryView next) {
    view = next;
    selectedTag = null;
    notifyListeners();
  }

  void setSearch(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  void selectTag(String? value) {
    selectedTag = value;
    notifyListeners();
  }

  WorkEntry? findEntry(String id) {
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Future<List<PlatformFile>> pickAttachmentFiles(
      {required int existingCount}) async {
    final remaining =
        AttachmentRepository.maxAttachmentsPerEntry - existingCount;
    if (remaining <= 0) {
      throw const FormatException(
          'Each record can contain up to 10 attachments');
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AttachmentRepository.allowedExtensions.toList(),
      allowMultiple: true,
      withData: false,
    );
    if (result == null) return const [];
    if (result.files.length > remaining) {
      throw FormatException('You can add up to $remaining more attachment(s)');
    }
    for (final file in result.files) {
      AttachmentRepository.validateFile(file.name, file.size);
      if (file.path == null && file.bytes == null) {
        throw FormatException('Could not read ${file.name}');
      }
    }
    return result.files;
  }

  Future<void> addAttachmentFiles(
      String entryId, List<PlatformFile> files) async {
    if (findEntry(entryId) == null) {
      throw const FormatException('Save the record before adding attachments');
    }
    final current = await _attachmentRepository.activeCountForEntry(entryId);
    if (current + files.length > AttachmentRepository.maxAttachmentsPerEntry) {
      throw const FormatException(
          'Each record can contain up to 10 attachments');
    }
    for (final file in files) {
      final bytes = file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) throw FormatException('Could not read ${file.name}');
      await _attachmentRepository.addFile(
        entryId: entryId,
        name: file.name,
        bytes: Uint8List.fromList(bytes),
      );
    }
    await _reloadAttachments();
  }

  Future<void> deleteAttachment(String id) async {
    final record = _attachments.where((item) => item.id == id).firstOrNull;
    if (record == null) return;
    await _attachmentRepository.markDeleted(
        id, DateTime.now().millisecondsSinceEpoch);
    await _reloadAttachments();
  }

  Future<String> materializeAttachment(String id) async {
    final payload = await _attachmentRepository.read(id);
    if (payload == null) {
      throw const FormatException('Attachment is unavailable');
    }
    final directory = Directory('${(await getTemporaryDirectory()).path}'
        '${Platform.pathSeparator}work_experience_attachments');
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}'
        '${payload.record.id}-${payload.record.name}');
    await file.writeAsBytes(payload.bytes, flush: true);
    return file.path;
  }

  Future<WorkEntry> saveEntry({
    String? id,
    required String date,
    required String title,
    required String category,
    required List<String> tags,
    required String summary,
    required String content,
    required String link,
    List<String> items = const [],
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = id == null ? null : findEntry(id);
    final entry = current == null
        ? WorkEntry(
            id: _uuid.v4(),
            date: date,
            title: title.trim(),
            category: category.trim(),
            tags: _cleanTags(tags),
            content: content,
            items: items,
            summary: summary.trim(),
            favorite: false,
            link: link.trim(),
            createdAt: now,
            updatedAt: now,
            deleted: false,
          )
        : current.copyWith(
            date: date,
            title: title.trim(),
            category: category.trim(),
            tags: _cleanTags(tags),
            content: content,
            items: items,
            summary: summary.trim(),
            link: link.trim(),
            updatedAt: now,
          );
    if (current == null) {
      _entries.add(entry);
    } else {
      _replace(entry);
    }
    if (entry.category.isNotEmpty && !_categories.contains(entry.category)) {
      _categories.add(entry.category);
    }
    await _persist();
    return entry;
  }

  Future<void> addTodo(String value) async {
    final text = value.trim();
    if (text.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _entries.add(WorkEntry(
      id: _uuid.v4(),
      date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      title: '',
      category: '',
      tags: const [],
      content: text,
      summary: '',
      favorite: false,
      link: '',
      createdAt: now,
      updatedAt: now,
      deleted: false,
      kind: 'todo',
    ));
    await _persist();
  }

  Future<void> toggleTodo(String id) async {
    final todo = findEntry(id);
    if (todo == null || !todo.isTodo) return;
    _replace(todo.copyWith(
      completed: !todo.completed,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await _persist();
  }

  Future<void> removeTodo(String id) async {
    final todo = findEntry(id);
    if (todo == null || !todo.isTodo) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _replace(todo.copyWith(
      deleted: true,
      purged: true,
      deletedAt: now,
      updatedAt: now,
    ));
    await _persist();
  }

  Future<void> toggleFavorite(String id) async {
    final entry = findEntry(id);
    if (entry == null) return;
    _replace(entry.copyWith(
        favorite: !entry.favorite,
        updatedAt: DateTime.now().millisecondsSinceEpoch));
    await _persist();
  }

  Future<void> moveToTrash(String id) async {
    final entry = findEntry(id);
    if (entry == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _replace(entry.copyWith(deleted: true, deletedAt: now, updatedAt: now));
    await _persist();
  }

  Future<void> restore(String id) async {
    final entry = findEntry(id);
    if (entry == null) return;
    _replace(entry.copyWith(
        deleted: false,
        clearDeletedAt: true,
        updatedAt: DateTime.now().millisecondsSinceEpoch));
    await _persist();
  }

  Future<void> purge(String id) async {
    final entry = findEntry(id);
    if (entry == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _replace(entry.copyWith(
      deleted: true,
      purged: true,
      deletedAt: now,
      updatedAt: now,
    ));
    await _attachmentRepository.deleteForEntry(id, now);
    await _reloadAttachments(notify: false);
    await _persist();
  }

  Future<void> emptyTrash() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].deleted && !_entries[i].purged) {
        _entries[i] = _entries[i].copyWith(
          purged: true,
          deletedAt: now,
          updatedAt: now,
        );
        await _attachmentRepository.deleteForEntry(_entries[i].id, now);
      }
    }
    await _persist();
  }

  Future<bool> addCategory(String value) async {
    final name = value.trim();
    if (name.isEmpty || _categories.contains(name)) return false;
    _categories.add(name);
    await _persist();
    return true;
  }

  Future<void> renameCategory(String oldName, String newName) async {
    final name = newName.trim();
    if (name.isEmpty || (name != oldName && _categories.contains(name))) return;
    final index = _categories.indexOf(oldName);
    if (index < 0) return;
    _categories[index] = name;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].category == oldName) {
        _entries[i] = _entries[i].copyWith(category: name, updatedAt: now);
      }
    }
    await _persist();
  }

  Future<void> deleteCategory(String name) async {
    _categories.remove(name);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].category == name) {
        _entries[i] =
            _entries[i].copyWith(category: 'Uncategorized', updatedAt: now);
      }
    }
    if (!_categories.contains('Uncategorized')) {
      _categories.add('Uncategorized');
    }
    await _persist();
  }

  List<WorkEntry> searchResults() {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return [];
    return activeEntries.where((entry) {
      final haystack = [
        entry.title,
        entry.summary,
        entry.content,
        entry.category,
        entry.tags.join(' ')
      ].join('\n').toLowerCase();
      return haystack.contains(query);
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<String?> exportBackup() async {
    final data = {
      'app': 'DailyWorkRecord',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': _categories,
      'entries': _entries
          .where((e) => !e.deleted && !e.purged)
          .map((e) => e.toJson()..remove('deleted'))
          .toList(),
    };
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
    final name =
        'work-experience-library-${DateFormat('yyyyMMdd').format(DateTime.now())}.dwr';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Work Experience Library Backup',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: ['dwr'],
      bytes: bytes,
    );
    if (path == null) return null;
    if (!kIsWeb && !await File(path).exists()) {
      await File(path).writeAsBytes(bytes, flush: true);
    }
    _meta['lastBackupAt'] = DateTime.now().millisecondsSinceEpoch;
    await _persist();
    return path;
  }

  Future<int?> importBackup({required bool merge}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['dwr', 'json'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    if (picked.size > 20 * 1024 * 1024) {
      throw const FormatException('Backup file exceeds the 20 MiB limit');
    }
    final bytes = picked.bytes ??
        (picked.path == null ? null : await File(picked.path!).readAsBytes());
    if (bytes == null) throw Exception('Could not read the backup file');
    final raw = jsonDecode(utf8.decode(bytes));
    if (raw is! Map || raw['entries'] is! List) {
      throw const FormatException('Invalid backup format');
    }
    final imported = (raw['entries'] as List)
        .whereType<Map>()
        .map((e) => WorkEntry.fromJson(Map<String, dynamic>.from(e)))
        .where((e) =>
            e.id.isNotEmpty &&
            (e.items.any((item) => item.trim().isNotEmpty) ||
                e.title.isNotEmpty ||
                e.summary.isNotEmpty ||
                e.content.isNotEmpty))
        .toList();
    if (!merge) {
      _entries.clear();
      _categories.clear();
    }
    final existing = {for (final entry in _entries) entry.id};
    var added = 0;
    for (final entry in imported) {
      if (existing.add(entry.id)) {
        _entries.add(entry.copyWith(deleted: false, clearDeletedAt: true));
        added++;
      }
      final category = entry.category.trim();
      if (category.isNotEmpty && !_categories.contains(category)) {
        _categories.add(category);
      }
    }
    for (final category
        in (raw['categories'] as List? ?? const []).map((e) => e.toString())) {
      if (category.trim().isNotEmpty &&
          !_categories.contains(category.trim())) {
        _categories.add(category.trim());
      }
    }
    await _persist();
    if (_categories.isEmpty) {
      _categories.addAll(LocalRepository.defaultCategories);
    }
    return added;
  }

  Future<void> saveLanConfig(String url, String token) async {
    _meta['serverUrl'] = url.trim();
    _meta['serverToken'] = token.trim();
    await _persist();
  }

  Future<void> testLan(String url, String token) async {
    await LanSyncService(baseUrl: url, token: token).ping();
  }

  Future<void> syncLan() async {
    if (serverUrl.isEmpty || serverToken.isEmpty) {
      throw Exception('Enter the computer URL and access key first');
    }
    syncing = true;
    syncMessage = 'Syncing…';
    notifyListeners();
    try {
      final service = LanSyncService(baseUrl: serverUrl, token: serverToken);
      await service.ping();
      final pendingDeletes = (_meta['pendingDeletes'] as List? ?? const [])
          .map((e) => e.toString())
          .toList();
      for (final id in pendingDeletes) {
        await service.deleteEntry(id);
      }
      _meta['pendingDeletes'] = <String>[];
      final remote = await service.pull();
      final localById = {for (final entry in _entries) entry.id: entry};
      final remoteById = {for (final entry in remote.entries) entry.id: entry};
      for (final remoteEntry in remote.entries) {
        final local = localById[remoteEntry.id];
        if (local == null || remoteEntry.updatedAt > local.updatedAt) {
          if (local == null) {
            _entries.add(remoteEntry);
          } else {
            _replace(remoteEntry);
          }
        }
      }
      for (final local in List<WorkEntry>.from(_entries)) {
        final remoteEntry = remoteById[local.id];
        if (remoteEntry == null || local.updatedAt > remoteEntry.updatedAt) {
          await service.putEntry(local);
        }
      }
      final categoryUnion = {..._categories, ...remote.categories};
      _categories
        ..clear()
        ..addAll(categoryUnion);
      for (final category in _categories) {
        if (!remote.categories.contains(category)) {
          await service.putCategory(category);
        }
      }
      await _syncLanAttachments(service);
      _meta['lastSyncAt'] = DateTime.now().millisecondsSinceEpoch;
      syncMessage = 'Sync complete';
      await _persist();
    } catch (e) {
      syncMessage = 'Sync failed: $e';
      rethrow;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> startPwaHost() async {
    if (_hostService?.running == true) return;
    _hostService = LanHostService(
      token: pwaToken,
      readStore: _readHostedStore,
      writeStore: _writeHostedStore,
      deleteStoreValue: _deleteHostedValue,
      clearStore: _clearHostedStore,
      writeBatch: _writeHostedBatch,
      readAttachmentManifest: _readHostedAttachmentManifest,
      readAttachment: _attachmentRepository.read,
      writeAttachment: _writeHostedAttachment,
      deleteAttachment: _deleteHostedAttachment,
      onPairingCodeChanged: notifyListeners,
    );
    try {
      await _hostService!.start();
      pwaHostError = null;
    } catch (e) {
      _hostService = null;
      pwaHostError = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> stopPwaHost() async {
    await _hostService?.stop();
    _hostService = null;
    notifyListeners();
  }

  List<Map<String, dynamic>> _readHostedStore(String store) => switch (store) {
        'entries' => _entries.map((entry) => entry.toJson()).toList(),
        'categories' => _categories
            .map((category) => {
                  'name': category,
                  'createdAt': _meta['categoryCreatedAt.$category'] ?? 0
                })
            .toList(),
        'meta' => _meta.entries
            .map((entry) => {'key': entry.key, 'value': entry.value})
            .toList(),
        _ => const [],
      };

  Future<void> _writeHostedBatch(List<Map<String, dynamic>> entries,
      List<Map<String, dynamic>> categories) async {
    final parsedEntries = entries.map(WorkEntry.fromJson).toList();
    if (parsedEntries.any((entry) => entry.id.isEmpty)) {
      throw const FormatException('missing entry id');
    }
    final categoryNames = categories
        .map((value) => value['name']?.toString().trim() ?? '')
        .toList();
    if (categoryNames.any((name) => name.isEmpty)) {
      throw const FormatException('missing category name');
    }
    for (final entry in parsedEntries) {
      if (entry.purged) {
        await _attachmentRepository.deleteForEntry(entry.id, entry.updatedAt);
      }
      final current = findEntry(entry.id);
      if (current == null) {
        _entries.add(entry);
      } else {
        _replace(entry);
      }
      if (entry.category.isNotEmpty && !_categories.contains(entry.category)) {
        _categories.add(entry.category);
      }
    }
    for (final name in categoryNames) {
      if (!_categories.contains(name)) _categories.add(name);
    }
    await _persist();
  }

  Future<List<Map<String, dynamic>>> _readHostedAttachmentManifest() async =>
      (await _attachmentRepository.listAll())
          .map((attachment) => attachment.toJson())
          .toList();

  Future<void> _writeHostedAttachment(
      Map<String, dynamic> value, List<int> bytes) async {
    final record = AttachmentRecord.fromJson(value);
    if (findEntry(record.entryId) == null) {
      throw const FormatException('Attachment record does not exist');
    }
    final known = _attachments.any((item) => item.id == record.id);
    if (!known &&
        await _attachmentRepository.activeCountForEntry(record.entryId) >=
            AttachmentRepository.maxAttachmentsPerEntry) {
      throw const FormatException('This record already has 10 attachments');
    }
    await _attachmentRepository.upsert(record, Uint8List.fromList(bytes));
    await _reloadAttachments();
  }

  Future<void> _deleteHostedAttachment(String id, int updatedAt) async {
    await _attachmentRepository.markDeleted(id, updatedAt);
    await _reloadAttachments();
  }

  Future<void> _writeHostedStore(
      String store, Map<String, dynamic> value) async {
    if (store == 'entries') {
      final entry = WorkEntry.fromJson(value);
      if (entry.id.isEmpty) throw const FormatException('missing entry id');
      final current = findEntry(entry.id);
      if (current == null) {
        _entries.add(entry);
      } else {
        _replace(entry);
      }
      if (entry.category.isNotEmpty && !_categories.contains(entry.category)) {
        _categories.add(entry.category);
      }
    } else if (store == 'categories') {
      final name = value['name']?.toString().trim() ?? '';
      if (name.isEmpty) throw const FormatException('missing category name');
      if (!_categories.contains(name)) _categories.add(name);
    } else if (store == 'meta') {
      final key = value['key']?.toString() ?? '';
      if (key.isEmpty) throw const FormatException('missing meta key');
      if (key != 'hostToken') _meta[key] = value['value'];
    }
    await _persist();
  }

  Future<void> _deleteHostedValue(String store, String key) async {
    if (store == 'entries') {
      _entries.removeWhere((entry) => entry.id == key);
      final now = DateTime.now().millisecondsSinceEpoch;
      await _attachmentRepository.deleteForEntry(key, now);
      await _reloadAttachments(notify: false);
    } else if (store == 'categories') {
      _categories.remove(key);
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < _entries.length; i++) {
        if (_entries[i].category == key) {
          _entries[i] =
              _entries[i].copyWith(category: 'Uncategorized', updatedAt: now);
        }
      }
    } else if (store == 'meta' && key != 'hostToken') {
      _meta.remove(key);
    }
    await _persist();
  }

  Future<void> _clearHostedStore(String store) async {
    if (store == 'entries') {
      _entries.clear();
    } else if (store == 'categories') {
      _categories.clear();
    } else if (store == 'meta') {
      final token = pwaToken;
      _meta.clear();
      _meta['hostToken'] = token;
    }
    await _persist();
  }

  Future<void> _syncLanAttachments(LanSyncService service) async {
    final remote = await service.pullAttachmentManifest();
    final local = await _attachmentRepository.listAll();
    final localById = {for (final item in local) item.id: item};
    final remoteById = {for (final item in remote) item.id: item};
    for (final id in {...localById.keys, ...remoteById.keys}) {
      final here = localById[id], there = remoteById[id];
      if (here != null && (there == null || here.version > there.version)) {
        if (here.deleted) {
          await service.deleteAttachment(here);
        } else {
          final payload = await _attachmentRepository.read(id);
          if (payload != null) await service.putAttachment(payload);
        }
      } else if (there != null &&
          (here == null || there.version > here.version)) {
        if (there.deleted) {
          await _attachmentRepository.markDeleted(id, there.version);
        } else {
          final payload = await service.downloadAttachment(there);
          await _attachmentRepository.upsert(there, payload);
        }
      }
    }
    await _reloadAttachments(notify: false);
  }

  Future<void> _reloadAttachments({bool notify = true}) async {
    _attachments
      ..clear()
      ..addAll(await _attachmentRepository.listAll());
    if (notify) notifyListeners();
  }

  Future<void> _persist() async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      await _repository.save(LibrarySnapshot(
          entries: _entries, categories: _categories, meta: _meta));
    } catch (e) {
      error = 'Save failed: $e';
      rethrow;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  void _replace(WorkEntry value) {
    final index = _entries.indexWhere((entry) => entry.id == value.id);
    if (index >= 0) _entries[index] = value;
  }

  static List<String> _cleanTags(List<String> values) => values
      .map((e) => e.trim().replaceAll(',', ''))
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
