import 'package:flutter/widgets.dart';

/// Bounded diagnostic samples contain no account, title, URL or token data.
class SpeshLoadMetrics {
  static final samples = <String>[];
  static void record(String operation, Stopwatch timer, {int count = 0}) {
    if (!const bool.fromEnvironment('SPESHMEDIA_CLIENT', defaultValue: true)) return;
    try {
    final cache = PaintingBinding.instance.imageCache;
    final sample = '$operation ms=${timer.elapsedMilliseconds} count=$count '
        'imageBytes=${cache.currentSizeBytes} liveImages=${cache.liveImageCount}';
    samples.add(sample);
    if (samples.length > 64) samples.removeAt(0);
    debugPrint('[SpeshTV performance] $sample');
    } catch (_) {
      // Diagnostics must never hold up loading during early startup.
    }
  }
}
