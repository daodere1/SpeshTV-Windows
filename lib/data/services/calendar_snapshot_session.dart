import 'dart:async';

import 'calendar_source_loader.dart';

/// Owns only the current page request, not a device schedule cache. Each refresh
/// reads Core again with the caller's current Jellyfin session/permissions.
class CalendarSnapshotSession<T> {
  StreamSubscription<CalendarSourceSnapshot<T>>? _subscription;
  int _generation = 0;
  bool _disposed = false;

  void refresh({
    required Map<String, Future<List<T>> Function()> sources,
    required void Function(CalendarSourceSnapshot<T>) onSnapshot,
  }) {
    if (_disposed) return;
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    // A fresh one-shot loader retains no result for a subsequent page request.
    _subscription = CalendarSourceLoader<T>()
        .load(scope: 'request-$generation', sources: sources, force: true)
        .listen((snapshot) {
          if (!_disposed && generation == _generation) onSnapshot(snapshot);
        });
  }

  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}
