import 'dart:collection';

/// Small in-memory cache; callers scope its owner to an authenticated client.
class SessionRequestCache<T> {
  SessionRequestCache({this.capacity = 8, DateTime Function()? now})
      : _now = now ?? DateTime.now;
  final int capacity;
  final DateTime Function() _now;
  final _values = LinkedHashMap<String, ({T value, DateTime saved})>();
  final _pending = <String, Future<T>>{};

  T? peek(String key, {required Duration maxAge}) {
    final entry = _values[key];
    if (entry == null || _now().difference(entry.saved) > maxAge) return null;
    return entry.value;
  }

  Future<T> load(String key, Future<T> Function() fetch, {
    Duration ttl = Duration.zero, bool force = false,
  }) {
    if (!force) {
      final cached = peek(key, maxAge: ttl);
      if (cached != null) return Future.value(cached);
    }
    return _pending[key] ??= Future<T>.sync(fetch).then((value) {
      _values.remove(key);
      _values[key] = (value: value, saved: _now());
      while (_values.length > capacity) { _values.remove(_values.keys.first); }
      return value;
    }).whenComplete(() { _pending.remove(key); });
  }
}
