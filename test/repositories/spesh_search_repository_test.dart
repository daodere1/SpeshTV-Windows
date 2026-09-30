import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/models/search_source.dart';
import 'package:moonfin/data/repositories/search_repository.dart';
import 'package:server_core/server_core.dart';

class Client extends Mock implements MediaServerClient {}
class Views extends Mock implements UserViewsApi {}
class Repository extends SearchRepository {
  Repository(super.client);
  final calls = <String>[];
  final pending = <Completer<List<AggregatedItem>>>[];
  @override
  Future<List<AggregatedItem>> search(String query, {
    List<String>? includeItemTypes, String? parentId, int? limit}) {
    calls.add(parentId!);
    final request = Completer<List<AggregatedItem>>();
    pending.add(request);
    return request.future;
  }
}

void main() {
  late Repository repo;
  late Views views;
  setUp(() {
    final client = Client();
    views = Views();
    when(() => client.userViewsApi).thenReturn(views);
    when(() => views.getUserViews()).thenAnswer((_) async => {'Items': [
      {'Id': 'local', 'Name': 'Movies', 'CollectionType': 'movies'},
      {'Id': 'vod', 'Name': 'VOD FHD Movies', 'CollectionType': 'movies'},
      {'Id': 'series', 'Name': 'VOD TV Shows', 'CollectionType': 'tvshows'},
      {'Id': 'local2', 'Name': 'HD TV Shows', 'CollectionType': 'tvshows'},
      {'Id': 'live', 'Name': 'Live TV', 'CollectionType': 'livetv'},
    ]});
    repo = Repository(client);
  });
  test('only visible user libraries, with a maximum of three active requests', () async {
    final work = repo.searchLibraries('a', source: SearchSource.all,
      isCurrent: () => true, onResults: (_) {});
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls, ['local', 'local2', 'vod']);
    repo.pending.first.complete([]);
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls, ['local', 'local2', 'vod', 'series']);
    for (final request in repo.pending.skip(1)) { request.complete([]); }
    await work;
    verify(() => views.getUserViews()).called(1);
  });
  test('VOD filtering happens before fetching items', () async {
    final work = repo.searchLibraries('a', source: SearchSource.vod,
      isCurrent: () => true, onResults: (_) {});
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls, ['vod', 'series']);
    for (final request in repo.pending) { request.complete([]); }
    await work;
  });
  test('canceled query schedules no additional library requests', () async {
    var current = true;
    var published = 0;
    final work = repo.searchLibraries('a', source: SearchSource.all,
      isCurrent: () => current, onResults: (_) => published++);
    await Future<void>.delayed(Duration.zero);
    current = false;
    for (final request in repo.pending) { request.complete([]); }
    await work;
    expect(repo.calls, hasLength(3));
    expect(published, 0);
  });

  DioException timeout() => DioException.connectionTimeout(
    requestOptions: RequestOptions(path: '/Items'),
    timeout: const Duration(seconds: 30),
  );

  test('transient library timeout retries once and preserves other results', () async {
    final work = repo.searchLibraries('a', source: SearchSource.vod,
      isCurrent: () => true, onResults: (_) {});
    await Future<void>.delayed(Duration.zero);
    repo.pending[0].completeError(timeout());
    repo.pending[1].complete([AggregatedItem(id: 'show', serverId: 's',
      rawData: {'Type': 'Series', 'Name': 'Show'})]);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(repo.calls, ['vod', 'series', 'vod']);
    repo.pending[2].complete([]);
    expect((await work).single.id, 'show');
  });

  test('retry is bounded and reports a persistent timeout', () async {
    final work = repo.searchLibraries('a', source: SearchSource.vod,
      isCurrent: () => true, onResults: (_) {});
    final assertion = expectLater(work, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    repo.pending[0].completeError(timeout());
    repo.pending[1].complete([]);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    repo.pending[2].completeError(timeout());
    await assertion;
    expect(repo.calls, hasLength(3));
  });

  test('authorization failures are not retried', () async {
    final work = repo.searchLibraries('a', source: SearchSource.vod,
      isCurrent: () => true, onResults: (_) {});
    final assertion = expectLater(work, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    final options = RequestOptions(path: '/Items');
    repo.pending[0].completeError(DioException.badResponse(
      statusCode: 403, requestOptions: options,
      response: Response(requestOptions: options, statusCode: 403)));
    repo.pending[1].complete([]);
    await assertion;
    expect(repo.calls, hasLength(2));
  });

  test('obsolete search does not retry after its backoff', () async {
    var current = true;
    final work = repo.searchLibraries('a', source: SearchSource.vod,
      isCurrent: () => current, onResults: (_) {});
    await Future<void>.delayed(Duration.zero);
    repo.pending[0].completeError(timeout());
    repo.pending[1].complete([]);
    await Future<void>.delayed(Duration.zero);
    current = false;
    await work;
    expect(repo.calls, hasLength(2));
  });
}
