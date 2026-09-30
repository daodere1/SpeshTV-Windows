({Map<String, dynamic>? now, Map<String, dynamic>? next}) speshNowNext(
    List<dynamic> items, DateTime clock) {
  final valid = <({Map<String, dynamic> item, DateTime start, DateTime end})>[];
  for (final item in items) {
    if (item is! Map<String, dynamic>) continue;
    final start = DateTime.tryParse(item['StartDate']?.toString() ?? '');
    final end = DateTime.tryParse(item['EndDate']?.toString() ?? '');
    if (start == null || end == null || !end.isAfter(start)) continue;
    valid.add((item: item, start: start, end: end));
  }
  valid.sort((a, b) => a.start.compareTo(b.start));
  Map<String, dynamic>? current;
  DateTime? currentEnd;
  for (final entry in valid) {
    if (!clock.isBefore(entry.start) && clock.isBefore(entry.end)) {
      current = entry.item;
      currentEnd = entry.end;
    }
  }
  for (final entry in valid) {
    if (entry.start.isAfter(clock) &&
        (currentEnd == null || !entry.start.isBefore(currentEnd))) {
      return (now: current, next: entry.item);
    }
  }
  return (now: current, next: null);
}
