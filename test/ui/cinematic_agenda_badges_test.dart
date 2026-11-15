import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/repositories/anime_marker_repository.dart';
import 'package:moonfin/ui/widgets/spesh_anime_badges.dart';
import 'package:moonfin/ui/screens/calendar/cinematic_calendar_screen.dart';
import 'package:moonfin/ui/widgets/seerr/seerr_shortcuts.dart';

void main() {
  test('upcoming agenda keeps today, crosses month boundaries, and excludes yesterday', () {
    CinematicCalendarEntry row(String day, {bool tv = false}) =>
        CinematicCalendarEntry(
          date: DateTime.parse(day),
          title: day,
          subtitle: '',
          route: '/item/$day',
          isTv: tv,
        );
    final yesterday = row('2026-11-13');
    final today = row('2026-11-14', tv: true);
    final nextMonth = row('2026-12-02');
    final rows = calendarEntriesForRange(
      [yesterday, nextMonth, today],
      DateTime(2026, 11, 14),
      DateTime(2027, 2, 12),
    );
    expect(rows, [today, nextMonth]);
    expect(rows.first.isTv, true);
    expect(rows.last.isTv, false);
    expect(
      SeerrShortcut.values.indexOf(SeerrShortcut.search),
      SeerrShortcut.values.indexOf(SeerrShortcut.issues) + 1,
    );
  });
  for (final width in [100.0, 200.0, 320.0]) {
    testWidgets('compact audio tags fit a $width pixel card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: width,
              child: const SpeshAnimeMarkerLabels(
                compact: true,
                marker: AnimeEpisodeMarker(
                  kind: AnimeEpisodeKind.mangaCanon,
                  recap: false,
                  audio: AnimeAudioKind.subbedAndDubbed,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final label = tester.widget<Text>(find.text('Subbed + dubbed'));
      expect(label.style!.fontSize, inInclusiveRange(8, 10));
      expect(
        tester.getSize(find.byType(SpeshAnimeMarkerLabels)).height,
        lessThan(60),
      );
    });
  }
}
