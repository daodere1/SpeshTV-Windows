import 'dart:async';

/// Publishes completed sources without letting a slow source hold up the list.
/// Timed-out requests may finish later, but cannot publish or launch more work.
Future<List<R>> collectProgressiveBatches<T, R>(
  List<T> sources,
  Future<List<R>> Function(T) fetch, {
  int concurrency = 2,
  Duration budget = const Duration(seconds: 10),
  void Function(List<R>)? onBatch,
}) async {
  if (concurrency < 1) throw ArgumentError.value(concurrency, 'concurrency');
  if (sources.isEmpty || budget <= Duration.zero) return const [];
  final clock = Stopwatch()..start();
  final result = <R>[];
  var next = 0;
  var finished = false;
  Future<void> worker() async {
    while (!finished && next < sources.length) {
      final remaining = budget - clock.elapsed;
      if (remaining <= Duration.zero) return;
      final source = sources[next++];
      try {
        final batch = await fetch(source).timeout(remaining);
        if (finished || clock.elapsed >= budget) return;
        result.addAll(batch);
        onBatch?.call(batch);
      } catch (_) {
        // One unavailable source must not discard the other completed sources.
      }
    }
  }

  try {
    await Future.wait(
      List.generate(
        sources.length < concurrency ? sources.length : concurrency,
        (_) => worker(),
      ),
    ).timeout(budget, onTimeout: () => const <void>[]);
  } finally {
    finished = true;
    clock.stop();
  }
  return List.unmodifiable(result);
}
