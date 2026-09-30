import 'package:flutter_test/flutter_test.dart';
import '../lib/playback/live_stall_watchdog.dart';

void main() {
  test('stalls reconnect twice then stop automatic retries', () {
    final watchdog = LiveStallWatchdog()..reset(Duration.zero);
    const position = Duration(seconds: 1);
    expect(watchdog.sample(Duration.zero, position, active: true), LiveStallAction.none);
    expect(watchdog.sample(const Duration(seconds: 12), position, active: true), LiveStallAction.reconnect);
    watchdog.sample(const Duration(seconds: 13), position, active: true);
    expect(watchdog.sample(const Duration(seconds: 25), position, active: true), LiveStallAction.reconnect);
    watchdog.sample(const Duration(seconds: 26), position, active: true);
    expect(watchdog.sample(const Duration(seconds: 38), position, active: true), LiveStallAction.exhausted);
    expect(watchdog.sample(const Duration(seconds: 90), position, active: true), LiveStallAction.none);
  });
  test('pause and background time do not count as stalls', () {
    final watchdog = LiveStallWatchdog()..reset(Duration.zero);
    watchdog.sample(Duration.zero, Duration.zero, active: true);
    expect(watchdog.sample(const Duration(seconds: 90), Duration.zero, active: false), LiveStallAction.none);
    expect(watchdog.sample(const Duration(seconds: 91), Duration.zero, active: true), LiveStallAction.none);
  });
  test('channel change resets retry budget and clock', () {
    final watchdog = LiveStallWatchdog()..reset(Duration.zero);
    watchdog.sample(Duration.zero, const Duration(seconds: 1), active: true);
    watchdog.sample(const Duration(seconds: 12), const Duration(seconds: 1), active: true);
    expect(watchdog.attempts, 1);
    watchdog.reset(const Duration(seconds: 50));
    expect(watchdog.attempts, 0);
    expect(watchdog.sample(const Duration(seconds: 51), Duration.zero, active: true), LiveStallAction.none);
  });
  test('healthy progress restores retry budget', () {
    final watchdog = LiveStallWatchdog()..reset(Duration.zero);
    watchdog.sample(Duration.zero, const Duration(seconds: 1), active: true);
    watchdog.sample(const Duration(seconds: 12), const Duration(seconds: 1), active: true);
    expect(watchdog.attempts, 1);
    for (var i = 13; i <= 44; i++) {
      expect(watchdog.sample(Duration(seconds: i), Duration(seconds: i), active: true), LiveStallAction.none);
    }
    expect(watchdog.attempts, 0);
  });
  test('initial loading gets a longer grace period', () {
    final watchdog = LiveStallWatchdog()..reset(Duration.zero);
    watchdog.sample(Duration.zero, Duration.zero, active: true);
    expect(watchdog.sample(const Duration(seconds: 12), Duration.zero, active: true), LiveStallAction.none);
    expect(watchdog.sample(const Duration(seconds: 30), Duration.zero, active: true), LiveStallAction.reconnect);
  });
  test('isolated progress after a long wait does not restore the retry budget', () {
    final watchdog = LiveStallWatchdog()..reset(Duration.zero);
    watchdog.sample(Duration.zero, const Duration(seconds: 1), active: true);
    watchdog.sample(const Duration(seconds: 12), const Duration(seconds: 1), active: true);
    watchdog.sample(const Duration(seconds: 13), Duration.zero, active: true);
    watchdog.sample(const Duration(seconds: 40), const Duration(seconds: 1), active: true);
    expect(watchdog.attempts, 1);
  });
}
