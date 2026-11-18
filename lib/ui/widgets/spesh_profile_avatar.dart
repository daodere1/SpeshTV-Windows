import 'package:flutter/material.dart';

const speshProfileColors = <String, Color>{
  'blue': Color(0xFF2979D5),
  'gold': Color(0xFFE4B34A),
  'teal': Color(0xFF188B8C),
  'purple': Color(0xFF8259C5),
  'coral': Color(0xFFDB6B59),
  'green': Color(0xFF42965B),
  'pink': Color(0xFFD564A0),
  'slate': Color(0xFF64748B),
};

class SpeshProfileAvatar extends StatelessWidget {
  const SpeshProfileAvatar({super.key, required this.avatar, this.size = 112});
  final String avatar;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: speshProfileColors[avatar] ?? speshProfileColors['blue'],
      borderRadius: BorderRadius.circular(size * .22),
    ),
    child: Icon(Icons.face_rounded, size: size * .65, color: Colors.white),
  );
}
