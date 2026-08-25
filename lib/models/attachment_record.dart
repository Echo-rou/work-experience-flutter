import 'dart:typed_data';

class AttachmentRecord {
  const AttachmentRecord({
    required this.id,
    required this.entryId,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.sha256,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    this.deletedAt,
  });

  final String id;
  final String entryId;
  final String name;
  final String mimeType;
  final int size;
  final String sha256;
  final int createdAt;
  final int updatedAt;
  final bool deleted;
  final int? deletedAt;

  int get version =>
      [updatedAt, deletedAt ?? 0].reduce((a, b) => a > b ? a : b);

  factory AttachmentRecord.fromJson(Map<String, dynamic> json) =>
      AttachmentRecord(
        id: json['id']?.toString() ?? '',
        entryId: json['entryId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        mimeType: json['mimeType']?.toString() ?? 'application/octet-stream',
        size: _asInt(json['size']),
        sha256: json['sha256']?.toString() ?? '',
        createdAt: _asInt(json['createdAt']),
        updatedAt: _asInt(json['updatedAt']),
        deleted: json['deleted'] == true || json['deleted'] == 1,
        deletedAt: json['deletedAt'] == null ? null : _asInt(json['deletedAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'entryId': entryId,
        'name': name,
        'mimeType': mimeType,
        'size': size,
        'sha256': sha256,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deleted': deleted,
        if (deletedAt != null) 'deletedAt': deletedAt,
      };

  AttachmentRecord copyWith({
    int? updatedAt,
    bool? deleted,
    int? deletedAt,
  }) =>
      AttachmentRecord(
        id: id,
        entryId: entryId,
        name: name,
        mimeType: mimeType,
        size: size,
        sha256: sha256,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        deletedAt: deletedAt ?? this.deletedAt,
      );

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class AttachmentPayload {
  const AttachmentPayload(this.record, this.bytes);

  final AttachmentRecord record;
  final Uint8List bytes;
}
