import 'package:flutter/material.dart';

/// Keeps a visible agenda row at the same viewport position as source results
/// arrive. This stores view geometry only, never a schedule or member cache.
class StableAgendaList<T> extends StatefulWidget {
  const StableAgendaList({
    super.key,
    required this.items,
    required this.identity,
    required this.itemBuilder,
    this.viewId,
  });
  final List<T> items;
  final String Function(T) identity;
  final Widget Function(BuildContext, T, T?) itemBuilder;
  final Object? viewId;
  @override
  State<StableAgendaList<T>> createState() => _StableAgendaListState<T>();
}

class _StableAgendaListState<T> extends State<StableAgendaList<T>> {
  final _scroll = ScrollController();
  final _viewport = GlobalKey();
  final _rows = <String, GlobalKey>{};
  int _revision = 0;
  @override
  void didUpdateWidget(covariant StableAgendaList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final revision = ++_revision;
    if (oldWidget.viewId != widget.viewId ||
        !_scroll.hasClients ||
        _scroll.position.isScrollingNotifier.value)
      return;
    final viewport = _viewport.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    final top = viewport.localToGlobal(Offset.zero).dy;
    final bottom = top + viewport.size.height;
    String? anchor;
    double? anchorTop;
    for (final row in _rows.entries) {
      final box = row.value.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y < bottom &&
          y + box.size.height > top &&
          (anchorTop == null || y < anchorTop)) {
        anchor = row.key;
        anchorTop = y;
      }
    }
    if (anchor == null || anchorTop == null) return;
    final id = anchor;
    final previousTop = anchorTop - top;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          revision != _revision ||
          !_scroll.hasClients ||
          _scroll.position.isScrollingNotifier.value)
        return;
      final box = _rows[id]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) return;
      final view = _viewport.currentContext?.findRenderObject();
      if (view is! RenderBox || !view.hasSize) return;
      final delta =
          box.localToGlobal(Offset.zero).dy -
          view.localToGlobal(Offset.zero).dy -
          previousTop;
      if (delta.abs() < 0.5) return;
      _scroll.jumpTo(
        (_scroll.offset + delta).clamp(
          _scroll.position.minScrollExtent,
          _scroll.position.maxScrollExtent,
        ),
      );
    });
  }

  @override
  void dispose() {
    _revision++;
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indexes = {
      for (var n = 0; n < widget.items.length; n++)
        widget.identity(widget.items[n]): n,
    };
    _rows.removeWhere(
      (id, key) => !indexes.containsKey(id) && key.currentContext == null,
    );
    return ListView.builder(
      key: _viewport,
      controller: _scroll,
      itemCount: widget.items.length,
      findChildIndexCallback: (key) =>
          key is ValueKey<String> ? indexes[key.value] : null,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final id = widget.identity(item);
        return KeyedSubtree(
          key: ValueKey(id),
          child: KeyedSubtree(
            key: _rows.putIfAbsent(id, () => GlobalKey()),
            child: widget.itemBuilder(
              context,
              item,
              index == 0 ? null : widget.items[index - 1],
            ),
          ),
        );
      },
    );
  }
}
