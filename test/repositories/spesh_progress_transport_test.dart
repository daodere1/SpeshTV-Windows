import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/services/row_data_source.dart';
import 'package:server_jellyfin/src/api/jellyfin_items_api.dart';

import 'spesh_search_transport_test.dart' show RecordingAdapter, Client;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'cached progress gets one longer request without changing ordinary API timeouts',
    () async {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://server.invalid',
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'X-Test-Session': 'preserved'},
        ),
      );
      final adapter = RecordingAdapter();
      dio.httpClientAdapter = adapter;
      final api = JellyfinItemsApi(dio, () => 'viewer');
      await api.getResumeItems(
        startIndex: 0,
        limit: 15,
        includeItemTypes: ['Movie', 'Episode'],
      );
      await api.getNextUp(startIndex: 0, limit: 15, enableResumable: false);
      await api.getItem('movie');
      expect(adapter.requests.length, 3);
      for (final request in adapter.requests.take(2)) {
        expect(request.connectTimeout, const Duration(seconds: 30));
        expect(request.receiveTimeout, const Duration(seconds: 30));
        expect(request.headers['X-Test-Session'], 'preserved');
        expect(request.queryParameters['Limit'], 15);
        expect(request.queryParameters['EnableTotalRecordCount'], false);
        expect(
          request.queryParameters['Fields'],
          'ProviderIds,ProductionYear,PrimaryImageAspectRatio',
        );
        expect(request.queryParameters.containsKey('EnableImageTypes'), false);
      }
      expect(adapter.requests.first.path, '/Users/viewer/Items/Resume');
      expect(adapter.requests.first.queryParameters['MediaTypes'], 'Video');
      expect(adapter.requests[1].queryParameters['UserId'], 'viewer');
      expect(adapter.requests[1].queryParameters['EnableResumable'], false);
      expect(adapter.requests.last.connectTimeout, const Duration(seconds: 8));
      expect(dio.options.connectTimeout, const Duration(seconds: 8));
      dio.close();
    },
  );
  test(
    'Next Up enrichment keeps history lookups scoped to the selected user',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://server.invalid'));
      final adapter = RecordingAdapter();
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(
        InterceptorsWrapper(
          onResponse: (response, handler) {
            response.data = {
              'Items': [
                {
                  'Id': 'episode',
                  'Type': 'Episode',
                  'Name': 'Episode',
                  'SeriesId': 'series',
                },
              ],
              'TotalRecordCount': 1,
            };
            handler.next(response);
          },
        ),
      );
      final client = Client();
      when(
        () => client.itemsApi,
      ).thenReturn(JellyfinItemsApi(dio, () => 'viewer'));
      final row = await RowDataSource(
        client,
      ).loadNextUp('server', startIndex: 0);
      expect(row.items.single.id, 'episode');
      expect(row.totalCount, 0);
      expect(adapter.requests.map((r) => r.path), [
        '/Shows/NextUp', '/Users/viewer/Items', '/Users/viewer/Items',
      ]);
      expect(adapter.requests.every((r) =>
          r.queryParameters['UserId'] == 'viewer' ||
          r.path.startsWith('/Users/viewer/')), true);
      dio.close();
    },
  );
}
