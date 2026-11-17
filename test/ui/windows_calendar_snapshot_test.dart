import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moonfin/ui/widgets/focus/focusable_wrapper.dart';
import 'package:moonfin/ui/screens/calendar/cinematic_calendar_screen.dart';
import 'package:moonfin/util/calendar_eastern_time.dart';

void main() {
  test('provider hasFile never claims Jellyfin availability', () {
    expect(calendarAvailabilityLabel({'hasFile': true}, tv: false), isNull);
    expect(calendarAvailabilityLabel({'hasFile': true}, tv: true), isNull);
    expect(
      radarrCalendarRoute({'moonfinItemId': 'movie', 'tmdbId': 0}),
      '/item/movie',
    );
    expect(radarrCalendarRoute({'tmdbId': 123}), contains('123'));
  });
  test('episode availability and local route survive timing-source merge in either order', () {
    final local = CinematicCalendarEntry(
      date: DateTime(2026, 11, 16),
      title: 'Show',
      subtitle: '',
      route: '/item/episode',
      isTv: true,
      availabilityLabel: 'Available',
      episodeKey: 'show|1|1',
    );
    final remote = CinematicCalendarEntry(
      date: DateTime.parse('2026-11-16T22:00:00Z'),
      title: 'Show',
      subtitle: '',
      route: '/item/series',
      isTv: true,
      availabilityLabel: 'Series available',
      episodeKey: 'show|1|1',
      hasAirTime: true,
      timingPriority: 2,
    );
    for (final items in [
      [local, remote],
      [remote, local],
    ]) {
      final row = calendarEntriesForRange(
        items,
        DateTime(2026, 11, 16),
        DateTime(2026, 11, 17),
      ).single;
      expect(row.route, '/item/episode');
      expect(row.availabilityLabel, 'Available');
      expect(row.hasAirTime, true);
    }
  });
  test('next Eastern midnight follows 23-hour and 25-hour DST days', () {
    final spring = DateTime.parse('2026-03-08T05:00:00Z');
    final fall = DateTime.parse('2026-11-01T04:00:00Z');
    expect(calendarNextEasternMidnight(spring).difference(spring).inHours, 23);
    expect(calendarNextEasternMidnight(fall).difference(fall).inHours, 25);
  });
  testWidgets('pointer and keyboard filters only select loaded entries', (
    tester,
  ) async {
    var selected = CalendarMediaFilter.all;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => CalendarMediaFilters(
              selected: selected,
              onChanged: (value) => update(() => selected = value),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('TV'));
    await tester.pumpAndSettle();
    expect(selected, CalendarMediaFilter.tv);
    final focus = Focus.of(tester.element(find.text('Movies')));
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, CalendarMediaFilter.movies);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(selected, CalendarMediaFilter.all);
    focus.requestFocus(); await tester.pump();
    // Flutter's Windows test map has no gamepad HID entry; only the event
    // keymap is changed here. The widget platform remains Windows.
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA, platform: 'android', physicalKey: PhysicalKeyboardKey.enter);
    await tester.pumpAndSettle(); expect(selected, CalendarMediaFilter.movies);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  for (final key in [
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.gameButtonA,
  ]) {
    testWidgets('native calendar details Back restores focus for $key', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: CalendarEntryLink(
                route: '/item/movie',
                accent: Color(0xFFF3C564),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Movie'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/item/:id',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.pop(),
                child: const Text('Back'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      final node = tester
          .widget<FocusableWrapper>(find.byType(FocusableWrapper))
          .focusNode!;
      node.requestFocus();
      await tester.pump();
      if (key == LogicalKeyboardKey.gameButtonA) {
        await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA, platform: 'android', physicalKey: PhysicalKeyboardKey.enter);
      } else {
        await tester.sendKeyEvent(key);
      }
      await tester.pumpAndSettle();
      expect(find.text('Back'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(node.hasFocus, true);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
}
