import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/repositories/search_repository.dart';
import 'package:server_core/server_core.dart';
import 'package:server_jellyfin/src/api/jellyfin_items_api.dart';

class Client extends Mock implements MediaServerClient {}

class RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString('{"Items":[]}', 200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
  @override
  void close({bool force = false}) {}
}

void main() {
  test('only search gets longer timeout; counts and collection collapse are off', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://server.invalid',
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'X-Test-Session': 'preserved'}));
    final adapter = RecordingAdapter();
    dio.httpClientAdapter = adapter;
    final api = JellyfinItemsApi(dio, () => 'viewer');
    final client = Client();
    when(() => client.itemsApi).thenReturn(api);
    final repository = SearchRepository(client);

    await repository.search('Reacher', parentId: 'vod', limit: 48);
    await repository.searchPeople('Reacher');
    await api.getItems(parentId: 'local');
    await api.getItem('movie');

    for (final request in adapter.requests.take(2)) {
      expect(request.connectTimeout, const Duration(seconds: 30));
      expect(request.receiveTimeout, const Duration(seconds: 30));
      expect(request.headers['X-Test-Session'], 'preserved');
      expect(request.queryParameters['EnableTotalRecordCount'], false);
    }
    expect(adapter.requests.first.path, '/Users/viewer/Items');
    expect(adapter.requests.first.queryParameters['ParentId'], 'vod');
    expect(adapter.requests.first.queryParameters['CollapseBoxSetItems'], false);
    for (final request in adapter.requests.skip(2)) {
      expect(request.connectTimeout, const Duration(seconds: 8));
    }
    expect(dio.options.connectTimeout, const Duration(seconds: 8));
    dio.close();
  });
}
