import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/spesh_playback_health.dart';

void main() {
  final now = DateTime.utc(2026, 9, 30);
  Map entry(String state, {String id = 'abc', int seconds = 0}) => {
    'ItemId': id, 'State': state, 'Updated': now.subtract(Duration(seconds: seconds)).toIso8601String(),
    'Message': 'password=secret https://private/token',
  };
  test('stream limits have an actionable safe message', () {
    final text = speshPlaybackMessage([entry('StreamLimit')], 'abc', now)!;
    expect(text, contains('Stop another stream'));
    expect(text, isNot(contains('secret')));
  });
  test('authorization does not suggest a provider outage', () {
    expect(speshPlaybackMessage([entry('Authorization')], 'abc', now), contains('administrator attention'));
  });
  test('stale future and other item reports are ignored', () {
    expect(speshPlaybackMessage([entry('ProviderAccess', seconds: 31), entry('ProviderAccess', seconds: -1), entry('ProviderAccess', id: 'other')], 'abc', now), isNull);
  });
  test('newer playing report supersedes old failure regardless of ordering', () {
    expect(speshPlaybackMessage([entry('ProviderAccess', seconds: 5), entry('Playing')], 'abc', now), isNull);
  });
}
