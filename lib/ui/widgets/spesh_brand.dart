import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const speshWeb = (kIsWeb && bool.fromEnvironment('SPESHTV_WEB')) ||
    bool.fromEnvironment('SPESHMEDIA_CLIENT');

class SpeshBrand extends StatelessWidget {
  const SpeshBrand({super.key, this.height = 40});
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.live_tv_outlined, color: Color(0xFF56D9CC), size: 32),
        const SizedBox(width: 10),
        Text('SpeshTV', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: const Color(0xFFF3F5F6), fontWeight: FontWeight.w700, letterSpacing: 0,
        )),
      ]),
    ),
  );
}
