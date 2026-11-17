import 'dart:async';

import 'calendar_source_loader.dart';

/// Owns only the current page request, not a device schedule cache. Each refresh
/// reads Core again with the caller's current Jellyfin session/permissions.
class CalendarSnapshotSession<T> {
  StreamSubscription<CalendarSourceSnapshot<T>>? _subscription;
  int _generation = 0;
  bool _disposed = false;
  bool isRefreshing = false;
  String? _scope;
  final Map<String, List<T>> _displayed = {};

  void refresh({
    required Map<String, Future<List<T>> Function()> sources,
    required void Function(CalendarSourceSnapshot<T>) onSnapshot,
    String scope = '',
    bool preserveRows = false,
    bool Function(Object)? discardOnFailure,
  }) {
    if (_disposed) return;
    final generation = ++_generation;
    isRefreshing = true;
    if (!preserveRows || _scope != scope) _displayed.clear();
    _scope = scope;
    _displayed.removeWhere((source, _) => !sources.containsKey(source));
    unawaited(_subscription?.cancel());
    // A fresh one-shot loader retains no result for a subsequent page request.
    _subscription = CalendarSourceLoader<T>()
        .load(scope: 'request-$generation', sources: sources, force: true)
        .listen((snapshot) {
          if (_disposed || generation != _generation) return;
          _displayed.addAll(snapshot.sources);
          for (final failure in snapshot.failures.entries) {
            if (discardOnFailure?.call(failure.value) ?? false)
              _displayed.remove(failure.key);
          }
          isRefreshing = snapshot.refreshing;
          onSnapshot(
            CalendarSourceSnapshot(
              _displayed,
              snapshot.failures,
              snapshot.refreshing,
            ),
          );
        });
  }

  void pause() {
    _generation++;
    isRefreshing = false;
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  void dispose() {
    _disposed = true;
    pause();
    _displayed.clear();
  }
}
