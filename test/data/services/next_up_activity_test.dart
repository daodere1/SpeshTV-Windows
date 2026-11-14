import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/utils/next_up_enrichment.dart';
import 'package:moonfin/data/models/aggregated_item.dart';

void main() {
  test('merged feeds interleave by timezone-aware activity', () {
    AggregatedItem item(String id, String feed, String? date) => AggregatedItem(
      id: id, serverId: 'server', rawData: {
        'SpeshProgressFeed': feed, 'UserData': {'LastPlayedDate': date},
      });
    final items = [
      item('resume', 'resume', '2026-10-12T18:00:00Z'),
      item('next', 'nextUp', '2026-10-12T15:00:00-04:00'),
      item('unknown', 'nextUp', null),
    ]..sort(compareProgressActivity);
    expect(items.map((i) => i.id), ['next', 'resume', 'unknown']);
  });
  test('viewing activity wins over import date', () {
    final played = DateTime.utc(2026, 10, 1);
    expect(nextUpActivityDate(played, DateTime.utc(2026, 10, 12)), played);
  });
  test('unknown activity falls back to available creation date', () {
    final added = DateTime.utc(2026, 10, 12);
    expect(nextUpActivityDate(null, added), added);
    expect(nextUpActivityDate(null, null), isNull);
  });
}
