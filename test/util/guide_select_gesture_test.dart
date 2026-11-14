import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/focus/guide_select_gesture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = LogicalKeyboardKey.select;
  const physical = PhysicalKeyboardKey.select;
  KeyEvent down() => KeyDownEvent(logicalKey: key, physicalKey: physical, timeStamp: Duration.zero);
  KeyEvent up() => KeyUpEvent(logicalKey: key, physicalKey: physical, timeStamp: Duration.zero);

  test('short select acts exactly once on release, not key down', () {
    fakeAsync((clock) {
      var selected = 0, held = 0;
      final gesture = GuideSelectGesture(onSelect: () => selected++, onHeld: () => held++);
      gesture.handle(down());
      clock.elapse(const Duration(milliseconds: 699));
      expect(selected, 0);
      gesture.handle(up());
      clock.elapse(const Duration(seconds: 1));
      expect(selected, 1); expect(held, 0);
      gesture.dispose();
    });
  });
  test('held select opens actions once without tuning on release', () {
    fakeAsync((clock) {
      var selected = 0, held = 0;
      final gesture = GuideSelectGesture(onSelect: () => selected++, onHeld: () => held++);
      gesture.handle(down());
      clock.elapse(const Duration(milliseconds: 700));
      gesture.handle(const KeyRepeatEvent(logicalKey: key, physicalKey: physical, timeStamp: Duration.zero));
      gesture.handle(up());
      expect(held, 1); expect(selected, 0);
      clock.elapse(const Duration(seconds: 11));
      gesture.dispose();
    });
  });
  test('focus loss cancels an unfinished hold', () {
    fakeAsync((clock) {
      var calls = 0;
      final gesture = GuideSelectGesture(onSelect: () => calls++, onHeld: () => calls++);
      gesture.handle(down()); gesture.cancel();
      clock.elapse(const Duration(seconds: 1)); gesture.handle(up());
      expect(calls, 0); gesture.dispose();
    });
  });
  test('returning to guide restores ID or clamps old row', () {
    expect(restoredGuideRow(['c', 'b', 'a'], 'b', 0), 1);
    expect(restoredGuideRow(['a'], 'removed', 40), 0);
    expect(restoredGuideRow(['a', 'b'], null, -5), 0);
    expect(restoredGuideRow([], 'a', 0), -1);
  });

  testWidgets('held repeat and release cannot activate the newly opened dialog', (tester) async {
    var chosen = 0;
    late GuideSelectGesture gesture;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      gesture = GuideSelectGesture(onSelect: () => chosen++, onHeld: () {
        showDialog<void>(context: context, builder: (context) => AlertDialog(
          content: TextButton(autofocus: true, onPressed: () => chosen++, child: const Text('Watch'))));
      });
      return Focus(autofocus: true, onKeyEvent: (_, e) => gesture.handle(e), child: const Text('Channel'));
    })));
    await tester.pump();
    await tester.sendKeyDownEvent(key);
    await tester.pump(const Duration(milliseconds: 701));
    await tester.pumpAndSettle();
    await tester.sendKeyRepeatEvent(key);
    await tester.sendKeyUpEvent(key);
    await tester.pump();
    expect(chosen, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(chosen, 1);
    gesture.dispose();
  });
}
