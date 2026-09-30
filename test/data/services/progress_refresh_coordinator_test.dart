import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_core/server_core.dart';
import 'package:moonfin/data/services/progress_refresh_coordinator.dart';

void main() {
  void scenario(
    void Function(
      FakeAsync,
      StreamController<ServerWebSocketMessage>,
      StreamController<void>,
      ProgressRefreshCoordinator,
      List<String>,
    )
    run, {
    Future<void> Function()? refresh,
    List<bool>? identityInvalidations,
  }) {
    fakeAsync((clock) {
      final events = StreamController<ServerWebSocketMessage>.broadcast(
        sync: true,
      );
      final connections = StreamController<void>.broadcast(sync: true);
      final calls = <String>[];
      final coordinator = ProgressRefreshCoordinator(
        userId: 'AA-BB',
        events: events.stream,
        connections: connections.stream,
        enabled: () => true,
        invalidate: (identities) {
          calls.add('invalidate');
          identityInvalidations?.add(identities);
        },
        refresh: () async {
          calls.add('refresh');
          await refresh?.call();
        },
      );
      coordinator.setActive(true);
      run(clock, events, connections, coordinator, calls);
      coordinator.dispose();
      unawaited(events.close());
      unawaited(connections.close());
      clock.flushMicrotasks();
    });
  }

  test(
    'current-user events invalidate immediately and bursts refresh once',
    () {
      scenario((clock, events, connections, coordinator, calls) {
        events.add(UserDataChangedMessage(userId: 'other', itemIds: ['one']));
        expect(calls, isEmpty);
        for (var i = 0; i < 5; i++) {
          events.add(
            UserDataChangedMessage(userId: 'aabb', itemIds: ['new-item']),
          );
        }
        expect(calls.where((c) => c == 'invalidate').length, 5);
        expect(calls.contains('refresh'), false);
        clock.elapse(const Duration(seconds: 2));
        expect(calls.where((c) => c == 'refresh').length, 1);
      });
    },
  );
  test('library changes and reconnects revalidate the row', () {
    final identities = <bool>[];
    scenario((clock, events, connections, coordinator, calls) {
      events.add(const LibraryChangedMessage(itemsAdded: ['new-local-copy']));
      clock.elapse(const Duration(seconds: 2));
      connections.add(null);
      clock.elapse(const Duration(seconds: 2));
      expect(calls, ['invalidate', 'refresh', 'invalidate', 'refresh']);
    }, identityInvalidations: identities);
    expect(identities, [true, true]);
  });
  test('hidden Home invalidates without polling and refreshes on return', () {
    scenario((clock, events, connections, coordinator, calls) {
      coordinator.setActive(false);
      events.add(UserDataChangedMessage(userId: 'aabb'));
      clock.elapse(const Duration(minutes: 3));
      expect(calls, ['invalidate']);
      coordinator.setActive(true);
      clock.elapse(const Duration(seconds: 2));
      expect(calls, ['invalidate', 'refresh']);
    });
  });
  test('fallback refreshes visible Home, and dispose stops future work', () {
    scenario((clock, events, connections, coordinator, calls) {
      clock.elapse(const Duration(seconds: 62));
      expect(calls, ['refresh']);
      coordinator.dispose();
      clock.elapse(const Duration(minutes: 5));
      events.add(UserDataChangedMessage(userId: 'aabb'));
      expect(calls.length, 1);
    });
  });
  test('events during a request queue only one follow-up', () {
    late Completer<void> request;
    scenario((clock, events, connections, coordinator, calls) {
      request = Completer<void>();
      coordinator.changed();
      clock.elapse(const Duration(seconds: 2));
      coordinator.changed();
      coordinator.changed();
      clock.elapse(const Duration(seconds: 5));
      expect(calls.where((c) => c == 'refresh').length, 1);
      request.complete();
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 2));
      expect(calls.where((c) => c == 'refresh').length, 2);
    }, refresh: () => request.future);
  });
  test('a failed request does not prevent the next fallback', () {
    scenario((clock, events, connections, coordinator, calls) {
      coordinator.changed();
      clock.elapse(const Duration(seconds: 62));
      expect(calls.where((c) => c == 'refresh').length, 2);
    }, refresh: () async => throw StateError('offline'));
  });
}
