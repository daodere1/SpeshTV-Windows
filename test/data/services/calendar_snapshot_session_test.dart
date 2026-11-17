import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/calendar_snapshot_session.dart';

void main() {
  test('refresh reads Core again, with no device result reuse', () async {
    final session = CalendarSnapshotSession<int>();
    addTearDown(session.dispose);
    var calls = 0;
    for (var n = 1; n <= 2; n++) {
      final done = Completer<void>();
      session.refresh(
        sources: {
          'Core': () async => [++calls],
        },
        onSnapshot: (value) {
          if (!value.refreshing) {
            expect(value.sources['Core'], [n]);
            done.complete();
          }
        },
      );
      await done.future;
    }
    expect(calls, 2);
  });
  test('new request supersedes slow old results without waiting', () async {
    final session = CalendarSnapshotSession<String>();
    addTearDown(session.dispose);
    final slow = Completer<List<String>>();
    final started = Completer<void>();
    final values = <String>[];
    session.refresh(
      sources: {
        'Core': () {
          started.complete();
          return slow.future;
        },
      },
      onSnapshot: (s) => values.addAll(s.sources.values.expand((x) => x)),
    );
    await started.future;
    final done = Completer<void>();
    session.refresh(
      sources: {
        'Core': () async => ['new'],
      },
      onSnapshot: (s) {
        values.addAll(s.sources.values.expand((x) => x));
        if (!s.refreshing) done.complete();
      },
    );
    await done.future.timeout(const Duration(seconds: 2));
    slow.complete(['old']);
    await Future<void>.delayed(Duration.zero);
    expect(values, ['new']);
  });
  test('slow or failed source does not hide successful source', () async {
    final session = CalendarSnapshotSession<String>();
    addTearDown(session.dispose);
    final slow = Completer<List<String>>();
    final fast = Completer<void>();
    final done = Completer<void>();
    session.refresh(
      sources: {
        'TV': () => slow.future,
        'Movies': () async => ['movie'],
      },
      onSnapshot: (s) {
        if (s.sources.containsKey('Movies') && !fast.isCompleted)
          fast.complete();
        if (!s.refreshing) {
          expect(s.sources['Movies'], ['movie']);
          expect(s.failures.containsKey('TV'), true);
          done.complete();
        }
      },
    );
    await fast.future;
    expect(slow.isCompleted, false);
    slow.completeError(StateError('unavailable'));
    await done.future;
  });
  test('disposed page ignores a pending server response', () async {
    final session = CalendarSnapshotSession<int>();
    final pending = Completer<List<int>>();
    final started = Completer<void>();
    var updates = 0;
    session.refresh(
      sources: {
        'Core': () {
          started.complete();
          return pending.future;
        },
      },
      onSnapshot: (_) => updates++,
    );
    await started.future;
    session.dispose();
    final before = updates;
    pending.complete([1]);
    await Future<void>.delayed(Duration.zero);
    expect(updates, before);
  });
}
