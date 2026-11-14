import 'dart:async';

import 'package:server_core/server_core.dart';

/// Reuses the session socket. No polling or refresh requests while Home is
/// hidden, but changes still invalidate the persisted snapshot immediately.
class ProgressRefreshCoordinator {
  final String userId;
  final bool Function() enabled;
  final void Function(bool libraryChanged) invalidate;
  final Future<void> Function() refresh;
  final Future<void> Function()? refreshLibrary;
  final Duration debounce;
  late final StreamSubscription<ServerWebSocketMessage> _events;
  late final StreamSubscription<void> _connections;
  late final Timer _fallback;
  Timer? _scheduled;
  bool _active = false, _disposed = false, _pending = false, _inFlight = false;
  bool _libraryPending = false;
  int _fallbackTicks = 0;

  ProgressRefreshCoordinator({
    required this.userId,
    required Stream<ServerWebSocketMessage> events,
    required Stream<void> connections,
    required this.enabled,
    required this.invalidate,
    required this.refresh,
    this.refreshLibrary,
    this.debounce = const Duration(seconds: 2),
    Duration fallbackInterval = const Duration(minutes: 1),
  }) {
    _events = events.listen(_onEvent);
    _connections = connections.listen((_) => changed(libraryChanged: true));
    _fallback = Timer.periodic(fallbackInterval, (_) {
      // A timer is not evidence of changed data. Do not discard a slow cold
      // fetch or erase the last good snapshot just because a minute elapsed.
      if (_active && !_inFlight && !_disposed && enabled()) {
        if (++_fallbackTicks % 5 == 0) _libraryPending = true;
        _pending = true;
        _schedule();
      }
    });
  }

  static String _id(String value) => value.replaceAll('-', '').toLowerCase();

  void _onEvent(ServerWebSocketMessage event) {
    if (event is LibraryChangedMessage ||
        (event is UserDataChangedMessage && _id(event.userId) == _id(userId))) {
      // A previously absent item or a new local copy can change this row too.
      changed(libraryChanged: event is LibraryChangedMessage);
    }
  }

  void changed({bool libraryChanged = false}) {
    if (_disposed || !enabled()) return;
    invalidate(libraryChanged);
    _libraryPending = _libraryPending || libraryChanged;
    _pending = true;
    _schedule();
  }

  void setActive(bool value) {
    if (_disposed || value == _active) return;
    _active = value;
    if (!value) {
      _scheduled?.cancel();
      _scheduled = null;
    } else {
      _schedule();
    }
  }

  void _schedule() {
    if (_disposed || !_active || !_pending || _inFlight || !enabled()) return;
    _scheduled ??= Timer(debounce, () {
      _scheduled = null;
      unawaited(_run());
    });
  }

  Future<void> _run() async {
    if (_disposed || !_active || !enabled()) return;
    _inFlight = true;
    _pending = false;
    final libraryChanged = _libraryPending;
    _libraryPending = false;
    try {
      if (libraryChanged && refreshLibrary != null) {
        await refreshLibrary!();
      } else {
        await refresh();
      }
    } catch (_) {
      _libraryPending = _libraryPending || libraryChanged;
      /* Next event or fallback will retry. */
    } finally {
      _inFlight = false;
      _schedule();
    }
  }

  void dispose() {
    _disposed = true;
    _scheduled?.cancel();
    _fallback.cancel();
    unawaited(_events.cancel());
    unawaited(_connections.cancel());
  }
}
