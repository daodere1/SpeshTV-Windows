import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/spesh_picker_now_next.dart';

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets('picker summary shows programmes and fits $width', (tester) async {
      tester.view.physicalSize = Size(width, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SpeshPickerNowNext(
        channel: '2 / CBS', loading: false, nowTitle: 'The current programme',
        nextTitle: 'The next programme', nowTime: '1:00 PM - 2:00 PM', nextTime: '2:00 PM - 3:00 PM',
      ))));
      expect(find.text('The current programme'), findsOneWidget);
      expect(find.text('The next programme'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('missing guide does not invent an event and loading is distinct', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SpeshPickerNowNext(channel: 'PPV', loading: true))));
    expect(find.text('Loading guide...'), findsNWidgets(2));
    expect(find.text('Guide unavailable'), findsNothing);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SpeshPickerNowNext(channel: 'PPV', loading: false))));
    expect(find.text('Guide unavailable'), findsNWidgets(2));
  });
}
