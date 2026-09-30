import 'package:flutter/material.dart';

class SpeshPickerNowNext extends StatelessWidget {
  const SpeshPickerNowNext({super.key, required this.channel, required this.loading,
    this.nowTitle, this.nowTime, this.nextTitle, this.nextTime, this.showChannel = true});
  final String channel;
  final bool loading;
  final bool showChannel;
  final String? nowTitle, nowTime, nextTitle, nextTime;

  Widget _programme(BuildContext context, String label, String? title, String? time) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(time == null ? label : '$label  $time',
          style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 3),
        Text(loading ? 'Loading guide...' : title ?? 'Guide unavailable',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium),
      ]);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (showChannel) Text(channel, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium),
      if (showChannel) const SizedBox(height: 6),
      LayoutBuilder(builder: (context, constraints) {
        final now = _programme(context, 'Now', nowTitle, nowTime);
        final next = _programme(context, 'Next', nextTitle, nextTime);
        return constraints.maxWidth >= 600
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: now), const SizedBox(width: 24), Expanded(child: next)])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                now, const SizedBox(height: 8), next]);
      }),
    ]),
  );
}
