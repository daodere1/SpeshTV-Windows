import 'dart:ui';

import 'package:flutter/material.dart';

/// A clipped backdrop keeps the blur confined to the navigation panel.
class SpeshNavigationGlass extends StatelessWidget {
  const SpeshNavigationGlass({
    super.key,
    required this.child,
    this.enabled = true,
  });
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final highContrast = MediaQuery.highContrastOf(context);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: highContrast
              ? const [Color(0xF0181C24), Color(0xF00D1016)]
              : const [Color(0x70212A36), Color(0x480D121C)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x30FFFFFF)),
      ),
      child: child,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: highContrast
          ? surface
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: surface,
            ),
    );
  }
}
