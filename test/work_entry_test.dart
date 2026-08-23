import 'package:flutter_test/flutter_test.dart';
import 'package:work_experience_library/models/work_entry.dart';

void main() {
  WorkEntry entry({
    String title = '',
    String summary = '',
    String content = '',
    List<String> items = const [],
    String kind = 'record',
    bool completed = false,
  }) =>
      WorkEntry(
        id: '1',
        date: '2026-08-23',
        title: title,
        category: '',
        tags: const [],
        content: content,
        items: items,
        summary: summary,
        favorite: false,
        link: '',
        createdAt: 1,
        updatedAt: 1,
        deleted: false,
        kind: kind,
        completed: completed,
      );

  test('merges legacy summary and content into individual items', () {
    final value = entry(
      title: 'Old title',
      summary: 'First point',
      content: 'Second point\n\nThird point',
    );

    expect(value.contentItems, ['First point', 'Second point', 'Third point']);
    expect(value.displayText, 'First point');
  });

  test('uses old title only when a legacy record has no content', () {
    final value = entry(title: 'Legacy title');

    expect(value.contentItems, ['Legacy title']);
    expect(value.displayText, 'Legacy title');
  });

  test('timeline preview is compact for long content', () {
    final value = entry(content: List.filled(30, 'abcdefghij').join());

    expect(value.timelinePreview().endsWith('…'), isTrue);
    expect(value.timelinePreview().length, lessThan(value.combinedText.length));
  });

  test('todo type and completion survive JSON round trip', () {
    final value =
        entry(content: 'Buy groceries', kind: 'todo', completed: true);
    final restored = WorkEntry.fromJson(value.toJson());

    expect(restored.isTodo, isTrue);
    expect(restored.completed, isTrue);
    expect(restored.content, 'Buy groceries');
  });

  test('line breaks stay inside an explicit item after JSON round trip', () {
    final value = entry(items: const ['First line\nSecond line', 'Next item']);
    final restored = WorkEntry.fromJson(value.toJson());

    expect(
        restored.contentItems, const ['First line\nSecond line', 'Next item']);
  });
}
