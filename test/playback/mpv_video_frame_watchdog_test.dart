import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/playback/mpv_video_frame_watchdog.dart';

void main() {
  test('fresh render samples count; redraw, playback clocks and malformed data do not', () {
    const first =
        '{"fresh":[{"desc":"upload","samples":[12,13]}],"redraw":[1]}';
    expect(freshVideoFrameSignal(first), isNotNull);
    expect(
      freshVideoFrameSignal(first.replaceFirst('[1]', '[22]')),
      freshVideoFrameSignal(first),
    );
    expect(
      freshVideoFrameSignal(first.replaceFirst('[12,13]', '[13,14]')),
      isNot(freshVideoFrameSignal(first)),
    );
    for (final raw in [
      null,
      '',
      '{}',
      '{"fresh":[]}',
      '{"fresh":[{"samples":[]}]}',
      '{"fresh":[{"samples":["oops"]}]}',
    ]) {
      expect(freshVideoFrameSignal(raw), isNull);
    }
  });

  late MpvVideoFrameWatchdog watch;
  late Duration now;
  late bool eligible;
  late String? signal;
  late List<bool> changes;
  setUp(() {
    now = Duration.zero;
    eligible = true;
    signal = 'frame-a';
    changes = [];
    watch = MpvVideoFrameWatchdog(
      eligible: () => eligible,
      readSignal: () async => signal,
      onFrozenChanged: changes.add,
      now: () => now,
    )..start();
  });
  tearDown(() => watch.stop());

  test(
    'detects stopped video even with no playing/buffering transition',
    () async {
      await watch.check();
      now = const Duration(seconds: 14);
      await watch.check();
      expect(watch.advancing, false);
      expect(changes, isEmpty);
      now = const Duration(seconds: 16);
      await watch.check();
      await watch.check();
      expect(changes, [true]);
      signal = 'new-fresh-frame';
      await watch.check();
      expect(watch.advancing, true);
      expect(changes, [true, false]);
    },
  );
  test(
    'ongoing fresh frames and still-picture content do not freeze',
    () async {
      for (var i = 0; i < 40; i++) {
        now = Duration(seconds: i * 2);
        signal = 'fresh render samples $i';
        await watch.check();
      }
      expect(changes, isEmpty);
    },
  );
  test('zero-frame startup gets 30s, then normal stalls use 15s', () async {
    watch.stop();
    var seen = false;
    watch = MpvVideoFrameWatchdog(
      eligible: () => eligible,
      readSignal: () async => signal,
      onFrozenChanged: changes.add,
      frameSeen: () => seen,
      now: () => now,
    )..start();
    signal = 'texture:0';
    await watch.check();
    now = const Duration(seconds: 20);
    await watch.check();
    expect(changes, isEmpty);
    now = const Duration(seconds: 31);
    await watch.check();
    expect(changes, [true]);
    seen = true;
    signal = 'texture:1';
    await watch.check();
    now += const Duration(seconds: 16);
    await watch.check();
    expect(changes, [true, false, true]);
  });
  test('status remains observable during a pending read without queueing more reads', () async {
    watch.stop();
    final pending = Completer<String?>();
    var reads = 0;
    final status = <String>[];
    watch = MpvVideoFrameWatchdog(
      eligible: () => eligible,
      readSignal: () {
        reads++;
        return pending.future;
      },
      onFrozenChanged: changes.add,
      now: () => now,
      onCheck: () => status.add(watch.diagnostics),
    );
    watch.start();
    final first = watch.check();
    await watch.check();
    expect(reads, 1);
    expect(status.last, contains('busy=true'));
    pending.complete('fresh');
    await first;
    expect(status.last, contains('busy=false'));
  });
  test('a failed diagnostic callback cannot disable freeze recovery', () async {
    watch.stop();
    watch = MpvVideoFrameWatchdog(
      eligible: () => eligible,
      readSignal: () async => signal,
      onFrozenChanged: changes.add,
      now: () => now,
      onCheck: () => throw StateError('observer failed'),
    )..start();
    await watch.check();
    now = const Duration(seconds: 16);
    await watch.check();
    expect(changes, [true]);
  });
  test('only real new-frame activity proves recovery; identical samples do not', () async {
    watch.stop();
    var proofs = 0;
    var seen = false;
    watch = MpvVideoFrameWatchdog(eligible: () => eligible,
      readSignal: () async => signal, onFrozenChanged: changes.add,
      frameSeen: () => seen, onProgress: () => proofs++, now: () => now)..start();
    await watch.check();
    expect(proofs, 0);
    seen = true;
    signal = 'new frame';
    await watch.check();
    await watch.check();
    expect(proofs, 1);
    signal = 'next frame';
    await watch.check();
    expect(proofs, 2);
  });
  test(
    'pause, audio-only, background, buffering and seeking discard elapsed time',
    () async {
      await watch.check();
      eligible = false;
      now = const Duration(minutes: 4);
      await watch.check();
      eligible = true;
      await watch.check();
      expect(changes, isEmpty);
      now += const Duration(seconds: 14);
      await watch.check();
      expect(changes, isEmpty);
    },
  );
  test('missing/unsupported telemetry never fabricates a freeze', () async {
    await watch.check();
    now = const Duration(minutes: 2);
    signal = null;
    await watch.check();
    signal = 'frame-a';
    await watch.check();
    expect(changes, isEmpty);
  });
  test(
    'a delayed old-session read cannot recover a new session or stopped player',
    () async {
      watch.stop();
      final pending = Completer<String?>();
      var reads = 0;
      watch = MpvVideoFrameWatchdog(
        eligible: () => eligible,
        readSignal: () {
          reads++;
          return pending.future;
        },
        onFrozenChanged: changes.add,
        now: () => now,
      )..start();
      final sample = watch.check();
      await watch.check();
      expect(reads, 1);
      watch.stop();
      watch.start();
      now = const Duration(minutes: 10);
      pending.complete('old-frame');
      await sample;
      expect(changes, isEmpty);
      watch.stop();
      await watch.check();
      expect(reads, 1);
    },
  );
}
