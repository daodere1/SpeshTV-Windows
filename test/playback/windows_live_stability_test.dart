import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/playback/windows_live_stability.dart';

void main() {
  late Duration now;
  late WindowsLiveRebufferWatch watch;
  setUp(() {
    now = Duration.zero;
    watch = WindowsLiveRebufferWatch(now: () => now)..beginSession(1);
  });
  bool pause(int seconds) {
    watch.observe(true, allowed: true);
    now += Duration(seconds: seconds);
    return watch.observe(false, allowed: true);
  }

  bool burst() {
    now += const Duration(seconds: 21);
    var result = false;
    for (var i = 0; i < 3; i++) {
      result = pause(2);
      now += const Duration(seconds: 2);
    }
    return result;
  }

  test('three genuine short pauses totaling six seconds trigger one stability rejoin', () {
    expect(burst(), true);
    expect(watch.diagnostics, contains('stabilityRejoins=1'));
  });
  test('startup and isolated pauses do not cause retunes', () {
    expect(pause(3), false);
    expect(pause(3), false);
    now = const Duration(seconds: 21);
    expect(pause(5), false);
    now += const Duration(seconds: 61);
    expect(pause(2), false);
    expect(watch.diagnostics, contains('rebufferEpisodes=1'));
  });
  test('pause/background/seek invalidate the buffered duration', () {
    now = const Duration(seconds: 21);
    watch.observe(true, allowed: true);
    now += const Duration(minutes: 3);
    watch.observe(false, allowed: false);
    expect(watch.diagnostics, contains('rebufferMs=0'));
    expect(watch.recentlyInterrupted, false);
  });
  test('automatic reopens preserve cooldown and a two-rejoin viewing-session limit', () {
    expect(burst(), true);
    watch.beginSession(1);
    expect(burst(), false);
    now += const Duration(minutes: 2);
    watch.beginSession(1);
    expect(burst(), true);
    now += const Duration(minutes: 3);
    watch.beginSession(1);
    expect(burst(), false);
    watch.beginSession(2);
    expect(burst(), true);
  });
  test('short buffering blocks recovery proof until playback has been stable for 20s', () {
    now = const Duration(seconds: 21);
    expect(pause(2), false);
    expect(watch.recentlyInterrupted, true);
    now += const Duration(seconds: 21);
    expect(watch.recentlyInterrupted, false);
  });

  test('live cache runway restores exact prior options before movies/custom configuration', () async {
    final properties = {
      'cache': 'auto',
      'cache-pause': 'yes',
      'cache-pause-wait': '1',
      'cache-pause-initial': 'no',
    };
    final original = Map<String, String>.from(properties);
    final policy = WindowsLiveBufferPolicy(
      read: (k) async => properties[k],
      write: (k, v) async {
        properties[k] = v;
      },
    );
    await policy.apply(enabled: true, owns: () => true);
    expect(properties['cache-pause-wait'], '3');
    expect(properties['cache-pause-initial'], 'yes');
    await policy.apply(enabled: false, owns: () => true);
    expect(properties, original);
  });
  test('unknown cache defaults are never changed irreversibly', () async {
    var writes = 0;
    final policy = WindowsLiveBufferPolicy(
      read: (_) async => null,
      write: (_, __) async {
        writes++;
      },
    );
    await policy.apply(enabled: true, owns: () => true);
    expect(writes, 0);
  });
  test('a stale configuration read cannot overwrite the next source', () async {
    final pending = Completer<String?>();
    var generation = 1;
    var writes = 0;
    final policy = WindowsLiveBufferPolicy(
      read: (_) => pending.future,
      write: (_, __) async {
        writes++;
      },
    );
    final first = policy.apply(enabled: true, owns: () => generation == 1);
    await Future<void>.delayed(Duration.zero);
    generation = 2;
    final next = policy.apply(enabled: false, owns: () => generation == 2);
    pending.complete('auto');
    await first;
    await next;
    expect(writes, 0);
  });
}
