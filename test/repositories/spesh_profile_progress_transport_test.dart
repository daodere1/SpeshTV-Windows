import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_jellyfin/src/api/jellyfin_items_api.dart';
import 'package:server_jellyfin/src/api/jellyfin_users_api.dart';

import 'spesh_search_transport_test.dart' show RecordingAdapter;

void main() {
  test(
    'Users/Me validation bypasses cached identity without changing auth',
    () async {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://server.invalid',
          headers: {'Authorization': 'test-selected-session'},
        ),
      );
      addTearDown(dio.close);
      RequestOptions? sent;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            sent = request;
            handler.resolve(
              Response(requestOptions: request, data: {'Id': 'profile-two'}),
            );
          },
        ),
      );
      final user = await JellyfinUsersApi(dio).getCurrentUser();
      expect(user.id, 'profile-two');
      expect(sent!.path, '/Users/Me');
      expect(sent!.headers['Authorization'], 'test-selected-session');
      expect(sent!.headers['Cache-Control'], 'no-store');
      expect(sent!.headers['Pragma'], 'no-cache');
    },
  );

  for (final audio in [false, true]) {
    test('fresh selected-user history (audio=$audio)', () async {
      var user = 'profile-two';
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://server.invalid',
          headers: {'X-Test-Session': 'kept'},
        ),
      );
      addTearDown(dio.close);
      final adapter = RecordingAdapter();
      dio.httpClientAdapter = adapter;
      final api = JellyfinItemsApi(dio, () => user);
      await api.getResumeItems(
        mediaTypes: audio ? 'Audio' : 'Video',
        fields: 'Overview',
        limit: 15,
      );
      user = 'profile-three';
      await api.getNextUp(limit: 15);
      expect(adapter.requests.map((r) => r.queryParameters['UserId']), [
        'profile-two',
        'profile-three',
      ]);
      for (final request in adapter.requests) {
        expect(request.headers['Cache-Control'], 'no-store');
        expect(request.headers['Pragma'], 'no-cache');
        expect(request.headers['X-Test-Session'], 'kept');
        expect(request.queryParameters.keys, isNot(contains('MinResumePct')));
      }
      if (audio) {
        expect(adapter.requests.first.queryParameters['MediaTypes'], 'Audio');
        expect(adapter.requests.first.queryParameters['Fields'], 'Overview');
      }
      expect(dio.options.headers.containsKey('Cache-Control'), false);
    });
    test('reject late history after identity changes (audio=$audio)', () async {
      var user = 'profile-two';
      final pending = Completer<void>();
      final entered = Completer<void>();
      final dio = Dio(BaseOptions(baseUrl: 'https://server.invalid'));
      addTearDown(dio.close);
      dio.httpClientAdapter = RecordingAdapter();
      dio.interceptors.add(
        InterceptorsWrapper(
          onResponse: (response, handler) async {
            entered.complete();
            await pending.future;
            handler.next(response);
          },
        ),
      );
      final api = JellyfinItemsApi(dio, () => user);
      final response = api.getResumeItems(
        mediaTypes: audio ? 'Audio' : 'Video',
      );
      final rejected = expectLater(response, throwsStateError);
      await entered.future;
      user = 'profile-three';
      pending.complete();
      await rejected;
    });
  }
  test('missing selected identity never queries owner history', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://server.invalid'));
    addTearDown(dio.close);
    final adapter = RecordingAdapter();
    dio.httpClientAdapter = adapter;
    final api = JellyfinItemsApi(dio, () => '');
    await expectLater(api.getResumeItems(), throwsStateError);
    await expectLater(api.getNextUp(), throwsStateError);
    expect(adapter.requests, isEmpty);
  });
}
