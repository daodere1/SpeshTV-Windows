import 'dart:async';

class CalendarSourceSnapshot<T> {
  CalendarSourceSnapshot(
    Map<String, List<T>> sources,
    Map<String, Object> failures,
    this.refreshing,
  ) : sources = Map.unmodifiable(
        sources.map(
          (key, values) => MapEntry(key, List<T>.unmodifiable(values)),
        ),
      ),
      failures = Map.unmodifiable(failures);
  final Map<String, List<T>> sources;
  final Map<String, Object> failures;
  final bool refreshing;
}

/// Small in-memory metadata cache. The caller scopes this loader to the active
/// server client and keys scopes by member/config/month, never by credentials.
class CalendarSourceLoader<T> {
  CalendarSourceLoader({DateTime Function()? now}) : now = now ?? DateTime.now;
  final DateTime Function() now;
  static const freshFor = Duration(minutes: 2);
  static const retainFor = Duration(minutes: 15);
  final _cache = <String, ({DateTime at, List<T> items})>{};
  final _inFlight = <String, Future<List<T>>>{};

  Stream<CalendarSourceSnapshot<T>> load({
    required String scope,
    required Map<String, Future<List<T>> Function()> sources,
    bool force = false,
    bool Function(Object error)? discardOnFailure,
  }) async* {
    final result = <String, List<T>>{};
    final failures = <String, Object>{};
    final pending = <String, Future<List<T>> Function()>{};
    for (final entry in sources.entries) {
      final key = '$scope|${entry.key}';
      final cached = _cache[key];
      final age = cached == null ? null : now().difference(cached.at);
      if (cached != null && age! >= Duration.zero && age <= retainFor) {
        result[entry.key] = cached.items;
      }
      if (force || cached == null || age! < Duration.zero || age > freshFor) {
        pending[entry.key] = entry.value;
      }
    }
    yield CalendarSourceSnapshot(result, failures, pending.isNotEmpty);
    if (pending.isEmpty) return;
    final updates = StreamController<CalendarSourceSnapshot<T>>();
    var remaining = pending.length;
    for (final entry in pending.entries) {
      final key = '$scope|${entry.key}';
      final fetch = _inFlight.putIfAbsent(key, () => Future.sync(entry.value));
      unawaited(() async {
        try {
          final items = List<T>.unmodifiable(await fetch);
          result[entry.key] = items;
          _cache.remove(key);
          _cache[key] = (at: now(), items: items);
          while (_cache.length > 36) {
            _cache.remove(_cache.keys.first);
          }
        } catch (error) {
          failures[entry.key] = error;
          if (discardOnFailure?.call(error) ?? false) {
            result.remove(entry.key);
            _cache.remove(key);
          }
        } finally {
          if (identical(_inFlight[key], fetch)) _inFlight.remove(key);
          remaining--;
          if (!updates.isClosed)
            updates.add(
              CalendarSourceSnapshot(result, failures, remaining > 0),
            );
          if (remaining == 0) await updates.close();
        }
      }());
    }
    try {
      yield* updates.stream;
    } finally {
      if (!updates.isClosed) unawaited(updates.close());
    }
  }
}
