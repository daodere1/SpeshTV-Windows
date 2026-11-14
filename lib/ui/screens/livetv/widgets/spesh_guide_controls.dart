import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../util/platform_detection.dart';

class SpeshGuideControls extends StatefulWidget {
  const SpeshGuideControls({super.key, required this.searchController,
    required this.numberController, required this.onSearch, required this.onJump,
    required this.onHome, this.onPreview, this.onStop, this.tvNavigation});
  final bool? tvNavigation;

  final TextEditingController searchController;
  final TextEditingController numberController;
  final ValueChanged<String> onSearch;
  final VoidCallback onJump;
  final VoidCallback onHome;
  final VoidCallback? onPreview;
  final VoidCallback? onStop;

  @override
  State<SpeshGuideControls> createState() => _SpeshGuideControlsState();
}

class _SpeshGuideControlsState extends State<SpeshGuideControls> {
  late final FocusNode _searchFocus = FocusNode(onKeyEvent: (_, event) =>
    _move(event, left: _homeFocus, right: _numberFocus));
  late final FocusNode _numberFocus = FocusNode(onKeyEvent: (_, event) =>
    _move(event, left: _searchFocus, right: _jumpFocus));
  final _homeFocus = FocusNode();
  final _jumpFocus = FocusNode();

  KeyEventResult _move(KeyEvent event, {required FocusNode left, required FocusNode right}) {
    if (!(widget.tvNavigation ?? PlatformDetection.isTV) ||
        View.of(context).viewInsets.bottom > 0 ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) return KeyEventResult.ignored;
    final target = event.logicalKey == LogicalKeyboardKey.arrowRight ? right
      : event.logicalKey == LogicalKeyboardKey.arrowLeft ? left : null;
    if (target == null) return KeyEventResult.ignored;
    target.requestFocus();
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _searchFocus.dispose(); _numberFocus.dispose();
    _homeFocus.dispose(); _jumpFocus.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchController = widget.searchController;
    final numberController = widget.numberController;
    final onSearch = widget.onSearch;
    final onJump = widget.onJump;
    final onHome = widget.onHome;
    final onPreview = widget.onPreview;
    final onStop = widget.onStop;
    return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 720;
      final preview = onStop != null
          ? IconButton(tooltip: 'Stop preview', onPressed: onStop,
              color: Colors.white70, padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              icon: const Icon(Icons.stop_circle_outlined))
          : SizedBox(width: 108, child: Tooltip(message: 'Watch preview',
              child: TextButton.icon(onPressed: onPreview,
                icon: const Icon(Icons.play_arrow), label: const Text('Preview'))));
      final search = SizedBox(
        width: compact ? constraints.maxWidth - (onStop != null ? 48 : 116) : 260,
        child: TextField(
          focusNode: _searchFocus,
          controller: searchController,
          onChanged: onSearch,
          decoration: InputDecoration(
            isDense: true, labelText: 'Search channels',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(tooltip: 'Clear channel search',
              color: Colors.white70,
              icon: const Icon(Icons.close), onPressed: () {
                searchController.clear(); onSearch('');
              }),
            border: const OutlineInputBorder(),
          ),
        ),
      );
      return Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Tooltip(message: 'Return to SpeshTV', child: TextButton.icon(
            focusNode: _homeFocus,
            onPressed: onHome, icon: const Icon(Icons.arrow_back),
            label: const Text('SpeshTV'))),
          if (!compact) search,
          SizedBox(width: compact ? 96 : 110, child: TextField(controller: numberController,
            focusNode: _numberFocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            onSubmitted: (_) => onJump(),
            decoration: const InputDecoration(isDense: true, labelText: 'Channel #',
              border: OutlineInputBorder()),
          )),
          IconButton(tooltip: 'Jump to channel', onPressed: onJump,
            focusNode: _jumpFocus,
            color: Colors.white70, padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(Icons.arrow_forward)),
          if (!compact) preview,
          if (compact) search,
          if (compact) preview,
        ]);
    }),
  );
  }
}
