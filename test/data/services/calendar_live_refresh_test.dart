import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/calendar_refresh_loop.dart';
import 'package:moonfin/data/services/calendar_snapshot_session.dart';

void main() {
  test('visible poll runs every minute, skips busy, pauses and disposes', () {
    fakeAsync((clock) {
      var count = 0;
      var busy = false;
      final loop = CalendarRefreshLoop(
        onRefresh: () => count++,
        isBusy: () => busy,
      );
      loop.setActive(true);
      clock.elapse(const Duration(seconds: 59));
      expect(count, 0);
      clock.elapse(const Duration(seconds: 1));
      expect(count, 1);
      busy = true;
      clock.elapse(const Duration(minutes: 2));
      expect(count, 1);
      loop.setActive(false);
      busy = false;
      clock.elapse(const Duration(minutes: 2));
      expect(count, 1);
      loop.setActive(true);
      clock.elapse(const Duration(minutes: 1));
      expect(count, 2);
      loop.dispose();
      clock.elapse(const Duration(minutes: 1));
      expect(count, 2);
    });
  });
  test('view rows persist while independent sources refresh, with current scope only', () async {
    final session = CalendarSnapshotSession<int>();
    addTearDown(session.dispose);
    Future<void> first() async {
      final done = Completer<void>();
      session.refresh(
        scope: 'member1',
        preserveRows: true,
        sources: {
          'TV': () async => [1],
          'Movies': () async => [2],
        },
        onSnapshot: (s) {
          if (!s.refreshing) done.complete();
        },
      );
      await done.future;
    }

    await first();
    final slow = Completer<List<int>>();
    final fast = Completer<void>();
    final done = Completer<void>();
    session.refresh(
      scope: 'member1',
      preserveRows: true,
      sources: {
        'TV': () => slow.future,
        'Movies': () async => [3],
      },
      onSnapshot: (s) {
        if (s.sources['Movies']?.single == 3 && !fast.isCompleted) {
          expect(s.sources['TV'], [1]);
          fast.complete();
        }
        if (!s.refreshing) {
          expect(s.sources['TV'], [4]);
          done.complete();
        }
      },
    );
    await fast.future;
    slow.complete([4]);
    await done.future;
    final emptySeen = Completer<void>();
    session.refresh(
      scope: 'member2',
      preserveRows: true,
      sources: {
        'TV': () async => [5],
      },
      onSnapshot: (s) {
        if (s.refreshing) {
          expect(s.sources, isEmpty);
          emptySeen.complete();
        }
      },
    );
    await emptySeen.future;
  });
  test(
    'revoked source is removed rather than retaining prior-member availability',
    () async {
      final session = CalendarSnapshotSession<int>();
      addTearDown(session.dispose);
      final first = Completer<void>();
      session.refresh(
        scope: 'member',
        preserveRows: true,
        sources: {
          'TV': () async => [1],
        },
        onSnapshot: (s) {
          if (!s.refreshing) first.complete();
        },
      );
      await first.future;
      final next = Completer<void>();
      session.refresh(
        scope: 'member',
        preserveRows: true,
        discardOnFailure: (_) => true,
        sources: {'TV': () async => throw StateError('permission')},
        onSnapshot: (s) {
          if (!s.refreshing) {
            expect(s.sources, isEmpty);
            next.complete();
          }
        },
      );
      await next.future;
    },
  );
}
