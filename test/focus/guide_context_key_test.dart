import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/focus/guide_context_key.dart';

void main() {
  testWidgets('context key and Shift F10 open once without consuming plain F10', (tester) async {
    var opens = 0;
    var plainF10 = 0;
    await tester.pumpWidget(MaterialApp(home: Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        final result = handleGuideContextKey(event, () => opens++);
        if (result == KeyEventResult.ignored &&
            event.logicalKey == LogicalKeyboardKey.f10 && event is KeyDownEvent) {
          plainF10++;
        }
        return result;
      },
      child: const SizedBox(),
    )));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.contextMenu);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.contextMenu);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.contextMenu);
    expect(opens, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    expect(plainF10, 1);
    expect(opens, 1);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(opens, 2);
    expect(tester.takeException(), isNull);
  });
}
