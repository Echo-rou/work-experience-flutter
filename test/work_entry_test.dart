import 'package:flutter_test/flutter_test.dart';
import 'package:work_experience_library/models/work_entry.dart';

void main() {
  test('work entry JSON round trip keeps all user data', () {
    final original = WorkEntry(
      id: 'entry-1',
      date: '2026-08-04',
      title: '一次合同复盘',
      category: '工作',
      tags: const ['合同', '风险'],
      content: '## 判断过程',
      summary: '先核对履约条件',
      favorite: true,
      link: 'https://example.com',
      createdAt: 100,
      updatedAt: 200,
      deleted: true,
      purged: true,
    );

    final restored = WorkEntry.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.title, original.title);
    expect(restored.tags, original.tags);
    expect(restored.content, original.content);
    expect(restored.favorite, isTrue);
    expect(restored.purged, isTrue);
  });
}
