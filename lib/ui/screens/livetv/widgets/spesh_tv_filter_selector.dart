import 'package:flutter/material.dart';
import '../../../../data/models/channel_facets.dart';

/// A bounded picker avoids dropdown-route positioning across the TV UI scale.
class SpeshTvFilterSelector extends StatelessWidget {
  const SpeshTvFilterSelector({super.key, required this.label,
    required this.value, required this.options, required this.onSelected});
  final String label;
  final String value;
  final List<ChannelFilterOption> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: () async {
      final opener = FocusManager.instance.primaryFocus;
      final values = ['', ...options.map((option) => option.value)];
      final selected = values.indexOf(value).clamp(0, values.length - 1);
      String? next;
      try {
        next = await showDialog<String>(context: context, builder: (context) =>
          AlertDialog(title: Text(label), content: _PickerList(
            values: values, options: options, selected: selected),
            actions: [TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'))]));
      } finally {
        if (opener?.context != null) opener!.requestFocus();
      }
      if (next != null && context.mounted) onSelected(next);
    },
    child: Row(children: [Expanded(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
      children: [Text(label, style: const TextStyle(fontSize: 12)),
        Text(value.isEmpty ? 'All' : value, maxLines: 1, overflow: TextOverflow.ellipsis)])),
      const Icon(Icons.expand_more)]),
  );
}

class _PickerList extends StatefulWidget {
  const _PickerList({required this.values, required this.options, required this.selected});
  final List<String> values;
  final List<ChannelFilterOption> options;
  final int selected;
  @override
  State<_PickerList> createState() => _PickerListState();
}

class _PickerListState extends State<_PickerList> {
  final _selectedFocus = FocusNode(debugLabel: 'SelectedGuideFilter');
  Animation<double>? _routeAnimation;
  void _focusSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selectedFocus.context != null) _selectedFocus.requestFocus();
    });
  }
  void _onRouteStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _focusSelected();
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (_routeAnimation != animation) {
      _routeAnimation?.removeStatusListener(_onRouteStatus);
      _routeAnimation = animation;
      animation?.addStatusListener(_onRouteStatus);
      _focusSelected();
    }
  }
  late final ScrollController _controller = ScrollController(
    initialScrollOffset: widget.selected * 56.0);
  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _selectedFocus.dispose(); _controller.dispose(); super.dispose();
  }
  @override
  Widget build(BuildContext context) => SizedBox(width: 480, height: 320,
    child: ListView.builder(controller: _controller, itemExtent: 56,
      itemCount: widget.values.length, itemBuilder: (context, index) => TextButton(
        focusNode: index == widget.selected ? _selectedFocus : null,
        autofocus: index == widget.selected,
        onPressed: () => Navigator.pop(context, widget.values[index]),
        child: Row(children: [Expanded(child: Text(index == 0 ? 'All' :
          '${widget.options[index - 1].value} (${widget.options[index - 1].count})',
          maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (index == widget.selected) const Icon(Icons.check)]),
      )),
  );
}
