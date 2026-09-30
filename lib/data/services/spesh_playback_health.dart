import 'package:dio/dio.dart';
import 'package:server_core/server_core.dart';

Future<String?> speshPlaybackFailure(MediaServerClient client, String itemId) async {
  final token = client.accessToken;
  if (token == null || token.isEmpty) return null;
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 1),
    receiveTimeout: const Duration(seconds: 1),
    followRedirects: false,
    headers: {
      'Authorization': buildServerAuthorizationHeader(
        scheme: 'MediaBrowser', deviceInfo: client.deviceInfo, accessToken: token),
      'Accept': 'application/json',
    },
  ));
  configureServerDio(dio);
  try {
    final response = await dio.get<dynamic>('${client.baseUrl}/UserIptvProxy/PlaybackHealth/Mine');
    if (response.data is! List) return null;
    return speshPlaybackMessage(response.data as List, itemId, DateTime.now().toUtc());
  } catch (_) {
    // Older servers and unavailable diagnostics retain the existing player error.
  } finally {
    dio.close(force: true);
  }
  return null;
}

String? speshPlaybackMessage(List entries, String itemId, DateTime now) {
    final candidates = <Map>[];
    for (final entry in entries) {
      if (entry is! Map) continue;
      final id = (entry['ItemId'] ?? entry['itemId'] ?? '').toString().replaceAll('-', '').toLowerCase();
      if (id != itemId.replaceAll('-', '').toLowerCase()) continue;
      final updated = DateTime.tryParse((entry['Updated'] ?? entry['updated'] ?? '').toString());
      if (updated == null || updated.toUtc().isAfter(now.toUtc()) || now.toUtc().difference(updated.toUtc()) > const Duration(seconds: 30)) continue;
      candidates.add(entry);
    }
    candidates.sort((a, b) => DateTime.parse((b['Updated'] ?? b['updated']).toString()).compareTo(DateTime.parse((a['Updated'] ?? a['updated']).toString())));
    for (final entry in candidates.take(1)) {
      final state = entry['State'] ?? entry['state'];
      return switch (state) {
        'Authorization' => 'Your account needs administrator attention before this content can play.',
        'ProviderAccess' => 'The provider denied access to this content. Contact your administrator.',
        'StreamLimit' => 'Your stream limit is reached. Stop another stream, then retry.',
        'ProviderRateLimit' => 'The provider is limiting requests. Please try again shortly.',
        'ProviderConnection' => 'The server could not connect to the provider. Please try again shortly.',
        'Transcoding' => 'The server could not prepare video for this device. Try another device or contact your administrator.',
        _ => null,
      };
    }
  return null;
}
