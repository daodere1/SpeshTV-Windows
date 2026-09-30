import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/spesh_empty_results.dart';

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets('empty results fit $width and keep actions independent', (tester) async {
      tester.view.physicalSize = Size(width, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var filters = 0;
      var searches = 0;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SpeshEmptyResults(
        title: 'No items found', onClearFilters: () => filters++, onClearSearch: () => searches++,
      ))));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Clear filters'));
      expect(filters, 1);
      expect(searches, 0);
      await tester.tap(find.text('Clear search'));
      expect(searches, 1);
    });
  }
  testWidgets('unfiltered empty library has no misleading clear actions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SpeshEmptyResults(title: 'No items found'))));
    expect(find.byType(TextButton), findsNothing);
    expect(find.text('No items found'), findsOneWidget);
  });
}
