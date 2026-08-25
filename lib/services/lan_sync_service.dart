import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/attachment_record.dart';
import '../models/work_entry.dart';

class LanSnapshot {
  LanSnapshot({required this.entries, required this.categories});
  final List<WorkEntry> entries;
  final List<String> categories;
}

class LanSyncService {
  LanSyncService({required String baseUrl, required this.token})
      : baseUrl = _normalize(baseUrl);

  final String baseUrl;
  final String token;

  static String _normalize(String value) {
    var result = value.trim();
    if (!result.startsWith('http://') && !result.startsWith('https://')) {
      result = 'https://$result';
    }
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    final uri = Uri.tryParse(result);
    if (uri == null || !uri.hasAuthority) {
      throw const FormatException('Enter a valid HTTPS sync URL');
    }
    final localOnly = uri.scheme == 'http' &&
        (uri.host == 'localhost' ||
            uri.host == '127.0.0.1' ||
            uri.host == '::1');
    if (uri.scheme != 'https' && !localOnly) {
      throw const FormatException(
          'HTTPS is required because HTTP can expose the access key');
    }
    return uri.toString();
  }

  Map<String, String> get _headers => {
        'X-Key': token,
        'Content-Type': 'application/json; charset=utf-8',
      };

  Future<void> ping() async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/ping'), headers: _headers)
        .timeout(const Duration(seconds: 6));
    _check(response);
  }

  Future<LanSnapshot> pull() async {
    final responses = await Future.wait([
      http.get(Uri.parse('$baseUrl/api/store/entries'), headers: _headers),
      http.get(Uri.parse('$baseUrl/api/store/categories'), headers: _headers),
    ]).timeout(const Duration(seconds: 12));
    responses.forEach(_check);
    final entries = (jsonDecode(utf8.decode(responses[0].bodyBytes)) as List)
        .whereType<Map>()
        .map((e) => WorkEntry.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.id.isNotEmpty)
        .toList();
    final categories = (jsonDecode(utf8.decode(responses[1].bodyBytes)) as List)
        .whereType<Map>()
        .map((e) => e['name']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    return LanSnapshot(entries: entries, categories: categories);
  }

  Future<List<AttachmentRecord>> pullAttachmentManifest() async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/attachments'), headers: _headers)
        .timeout(const Duration(seconds: 12));
    _check(response);
    return (jsonDecode(utf8.decode(response.bodyBytes)) as List)
        .whereType<Map>()
        .map((value) =>
            AttachmentRecord.fromJson(Map<String, dynamic>.from(value)))
        .where((value) => value.id.isNotEmpty && value.entryId.isNotEmpty)
        .toList();
  }

  Future<Uint8List> downloadAttachment(AttachmentRecord record) async {
    final response = await http.get(
        Uri.parse('$baseUrl/api/attachments/${Uri.encodeComponent(record.id)}'),
        headers: {'X-Key': token}).timeout(const Duration(seconds: 45));
    _check(response);
    return response.bodyBytes;
  }

  Future<void> putAttachment(AttachmentPayload payload) async {
    final metadata =
        base64UrlEncode(utf8.encode(jsonEncode(payload.record.toJson())));
    final response = await http
        .put(
          Uri.parse('$baseUrl/api/attachments/'
              '${Uri.encodeComponent(payload.record.id)}'),
          headers: {
            'X-Key': token,
            'X-Attachment-Meta': metadata,
            'Content-Type': payload.record.mimeType,
          },
          body: payload.bytes,
        )
        .timeout(const Duration(seconds: 60));
    _check(response);
  }

  Future<void> deleteAttachment(AttachmentRecord record) async {
    final uri = Uri.parse('$baseUrl/api/attachments/'
            '${Uri.encodeComponent(record.id)}')
        .replace(queryParameters: {'updatedAt': record.version.toString()});
    final response = await http.delete(uri,
        headers: {'X-Key': token}).timeout(const Duration(seconds: 12));
    _check(response);
  }

  Future<void> putEntry(WorkEntry entry) =>
      _put('/api/store/entries', entry.toJson());

  Future<void> putCategory(String category) => _put('/api/store/categories', {
        'name': category,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

  Future<void> deleteEntry(String id) async {
    final response = await http
        .delete(
            Uri.parse('$baseUrl/api/store/entries/${Uri.encodeComponent(id)}'),
            headers: _headers)
        .timeout(const Duration(seconds: 8));
    _check(response);
  }

  Future<void> _put(String path, Map<String, dynamic> body) async {
    final response = await http
        .put(Uri.parse('$baseUrl$path'),
            headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 8));
    _check(response);
  }

  void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 403) throw Exception('Incorrect access key');
      throw Exception('LAN service returned ${response.statusCode}');
    }
  }
}
