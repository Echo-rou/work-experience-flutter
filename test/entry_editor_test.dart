import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_experience_library/app_state.dart';
import 'package:work_experience_library/services/local_repository.dart';
import 'package:work_experience_library/ui/entry_editor_page.dart';

void main() {
  testWidgets('record fields are full-width rows in the requested order',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: EntryEditorPage(state: WorkLibraryState(LocalRepository())),
    ));

    const keys = [
      ValueKey('record-date'),
      ValueKey('record-category'),
      ValueKey('record-tags'),
      ValueKey('record-link'),
    ];
    final rects = keys.map((key) => tester.getRect(find.byKey(key))).toList();

    for (var index = 0; index < rects.length - 1; index++) {
      expect(rects[index].bottom, lessThan(rects[index + 1].top));
    }
    expect(rects.map((rect) => rect.width).toSet().length, 1);
  });

  testWidgets('Enter adds an item and Shift Enter stays in the current item',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EntryEditorPage(state: WorkLibraryState(LocalRepository())),
    ));

    final first = find.byKey(const ValueKey('record-item-0'));
    await tester.tap(first);
    await tester.enterText(first, 'First line');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(find.byKey(const ValueKey('record-item-1')), findsNothing);
    expect(tester.widget<TextField>(first).controller!.text, 'First line\n');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.byKey(const ValueKey('record-item-1')), findsOneWidget);
  });

  testWidgets('the row add button inserts the next item', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EntryEditorPage(state: WorkLibraryState(LocalRepository())),
    ));

    await tester.tap(find.byKey(const ValueKey('add-item-0')));
    await tester.pump();

    expect(find.byKey(const ValueKey('record-item-1')), findsOneWidget);
  });
}
