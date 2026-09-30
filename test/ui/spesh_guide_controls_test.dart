import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/livetv/widgets/spesh_guide_controls.dart';
import 'package:moonfin/ui/widgets/spesh_brand.dart';

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets('guide controls fit $width and dispatch explicit actions', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final search = TextEditingController();
      final number = TextEditingController();
      var query = '';
      var jumps = 0;
      var homes = 0;
      var previews = 0;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
        const SpeshBrand(height: 64),
        SpeshGuideControls(searchController: search, numberController: number,
          onSearch: (value) => query = value, onJump: () => jumps++,
          onHome: () => homes++, onPreview: () => previews++),
      ]))));
      expect(tester.takeException(), isNull);
      await tester.enterText(find.widgetWithText(TextField, 'Search channels'), 'TNT');
      expect(query, 'TNT');
      await tester.tap(find.byTooltip('Clear channel search'));
      expect(query, '');
      await tester.enterText(find.widgetWithText(TextField, 'Channel #'), '4001');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(jumps, 1);
      await tester.tap(find.byTooltip('Jump to channel'));
      expect(jumps, 2);
      await tester.tap(find.widgetWithText(TextButton, 'SpeshTV'));
      expect(homes, 1);
      await tester.tap(find.byTooltip('Watch preview'));
      expect(previews, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      search.dispose(); number.dispose();
    });
  }
}
