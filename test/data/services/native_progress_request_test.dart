import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_jellyfin/src/api/jellyfin_items_api.dart';

void main() {
  test('native merged progress uses lightweight user-scoped requests', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()..interceptors.add(InterceptorsWrapper(
      onRequest: (request, handler) {
        requests.add(request);
        handler.resolve(Response(requestOptions: request,
          data: <String, dynamic>{'Items': [], 'TotalRecordCount': 999}));
      },
    ));
    final api = JellyfinItemsApi(dio, () => 'member');
    final result = await api.getResumeItems(mediaTypes: 'Video', startIndex: 15);
    await api.getNextUp(enableResumable: false);
    expect(requests.first.path, '/Users/member/Items/Resume');
    for (final request in requests) {
      expect(request.queryParameters['EnableTotalRecordCount'], false);
      expect(request.queryParameters['EnableUserData'], true);
      expect(request.receiveTimeout, const Duration(seconds: 30));
    }
    expect(requests.first.queryParameters['StartIndex'], 15);
    expect(requests.last.queryParameters['EnableResumable'], false);
    expect(result['TotalRecordCount'], 0);
    await api.getResumeItems(mediaTypes: 'Audio');
    expect(requests.last.path, '/UserItems/Resume');
    expect(requests.last.queryParameters['MediaTypes'], 'Audio');
  });
}
