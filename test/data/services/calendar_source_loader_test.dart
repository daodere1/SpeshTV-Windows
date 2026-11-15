import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/calendar_source_loader.dart';

void main() {
  test('leaving a page does not wait for the slow source; returning shares it', () async {
    final loader = CalendarSourceLoader<int>();
    final slow = Completer<List<int>>();
    final started = Completer<void>();
    var calls = 0;
    final sources = {'calendar': () { calls++; if (!started.isCompleted) started.complete(); return slow.future; }};
    final subscription = loader.load(scope: 'a', sources: sources).listen((_) {});
    await started.future;
    await subscription.cancel().timeout(const Duration(seconds: 2));
    final next = loader.load(scope: 'a', sources: sources).toList();
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    slow.complete([1]);
    expect((await next).last.sources['calendar'], [1]);
  });
  test('fast source displays before a slow source completes', () async {
    final loader = CalendarSourceLoader<String>();
    final slow = Completer<List<String>>();
    final fastShown = Completer<void>();
    final finished = Completer<void>();
    final updates = <CalendarSourceSnapshot<String>>[];
    loader.load(scope: 'member/month', sources: {
      'fast': () async => ['episode'], 'slow': () => slow.future,
    }).listen((snapshot) {
      updates.add(snapshot);
      if (snapshot.sources.containsKey('fast') && !fastShown.isCompleted) fastShown.complete();
    }, onDone: finished.complete);
    await fastShown.future.timeout(const Duration(seconds: 2));
    expect(slow.isCompleted, false);
    expect(updates.last.refreshing, true);
    slow.complete(['film']);
    await finished.future;
    expect(updates.last.refreshing, false);
    expect(updates.last.sources['slow'], ['film']);
  });

  test('fresh cache avoids requests; manual refresh replaces it', () async {
    final loader = CalendarSourceLoader<int>();
    var calls = 0;
    final sources = {'calendar': () async => [++calls]};
    await loader.load(scope: 'a', sources: sources).drain<void>();
    final cached = await loader.load(scope: 'a', sources: sources).toList();
    expect(calls, 1);
    expect(cached.single.refreshing, false);
    expect(cached.single.sources['calendar'], [1]);
    final refreshed = await loader.load(scope: 'a', sources: sources, force: true).last;
    expect(calls, 2);
    expect(refreshed.sources['calendar'], [2]);
  });

  test('member/month scopes never reuse one another', () async {
    final loader = CalendarSourceLoader<String>();
    await loader.load(scope: 'member-a/nov', sources: {'calendar': () async => ['private-a']}).drain<void>();
    final results = await loader.load(scope: 'member-b/nov', sources: {'calendar': () async => ['private-b']}).toList();
    expect(results.first.sources, isEmpty);
    expect(results.last.sources['calendar'], ['private-b']);
  });

  test('stale rows remain visible on failure, but authorization refusal discards them', () async {
    var now = DateTime(2026, 11, 14);
    final loader = CalendarSourceLoader<String>(now: () => now);
    await loader.load(scope: 'a', sources: {'calendar': () async => ['saved']}).drain<void>();
    now = now.add(const Duration(minutes: 3));
    final failed = await loader.load(scope: 'a', sources: {'calendar': () async => throw Exception('offline')}).toList();
    expect(failed.first.sources['calendar'], ['saved']);
    expect(failed.last.failures.keys, ['calendar']);
    final denied = await loader.load(scope: 'a', force: true,
      discardOnFailure: (error) => error is StateError,
      sources: {'calendar': () async => throw StateError('forbidden')}).last;
    expect(denied.sources, isEmpty);
  });

  test('concurrent refreshes share one in-flight request', () async {
    final loader = CalendarSourceLoader<int>();
    final pending = Completer<List<int>>();
    var calls = 0;
    final sources = {'calendar': () { calls++; return pending.future; }};
    final one = loader.load(scope: 'a', sources: sources).toList();
    final two = loader.load(scope: 'a', sources: sources).toList();
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    pending.complete([1]);
    await Future.wait([one, two]);
  });
}
