import 'package:dio/dio.dart';
import 'package:server_jellyfin/src/api/jellyfin_items_api.dart';
import 'package:test/test.dart';

class _FakeServer extends Interceptor {
  _FakeServer(this.handle);

  final void Function(RequestOptions options, RequestInterceptorHandler handler)
  handle;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) =>
      handle(options, handler);
}

void main() {
  test('discovery IDs do not request Jellyfin theme media', () async {
    var requests = 0;
    final dio = Dio()..interceptors.add(_FakeServer((options, handler) {
      requests++;
      handler.resolve(Response(requestOptions: options, data: <String, dynamic>{}));
    }));
    final result = await JellyfinItemsApi(dio, () => 'user-1').getThemeMedia('tmdb:movie:1236045');
    expect(requests, 0);
    expect(result['ThemeSongsResult']['Items'], isEmpty);
    expect(result['ThemeVideosResult']['Items'], isEmpty);
  });

  test(
    'genres extends timeout and caches only matching user queries',
    () async {
      var requests = 0;
      var user = 'one';
      final dio = Dio()
        ..interceptors.add(
          _FakeServer((options, handler) {
            requests++;
            expect(options.receiveTimeout, const Duration(seconds: 60));
            expect(options.queryParameters['IncludeItemTypes'], 'Movie,Series');
            handler.resolve(
              Response(
                requestOptions: options,
                data: <String, dynamic>{'Items': [], 'TotalRecordCount': 0},
              ),
            );
          }),
        );
      final api = JellyfinItemsApi(dio, () => user);
      await api.getGenres(includeItemTypes: ['Movie', 'Series']);
      await api.getGenres(includeItemTypes: ['Movie', 'Series']);
      expect(requests, 1);
      user = 'two';
      await api.getGenres(includeItemTypes: ['Movie', 'Series']);
      await api.getGenres(
        parentId: 'library',
        includeItemTypes: ['Movie', 'Series'],
      );
      expect(requests, 3);
    },
  );

  test('failed genres request can be retried', () async {
    var requests = 0;
    final dio = Dio()
      ..interceptors.add(
        _FakeServer((options, handler) {
          requests++;
          if (requests == 1) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.receiveTimeout,
              ),
            );
          } else {
            handler.resolve(
              Response(
                requestOptions: options,
                data: <String, dynamic>{'Items': []},
              ),
            );
          }
        }),
      );
    final api = JellyfinItemsApi(dio, () => 'one');
    await expectLater(api.getGenres(), throwsA(isA<DioException>()));
    await api.getGenres();
    expect(requests, 2);
  });

  test('concurrent genres requests share one fetch', () async {
    var requests = 0;
    final dio = Dio()
      ..interceptors.add(
        _FakeServer((options, handler) async {
          requests++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          handler.resolve(
            Response(
              requestOptions: options,
              data: <String, dynamic>{'Items': []},
            ),
          );
        }),
      );
    final api = JellyfinItemsApi(dio, () => 'one');
    final first = api.getGenres();
    final second = api.getGenres();
    await first;
    await second;
    expect(requests, 1);
  });
  test('item details request UserData', () async {
    RequestOptions? request;
    final dio = Dio()
      ..interceptors.add(
        _FakeServer((options, handler) {
          request = options;
          handler.resolve(
            Response(requestOptions: options, data: <String, dynamic>{}),
          );
        }),
      );

    await JellyfinItemsApi(dio, () => 'user-1').getItem('movie-1');

    expect(request?.method, 'GET');
    expect(request?.path, '/Users/user-1/Items/movie-1');
    expect(request?.queryParameters['Fields'], contains('UserData'));
    for (final field in [
      'ProviderIds',
      'Studios',
      'Taglines',
      'OriginalTitle',
      'RemoteTrailers',
    ]) {
      expect(request?.queryParameters['Fields'], contains(field));
    }
  });

  test('episodes include the current user and requested metadata', () async {
    RequestOptions? request;
    final dio = Dio()
      ..interceptors.add(
        _FakeServer((options, handler) {
          request = options;
          handler.resolve(
            Response(
              requestOptions: options,
              data: <String, dynamic>{'Items': []},
            ),
          );
        }),
      );
    await JellyfinItemsApi(
      dio,
      () => 'user-1',
    ).getEpisodes('series-1', seasonId: 'season-1', fields: 'Overview,People');
    expect(request?.path, '/Shows/series-1/Episodes');
    expect(request?.queryParameters['UserId'], 'user-1');
    expect(request?.queryParameters['SeasonId'], 'season-1');
    expect(request?.queryParameters['Fields'], 'Overview,People');
  });

  test('resume items page through StartIndex', () async {
    RequestOptions? request;
    final dio = Dio()
      ..interceptors.add(
        _FakeServer((options, handler) {
          request = options;
          handler.resolve(
            Response(requestOptions: options, data: <String, dynamic>{}),
          );
        }),
      );

    await JellyfinItemsApi(
      dio,
      () => 'user-1',
    ).getResumeItems(startIndex: 30, limit: 15);

    expect(request?.path, '/UserItems/Resume');
    expect(request?.queryParameters['StartIndex'], 30);
    expect(request?.queryParameters['Limit'], 15);
  });

  test('resume items send MediaTypes instead of a type list', () async {
    RequestOptions? request;
    final dio = Dio()
      ..interceptors.add(
        _FakeServer((options, handler) {
          request = options;
          handler.resolve(
            Response(requestOptions: options, data: <String, dynamic>{}),
          );
        }),
      );

    await JellyfinItemsApi(
      dio,
      () => 'user-1',
    ).getResumeItems(mediaTypes: 'Video', limit: 12);

    expect(request?.path, '/UserItems/Resume');
    expect(request?.queryParameters['MediaTypes'], 'Video');
    expect(request?.queryParameters.containsKey('IncludeItemTypes'), isFalse);
  });

  test('next up pages through StartIndex', () async {
    RequestOptions? request;
    final dio = Dio()
      ..interceptors.add(
        _FakeServer((options, handler) {
          request = options;
          handler.resolve(
            Response(requestOptions: options, data: <String, dynamic>{}),
          );
        }),
      );

    await JellyfinItemsApi(dio, () => 'user-1').getNextUp(startIndex: 15);

    expect(request?.path, '/Shows/NextUp');
    expect(request?.queryParameters['StartIndex'], 15);
  });

  test('an unpaged request sends no StartIndex', () async {
    RequestOptions? request;
    final dio = Dio()
      ..interceptors.add(
        _FakeServer((options, handler) {
          request = options;
          handler.resolve(
            Response(requestOptions: options, data: <String, dynamic>{}),
          );
        }),
      );

    await JellyfinItemsApi(dio, () => 'user-1').getResumeItems(limit: 15);

    expect(request?.queryParameters.containsKey('StartIndex'), isFalse);
  });

  test('seasons ask for the child count', () async {
    RequestOptions? request;
    final dio = Dio()
      ..interceptors.add(
        _FakeServer((options, handler) {
          request = options;
          handler.resolve(
            Response(requestOptions: options, data: <String, dynamic>{}),
          );
        }),
      );

    await JellyfinItemsApi(
      dio,
      () => 'user-1',
    ).getSeasons('series-1', fields: 'ChildCount');

    expect(request?.path, '/Shows/series-1/Seasons');
    expect(request?.queryParameters['Fields'], 'ChildCount');
    expect(request?.queryParameters['UserId'], 'user-1');
  });

  test('seasons send no Fields when none are asked for', () async {
    RequestOptions? request;
    final dio = Dio()
      ..interceptors.add(
        _FakeServer((options, handler) {
          request = options;
          handler.resolve(
            Response(requestOptions: options, data: <String, dynamic>{}),
          );
        }),
      );

    await JellyfinItemsApi(dio, () => 'user-1').getSeasons('series-1');

    expect(request?.queryParameters.containsKey('Fields'), isFalse);
    expect(request?.queryParameters['UserId'], 'user-1');
  });

  test('collection removal deletes with the joined Ids param', () async {
    RequestOptions? request;
    final dio = Dio()
      ..interceptors.add(
        _FakeServer((options, handler) {
          request = options;
          handler.resolve(
            Response(requestOptions: options, data: <String, dynamic>{}),
          );
        }),
      );

    await JellyfinItemsApi(
      dio,
      () => 'user-1',
    ).removeFromCollection('boxset-1', ['a', 'b']);

    expect(request?.method, 'DELETE');
    expect(request?.path, '/Collections/boxset-1/Items');
    expect(request?.queryParameters['Ids'], 'a,b');
  });

  test(
    'getLatestItems requests /Users/\$userId/Items/Latest when userId is present',
    () async {
      RequestOptions? request;
      final dio = Dio()
        ..interceptors.add(
          _FakeServer((options, handler) {
            request = options;
            handler.resolve(
              Response(requestOptions: options, data: <dynamic>[]),
            );
          }),
        );

      await JellyfinItemsApi(
        dio,
        () => 'user-1',
      ).getLatestItems(includeItemTypes: ['Movie']);

      expect(request?.method, 'GET');
      expect(request?.path, '/Users/user-1/Items/Latest');
      expect(request?.queryParameters['IncludeItemTypes'], 'Movie');
    },
  );

  test(
    'getLatestItems falls back to /Items/Latest when userId is empty',
    () async {
      RequestOptions? request;
      final dio = Dio()
        ..interceptors.add(
          _FakeServer((options, handler) {
            request = options;
            handler.resolve(
              Response(requestOptions: options, data: <dynamic>[]),
            );
          }),
        );

      await JellyfinItemsApi(
        dio,
        () => '',
      ).getLatestItems(includeItemTypes: ['Movie']);

      expect(request?.method, 'GET');
      expect(request?.path, '/Items/Latest');
    },
  );
}
