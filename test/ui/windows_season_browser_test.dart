import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:server_core/server_core.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/ui/screens/detail/spotlight/widgets/spotlight_season_browser.dart';
import 'package:moonfin/ui/screens/detail/spotlight/widgets/spotlight_section_modal.dart';
import 'package:moonfin/ui/widgets/media_card.dart';

class _Images extends Mock implements ImageApi {}

AggregatedItem ep(
  int season,
  int number, {
  bool played = false,
  bool favorite = false,
  String? art,
}) => AggregatedItem(
  id: 'ep$season-$number',
  serverId: 'server',
  rawData: {
    'Type': 'Episode',
    'SeriesId': 'show',
    'SeasonId': 's$season',
    'Name': 'Episode $season-$number',
    'IndexNumber': number,
    'ParentIndexNumber': season,
    'UserData': {'Played': played, 'IsFavorite': favorite},
    if (art != null) 'ImageTags': {'Primary': art},
  },
);
void main() {
  late UserPreferences prefs;
  late _Images images;
  setUp(() async {
    await GetIt.instance.reset();
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    prefs = UserPreferences(store);
    images = _Images();
    when(() => images.getPrimaryImageUrl('show', maxHeight: 360))
        .thenReturn('');
    for (var n = 1; n <= 14; n++) {
      when(() => images.getPrimaryImageUrl('s$n', maxHeight: 360))
          .thenReturn('');
    }
  });
  tearDown(() => GetIt.instance.reset());
  Future<void> open(
    WidgetTester tester,
    ValueNotifier<Map<int, List<AggregatedItem>>> groups, {
    int currentSeason = 1,
    String current = 'ep1-1',
    Future<List<AggregatedItem>?> Function(String)? refreshSeason,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Open'),
              onPressed: () => SpotlightSectionModal.show(
                context,
                title: 'More Episodes',
                sections: [
                  SpotlightModalSection(
                    fillsViewport: true,
                    builder: (context, focus) =>
                        ValueListenableBuilder<Map<int, List<AggregatedItem>>>(
                          valueListenable: groups,
                          builder: (context, data, _) => SpotlightSeasonBrowser(
                            groups: data,
                            refreshSeason: refreshSeason,
                            currentItemId: current,
                            currentSeason: currentSeason,
                            imageApi: images,
                            prefs: prefs,
                            seasonLabel: (n) => 'Season $n',
                            onItemTap: (_) {},
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Down reaches the last episode from a missing column', (
    tester,
  ) async {
    final groups = ValueNotifier({1: [for (var n = 1; n <= 18; n++) ep(1, n)]});
    addTearDown(groups.dispose);
    await open(tester, groups);
    await tester.tap(find.text('Season 1'));
    await tester.pumpAndSettle();
    final grid = tester.widget<GridView>(find.byType(GridView).last);
    final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    final columns = delegate.crossAxisCount;
    expect(columns, greaterThan(1));
    groups.value = {1: [for (var n = 1; n <= columns + 1; n++) ep(1, n)]};
    await tester.pumpAndSettle();
    for (var column = 1; column < columns; column++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
    }
    final previous = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final tail = tester.widget<MediaCard>(
      find.widgetWithText(MediaCard, '${columns + 1} · Episode 1-${columns + 1}'),
    );
    expect(tail.focusNode, isNot(same(previous)));
    expect(tail.focusNode?.hasPrimaryFocus, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('fresh season retains cached episodes and ignores a late result', (
    tester,
  ) async {
    final groups = ValueNotifier({4: [ep(4, 8), ep(4, 9)]});
    addTearDown(groups.dispose);
    final requests = <Completer<List<AggregatedItem>?>>[];
    when(() => images.getPrimaryImageUrl('s4', maxHeight: 360)).thenReturn('');
    await open(tester, groups, currentSeason: 4, current: 'ep4-9',
        refreshSeason: (seasonId) {
      expect(seasonId, 's4');
      final result = Completer<List<AggregatedItem>?>();
      requests.add(result);
      return result.future;
    });
    await tester.tap(find.text('Season 4'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Episode 4-9'), findsOneWidget);
    final focused = FocusManager.instance.primaryFocus;
    requests[0].complete([ep(4, 8), ep(4, 9), ep(4, 10)]);
    await tester.pumpAndSettle();
    expect(find.text('3 episodes'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus, same(focused));

    await tester.tap(find.byKey(const ValueKey('episode_seasons_back')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Season 4'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('episode_seasons_back')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Season 4'));
    await tester.pumpAndSettle();
    requests[2].complete([ep(4, 8), ep(4, 9), ep(4, 10), ep(4, 11)]);
    requests[1].complete([ep(4, 8)]);
    await tester.pumpAndSettle();
    expect(find.text('4 episodes'), findsOneWidget);
  });

  testWidgets(
    'one-season show requires picker, then Back returns through picker',
    (tester) async {
      final data = ValueNotifier({
        1: [ep(1, 1), ep(1, 2)],
      });
      addTearDown(data.dispose);
      await open(tester, data);
      expect(find.text('Choose a season'), findsOneWidget);
      verify(() => images.getPrimaryImageUrl('s1', maxHeight: 360))
          .called(greaterThan(0));
      expect(find.textContaining('Episode 1-1'), findsNothing);
      await tester.tap(find.text('Season 1'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Episode 1-1'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Choose a season'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Choose a season'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets(
    'long season is virtualized, keeps tail and in-place updates, Back retains picker',
    (tester) async {
      final data = ValueNotifier({
        1: [ep(1, 1), ep(1, 2)],
        2: [for (var n = 1; n <= 500; n++) ep(2, n)],
      });
      addTearDown(data.dispose);
      await open(tester, data, currentSeason: 2, current: 'ep2-350');
      await tester.tap(find.text('Season 2'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Episode 2-350'), findsOneWidget);
      expect(find.byType(MediaCard).evaluate().length, lessThan(40));
      final grid = tester.widget<GridView>(find.byType(GridView).last);
      expect(grid.semanticChildCount, 500);
      grid.controller!.jumpTo(grid.controller!.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.textContaining('Episode 2-500'), findsOneWidget);
      final offset = grid.controller!.offset;
      when(
        () => images.getPrimaryImageUrl('ep2-500', maxHeight: 360, tag: 'new'),
      ).thenReturn('');
      data.value = {
        1: data.value[1]!,
        2: [
          for (var n = 1; n <= 500; n++)
            ep(
              2,
              n,
              played: n == 500,
              favorite: n == 500,
              art: n == 500 ? 'new' : null,
            ),
        ],
      };
      await tester.pumpAndSettle();
      expect(grid.controller!.offset, closeTo(offset, 1));
      final card = tester.widget<MediaCard>(
        find.byWidgetPredicate(
          (w) => w is MediaCard && w.title?.contains('Episode 2-500') == true,
        ),
      );
      expect(card.isPlayed, true);
      expect(card.isFavorite, true);
      verify(
        () => images.getPrimaryImageUrl('ep2-500', maxHeight: 360, tag: 'new'),
      ).called(greaterThan(0));
      await tester.tap(find.byKey(const ValueKey('episode_seasons_back')));
      await tester.pumpAndSettle();
      expect(find.text('Choose a season'), findsOneWidget);
      await tester.tap(find.text('Season 1'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Episode 1-1'), findsOneWidget);
      expect(find.textContaining('Episode 2-350'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets(
    'picker scroll and keyboard/controller Back restore the selected season',
    (tester) async {
      final data = ValueNotifier({
        for (var n = 1; n <= 14; n++) n: [ep(n, 1)],
      });
      addTearDown(data.dispose);
      await open(tester, data);
      final picker = tester.widget<GridView>(find.byType(GridView).last);
      picker.controller!.jumpTo(picker.controller!.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final position = picker.controller!.offset;
      await tester.tap(find.text('Season 14'));
      await tester.pumpAndSettle();
      expect(find.byType(Scrollable), findsOneWidget);
      expect(find.textContaining('Episode 14-1'), findsOneWidget);
      await tester.sendKeyEvent(
        LogicalKeyboardKey.gameButtonB,
        platform: 'android',
        physicalKey: PhysicalKeyboardKey.escape,
      );
      await tester.pumpAndSettle();
      expect(find.text('Choose a season'), findsOneWidget);
      expect(picker.controller!.offset, closeTo(position, 1));
      final card = tester.widget<MediaCard>(
        find.byWidgetPredicate((w) => w is MediaCard && w.title == 'Season 14'),
      );
      expect(card.focusNode!.hasFocus, true);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.textContaining('Episode 14-1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
