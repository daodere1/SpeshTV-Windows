import 'package:media_kit/media_kit.dart';

({Media media, bool play}) mediaKitOpenRequest(
  String url, {
  required Duration startPosition,
  required bool nativeResume,
  required bool autoPlay,
  bool isLive = false,
  Map<String, String>? headers,
}) {
  return (
    // Explicit zero clears mpv's start option when moving to a new title.
    media: Media(
      url,
      start: nativeResume && !isLive ? startPosition : null,
      httpHeaders: headers,
    ),
    play: autoPlay && (isLive || nativeResume || startPosition == Duration.zero),
  );
}
