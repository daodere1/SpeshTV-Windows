import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/screens/calendar/cinematic_calendar_screen.dart';
import 'package:moonfin/ui/widgets/spesh_cinematic.dart';

void main() {
  testWidgets('landscape titles remain readable without external labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 240,
            height: 135,
            child: CinematicArtworkTitle(
              title: 'A long series title and an episode name',
            ),
          ),
        ),
      ),
    );
    expect(
      find.text('A long series title and an episode name'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  test('Cinematic selects the trailer renderer and respects explicit Off', () {
    expect(
      resolveCinematicMediaBarMode(
        UserPreferences.mediaBarModeBanner,
        cinematic: true,
      ),
      UserPreferences.mediaBarModeMoonfin,
    );
    expect(
      resolveCinematicMediaBarMode(
        UserPreferences.mediaBarModeOff,
        cinematic: true,
      ),
      UserPreferences.mediaBarModeOff,
    );
    expect(
      resolveCinematicMediaBarMode(
        UserPreferences.mediaBarModeBanner,
        cinematic: false,
      ),
      UserPreferences.mediaBarModeBanner,
    );
  });

  test(
    'agenda filters the selected month, sorts, and deduplicates releases',
    () {
      CinematicCalendarEntry entry(String day, String route) =>
          CinematicCalendarEntry(
            date: DateTime.parse(day),
            title: 'Film',
            subtitle: 'Digital',
            route: route,
          );
      final early = entry('2026-11-01', '/item/one');
      final late = entry('2026-11-30', '/item/two');
      final result = calendarEntriesForMonth([
        late,
        entry('2026-12-01', '/item/three'),
        early,
        early,
        entry('2026-10-31', '/item/four'),
      ], DateTime(2026, 11));
      expect(result, [early, late]);
    },
  );

  for (final size in [const Size(800, 600), const Size(1920, 1080)]) {
    testWidgets('details frame fits $size and closes with Escape', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var closed = false;
      late Size contentSize;
      await tester.pumpWidget(
        MaterialApp(
          home: CinematicDetailFrame(
            onClose: () => closed = true,
            child: Builder(
              builder: (context) {
                contentSize = MediaQuery.sizeOf(context);
                return Scaffold(
                  body: TextButton(
                    autofocus: true,
                    onPressed: () {},
                    child: const Text('Play'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(contentSize.width, lessThanOrEqualTo(1120));
      expect(contentSize.height, lessThanOrEqualTo(size.height - 48));
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(closed, isTrue);
    });
  }
}
