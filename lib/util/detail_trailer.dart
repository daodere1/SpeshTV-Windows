import 'package:get_it/get_it.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

import '../data/models/aggregated_item.dart';
import '../preference/user_preferences.dart';
import 'platform_detection.dart';

/// A standalone trailer carries the item type, one attached to a film carries
/// the extra type, and which of the two arrives depends on how the server
/// found the file.
bool isTrailerFeature(AggregatedItem feature) =>
    feature.rawData['ExtraType'] == 'Trailer' || feature.type == 'Trailer';

/// Whether a trailer exists for [item], from any of the places one can live.
///
/// The count is checked before the trailer links, since reading it avoids
/// building a list. Special features come last and only answer for servers
/// that file a trailer as an ordinary extra, because a server that keeps the
/// two apart leaves trailers out of that list.
bool hasTrailer(AggregatedItem item, List<AggregatedItem> features) {
  if (item.localTrailerCount > 0) return true;
  if (item.remoteTrailers.isNotEmpty) return true;
  return features.any(isTrailerFeature);
}

/// Whether the details screen hands remote trailers to the system instead of
/// the in-app player, the way the official Jellyfin TV app does.
bool opensTrailersExternally({String? url}) {
  if (PlatformDetection.isWindows && url != null && youtubeTrailerId(url) != null) {
    return false;
  }
  final prefs = GetIt.instance<UserPreferences>();
  return prefs.effectiveDetailTrailersExternal;
}

bool canAutoFallbackToYouTube() =>
    (PlatformDetection.isAndroid || PlatformDetection.isWindows) &&
    !GetIt.instance<UserPreferences>().get(UserPreferences.kidsModeEnabled);

/// Windows and Android need a resolved media URL, not YouTube's HTML page.
String? unresolvedTrailerPlaybackUrl(String url) =>
    (PlatformDetection.isAndroid || PlatformDetection.isWindows) &&
            youtubeTrailerId(url) != null
        ? null
        : url;

String? youtubeTrailerId(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !['http', 'https'].contains(uri.scheme)) return null;
  final host = uri.host.toLowerCase();
  String? id;
  if (host == 'youtu.be') {
    id = uri.pathSegments.firstOrNull;
  } else if (['youtube.com', 'www.youtube.com', 'm.youtube.com',
      'youtube-nocookie.com', 'www.youtube-nocookie.com'].contains(host)) {
    id = uri.queryParameters['v'];
    if (id == null && uri.pathSegments.length == 2 &&
        ['embed', 'shorts', 'live'].contains(uri.pathSegments.first)) {
      id = uri.pathSegments.last;
    }
  }
  return id != null && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id)
      ? id : null;
}

/// Hands [url] to whatever the system offers, the YouTube app on TV, the
/// browser on desktop, a new tab on web. Returns false when nothing accepted
/// it so the caller can fall back to the in-app player.
Future<bool> launchTrailerExternally(String url) async {
  try {
    final videoId = youtubeTrailerId(url);
    if (PlatformDetection.isAndroid && videoId != null) {
      return await const MethodChannel('org.moonfin.androidtv/platform')
          .invokeMethod<bool>('launchYouTube', {'videoId': videoId}) ?? false;
    }
    return await launchUrl(
      Uri.parse(url),
      mode: PlatformDetection.isWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    ).timeout(const Duration(seconds: 5), onTimeout: () => false);
  } catch (_) {
    return false;
  }
}
