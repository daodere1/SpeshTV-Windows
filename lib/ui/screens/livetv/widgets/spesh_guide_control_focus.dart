import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void focusSpeshGuideScope(FocusScopeNode scope, {FocusScopeNode? fallback}) {
  final context = scope.context;
  if (context == null || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
  final targets = scope.traversalDescendants.where((node) =>
      node is! FocusScopeNode && node.canRequestFocus && !node.skipTraversal);
  if (targets.isEmpty) {
    if (fallback != null && !identical(fallback, scope)) {
      focusSpeshGuideScope(fallback);
    }
    return;
  }
  if (scope.focusedChild != null) {
    scope.requestFocus();
    return;
  }
  for (final node in targets) {
    if (node is! FocusScopeNode && node.canRequestFocus && !node.skipTraversal) {
      node.requestFocus();
      return;
    }
  }
}

class SpeshGuideFocusBand extends StatelessWidget {
  const SpeshGuideFocusBand({super.key, required this.scope, required this.child,
    required this.onEntered, this.onUp, this.onDown});
  final FocusScopeNode scope;
  final Widget child;
  final VoidCallback onEntered;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    onFocusChange: (focused) { if (focused) onEntered(); },
    onKeyEvent: (_, event) {
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return KeyEventResult.ignored;
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
      final action = event.logicalKey == LogicalKeyboardKey.arrowDown ? onDown
        : event.logicalKey == LogicalKeyboardKey.arrowUp ? onUp : null;
      if (action == null) return KeyEventResult.ignored;
      action();
      return KeyEventResult.handled;
    },
    child: FocusScope(node: scope, child: child),
  );
}

void handleSpeshGuideBack({required bool keyboardVisible,
  required VoidCallback dismissKeyboard, required VoidCallback returnHome}) {
  if (keyboardVisible) { dismissKeyboard(); } else { returnHome(); }
}

class SpeshGuideControlFocus extends StatelessWidget {
  const SpeshGuideControlFocus({super.key, required this.child});
  final Widget child;

  static void _requestFocus(FocusNode node, {
    ScrollPositionAlignmentPolicy? alignmentPolicy, double? alignment,
    Duration? duration, Curve? curve,
  }) => node.requestFocus();

  @override
  Widget build(BuildContext context) => FocusTraversalGroup(
    // Fixed guide controls must not reveal themselves by scrolling ancestors.
    policy: ReadingOrderTraversalPolicy(requestFocusCallback: _requestFocus),
    child: Shortcuts(shortcuts: const {
      SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(TraversalDirection.up),
      SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(TraversalDirection.down),
    }, child: child),
  );
}
