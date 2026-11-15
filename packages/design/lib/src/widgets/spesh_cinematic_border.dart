import 'package:flutter/material.dart';

/// Thin blue-to-gold focus ring, painted inside the existing bounds.
/// Keeps the same layout and hit target when keyboard or remote focus moves.
class SpeshCinematicBorder extends Border {
  SpeshCinematicBorder({double width = 2})
    : super.fromBorderSide(BorderSide(color: Colors.white, width: width));

  static const gradient = LinearGradient(
    colors: [Color(0xFF8ABCF4), Color(0xFFF3C564)],
  );

  @override
  void paint(Canvas canvas, Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = top.width
      ..shader = gradient.createShader(rect);
    final inset = top.width / 2;
    if (shape == BoxShape.circle) {
      canvas.drawOval(rect.deflate(inset), paint);
    } else {
      canvas.drawRRect(
        (borderRadius ?? BorderRadius.zero).toRRect(rect).deflate(inset), paint,
      );
    }
  }
}
