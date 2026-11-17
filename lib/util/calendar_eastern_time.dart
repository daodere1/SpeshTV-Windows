import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

final tz.Location _eastern = (() {
  data.initializeTimeZones();
  return tz.getLocation('America/New_York');
})();

/// Date-only releases retain their published day; only real air times shift.
DateTime calendarEasternDate(DateTime date, {required bool hasAirTime}) =>
    hasAirTime
    ? tz.TZDateTime.from(date, _eastern)
    : DateTime(date.year, date.month, date.day);

DateTime calendarEasternNow() => tz.TZDateTime.now(_eastern);

DateTime calendarNextEasternMidnight(DateTime instant) {
  final now = tz.TZDateTime.from(instant, _eastern);
  return tz.TZDateTime(_eastern, now.year, now.month, now.day + 1);
}
