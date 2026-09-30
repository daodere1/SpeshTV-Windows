import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/ui/widgets/spesh_season_selector.dart';

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets('season selection and counts fit $width', (tester) async {
      int? selected;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(
        width: width,
        child: SpeshSeasonSelector(selected: 1, label: 'Seasons',
          options: const {1: 'Season 1 - 3/10 watched', 2: 'Season 2 - 0/8 watched'},
          onChanged: (value) => selected = value),
      ))));
      expect(find.text('Season 1 - 3/10 watched'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Season 2 - 0/8 watched').last);
      await tester.pumpAndSettle();
      expect(selected, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
