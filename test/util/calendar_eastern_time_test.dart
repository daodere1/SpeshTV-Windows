import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/calendar_eastern_time.dart';
import 'package:moonfin/ui/screens/calendar/cinematic_calendar_screen.dart';

void main() {
  test('Eastern time uses EST in winter and EDT in summer', () {
    final winter = calendarEasternDate(DateTime.parse('2026-11-15T02:00:00Z'), hasAirTime: true);
    expect([winter.day, winter.hour, winter.timeZoneName], [14, 21, 'EST']);
    final summer = calendarEasternDate(DateTime.parse('2026-07-15T02:00:00Z'), hasAirTime: true);
    expect([summer.day, summer.hour, summer.timeZoneName], [14, 22, 'EDT']);
  });
  test('daylight-saving transitions preserve correct Eastern clock times', () {
    final before = calendarEasternDate(DateTime.parse('2026-03-08T06:30:00Z'), hasAirTime: true);
    final after = calendarEasternDate(DateTime.parse('2026-03-08T07:30:00Z'), hasAirTime: true);
    expect([before.hour, before.timeZoneName], [1, 'EST']);
    expect([after.hour, after.timeZoneName], [3, 'EDT']);
  });
  test('date-only releases keep their day and Eastern month boundaries apply', () {
    expect(calendarEasternDate(DateTime.utc(2026, 11, 1), hasAirTime: false).day, 1);
    final entry = CinematicCalendarEntry(date: DateTime.parse('2026-11-01T02:00:00Z'),
      title: 'Episode', subtitle: '', route: '/item/1', hasAirTime: true);
    expect(calendarEntriesForMonth([entry], DateTime(2026, 11)), isEmpty);
    expect(calendarEntriesForMonth([entry], DateTime(2026, 10)), [entry]);
  });
}
