import 'package:flutter/material.dart';

class SpeshPreviousChannelButton extends StatelessWidget {
  const SpeshPreviousChannelButton({super.key, this.channelName, this.onPressed});
  final String? channelName;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(width: 44, height: 44,
    child: IconButton(
      tooltip: channelName == null ? 'Previous channel' : 'Previous channel: $channelName',
      onPressed: onPressed,
      icon: const Icon(Icons.swap_horiz),
      color: Colors.white,
      disabledColor: Colors.white38,
    ),
  );
}
