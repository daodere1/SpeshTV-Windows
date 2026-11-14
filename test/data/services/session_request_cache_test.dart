import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/session_request_cache.dart';

void main() {
  test('coalesces requests, expires values and allows forced refresh', () async {
    var now = DateTime(2026);
    final cache = SessionRequestCache<int>(now: () => now);
    final response = Completer<int>();
    var calls = 0;
    Future<int> fetch() { calls++; return response.future; }
    final a = cache.load('user-a', fetch);
    final b = cache.load('user-a', fetch);
    response.complete(1);
    expect(await a, 1);
    expect(await b, 1);
    expect(calls, 1);
    expect(await cache.load('user-a', () async => 2, ttl: const Duration(minutes: 1)), 1);
    expect(cache.peek('user-b', maxAge: const Duration(minutes: 1)), isNull);
    now = now.add(const Duration(minutes: 2));
    expect(await cache.load('user-a', () async => 2, ttl: const Duration(minutes: 1)), 2);
    expect(await cache.load('user-a', () async => 3, force: true), 3);
  });
  test('bounded capacity and failed requests do not poison retries', () async {
    final cache = SessionRequestCache<int>(capacity: 1);
    await cache.load('a', () async => 1);
    await cache.load('b', () async => 2);
    expect(cache.peek('a', maxAge: const Duration(days: 1)), isNull);
    await expectLater(cache.load('c', () async => throw StateError('fail')), throwsStateError);
    expect(await cache.load('c', () async => 3), 3);
  });
}
