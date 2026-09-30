import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/spesh_previous_channel_button.dart';

void main() {
  testWidgets('previous channel is disabled without a target', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SpeshPreviousChannelButton())));
    expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
    expect(tester.getSize(find.byType(SpeshPreviousChannelButton)), const Size(44, 44));
  });
  for (final width in [320.0, 1280.0]) {
    testWidgets('previous channel fits $width and dispatches its action', (tester) async {
      tester.view.physicalSize = Size(width, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var taps = 0;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Row(children: [
        const Expanded(child: Text('A long channel name', maxLines: 1, overflow: TextOverflow.ellipsis)),
        SpeshPreviousChannelButton(channelName: 'TNT', onPressed: () => taps++),
      ]))));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Previous channel: TNT'));
      expect(taps, 1);
    });
  }
}
