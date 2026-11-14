import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/utils/progressive_batches.dart';

void main() {
  test('empty and expired budgets do not launch requests', () async {
    var calls = 0;
    Future<List<int>> fetch(int id) async { calls++; return [id]; }
    expect(await collectProgressiveBatches<int, int>([], fetch), isEmpty);
    expect(await collectProgressiveBatches<int, int>([1], fetch,
      budget: Duration.zero), isEmpty);
    expect(calls, 0);
  });
  test('two workers bound requests while draining every queued source', () async {
    var active = 0;
    var peak = 0;
    final result = await collectProgressiveBatches<int, int>([1, 2, 3, 4],
      (id) async {
        active++;
        if (active > peak) peak = active;
        await Future<void>.delayed(Duration.zero);
        active--;
        return [id];
      });
    expect(peak, 2);
    expect(result, unorderedEquals([1, 2, 3, 4]));
  });
  test('fast source publishes while another source is pending', () async {
    final slow = Completer<List<int>>();
    final seen = <int>[];
    final loading = collectProgressiveBatches<int, int>(
      [1, 2],
      (id) => id == 1 ? slow.future : Future.value([id]),
      onBatch: seen.addAll,
    );
    await Future<void>.delayed(Duration.zero);
    expect(seen, [2]);
    slow.complete([1]);
    expect(await loading, [2, 1]);
  });
  test('deadline blocks late results and queued work', () async {
    final slow = Completer<List<int>>();
    final started = <int>[];
    final seen = <int>[];
    final result = await collectProgressiveBatches<int, int>(
      [1, 2, 3],
      (id) {
        started.add(id);
        return id == 1 ? Future.value([1]) : slow.future;
      },
      concurrency: 1,
      budget: const Duration(milliseconds: 30),
      onBatch: seen.addAll,
    );
    expect(result, [1]);
    slow.complete([2]);
    await Future<void>.delayed(Duration.zero);
    expect(started, [1, 2]);
    expect(seen, [1]);
  });
  test('failed source does not discard successful sources', () async {
    final result = await collectProgressiveBatches<int, int>(
      [1, 2],
      (id) => id == 1 ? Future.error(StateError('offline')) : Future.value([2]),
    );
    expect(result, [2]);
  });
}
