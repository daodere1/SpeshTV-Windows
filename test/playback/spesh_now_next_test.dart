import 'package:flutter_test/flutter_test.dart';
import '../../lib/playback/spesh_now_next.dart';

void main() {
  final clock = DateTime.utc(2026, 9, 30, 12);
  Map<String, dynamic> programme(String name, int start, int end) => {
    'Name': name,
    'StartDate': clock.add(Duration(minutes: start)).toIso8601String(),
    'EndDate': clock.add(Duration(minutes: end)).toIso8601String(),
  };
  test('sorts guide and excludes expired or overlapping next programmes', () {
    final result = speshNowNext([
      programme('Next', 20, 40), programme('Old', -40, -20),
      programme('Overlap', 10, 15), programme('Now', -10, 20),
    ], clock);
    expect(result.now?['Name'], 'Now');
    expect(result.next?['Name'], 'Next');
  });
  test('future programme is not presented as now', () {
    final result = speshNowNext([programme('Future', 10, 30)], clock);
    expect(result.now, isNull);
    expect(result.next?['Name'], 'Future');
  });
  test('end boundary is exclusive and malformed entries are ignored', () {
    final result = speshNowNext([
      null, {'StartDate': 'bad'}, programme('Ended', -20, 0),
      programme('Current', 0, 20),
    ], clock);
    expect(result.now?['Name'], 'Current');
    expect(result.next, isNull);
  });
}
