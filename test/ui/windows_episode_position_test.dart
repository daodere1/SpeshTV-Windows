import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:server_core/server_core.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/widgets/spesh_navigation_glass.dart';
import 'package:moonfin/ui/screens/detail/spotlight/widgets/spotlight_modal_grids.dart';

class _Images extends Mock implements ImageApi {}

AggregatedItem episode(int n, {bool played = false, int position = 0}) =>
    AggregatedItem(
      id: 'e$n',
      serverId: 'server',
      rawData: {
        'Type': 'Episode',
        'Name': 'Episode $n',
        'IndexNumber': n,
        'ParentIndexNumber': 2,
        'UserData': {'Played': played, 'PlaybackPositionTicks': position},
      },
    );

void main() {
  test(
    'initial episode prefers current, then resume, then first unwatched',
    () {
      final items = [
        episode(1, played: true),
        episode(2),
        episode(3, position: 100),
      ];
      expect(spotlightInitialEpisodeIndex(items, 'e1'), 0);
      expect(spotlightInitialEpisodeIndex(items, null), 2);
      expect(spotlightInitialEpisodeIndex(items.take(2).toList(), null), 1);
      expect(
        spotlightInitialEpisodeIndex([episode(1, played: true)], null),
        isNull,
      );
    },
  );
  for (final contrast in [false, true]) {
    testWidgets('navigation glass respects high contrast=$contrast', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(highContrast: contrast),
            child: const SpeshNavigationGlass(child: Text('Libraries')),
          ),
        ),
      );
      expect(find.text('Libraries'), findsOneWidget);
      expect(
        find.byType(BackdropFilter),
        contrast ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'initial episode scroll is applied once, not after watched/artwork refresh',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = PreferenceStore();
      await store.init();
      final prefs = UserPreferences(store);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      var items = [for (var n = 1; n <= 40; n++) episode(n)];
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return SingleChildScrollView(
                  controller: scroll,
                  child: SpotlightMediaGridSection(
                    items: items,
                    currentItemId: 'e30',
                    imageApi: _Images(),
                    prefs: prefs,
                    landscapeCells: true,
                    aspectRatio: 16 / 9,
                    onItemTap: (_) {},
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      update(() {
        items = [for (var n = 1; n <= 40; n++) episode(n, played: n == 30)];
      });
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
