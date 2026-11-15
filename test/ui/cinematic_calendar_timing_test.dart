import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/calendar/cinematic_calendar_screen.dart';
import 'package:moonfin/ui/widgets/spesh_streaming_services.dart';

void main() {
  test(
    'TVDB-only Sonarr airings retain a playable or searchable destination',
    () {
      final episode = {
        'series': {'title': 'A Series', 'tvdbId': 123},
        'airDateUtc': '2026-11-15T02:00:00Z',
      };
      expect(sonarrCalendarRoute(episode), contains('/search'));
      expect(sonarrCalendarDate(episode)!.hasTime, true);
      expect(
        sonarrCalendarRoute({...episode, 'moonfinEpisodeId': 'local-episode'}),
        '/item/local-episode',
      );
    },
  );
  test('streaming navigation contains only the nine approved services', () {
    expect(speshStreamingServices.map((s) => s.name).toList(), [
      'Netflix',
      'Disney+',
      'Prime Video',
      'Apple TV+',
      'Hulu',
      'HBO Max',
      'Paramount+',
      'Peacock',
      'Discovery+',
    ]);
    for (final service in speshStreamingServices) {
      final route = Uri.parse(streamingServiceRoute(service.name));
      expect(route.queryParameters['filterType'], 'network');
      expect(route.queryParameters['filterId'], '${service.networkId}');
    }
  });
  test('Sonarr UTC and explicit offsets preserve the same airing instant', () {
    final utc = sonarrCalendarDate({'airDateUtc': '2026-11-15T02:00:00Z'});
    final offset = sonarrCalendarDate({
      'airDateUtc': '2026-11-14T21:00:00-05:00',
    });
    expect(utc!.hasTime, true);
    expect(offset!.date.isAtSameMomentAs(utc.date), true);
    expect(sonarrCalendarDate({'airDate': '2026-11-14'})!.hasTime, false);
    expect(
      sonarrCalendarDate({'airDateUtc': 'bad', 'airDate': '2026-11-14'})!
          .hasTime,
      false,
    );
    expect(sonarrCalendarDate({'airDateUtc': '2026-11-14T21:00:00'}), isNull);
  });
  test('authoritative air time wins in either fetch order, retaining local playback', () {
    final key = calendarEpisodeKey('A Series', 1, 2);
    final local = CinematicCalendarEntry(
      date: DateTime(2026, 11, 14),
      title: 'A Series',
      subtitle: 'Jellyfin',
      route: '/item/episode',
      episodeKey: key,
    );
    final timed = CinematicCalendarEntry(
      date: DateTime(2026, 11, 14, 21),
      title: 'A Series',
      subtitle: 'Sonarr',
      route: '/seerr/media/2',
      episodeKey: key,
      hasAirTime: true,
      timingPriority: 2,
    );
    for (final list in [
      [local, timed],
      [timed, local],
    ]) {
      final result = calendarEntriesForMonth(list, DateTime(2026, 11));
      expect(result.length, 1);
      expect(result.single.date.hour, 21);
      expect(result.single.hasAirTime, true);
      expect(result.single.route, '/item/episode');
    }
  });
}
