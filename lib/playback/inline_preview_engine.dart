// Inline previews (media bar trailers and home row previews) always use the
// media_kit / mpv path. Media3 as an embedded preview surface has device
// specific playback problems, and mpv plays the same trailers reliably.
bool usesMedia3ForInlinePreview() => false;

bool usesEmbeddedYouTubeForInlinePreview({
  required bool available,
  required bool isAndroid,
  required bool isWeb,
  required bool isIOS,
  required bool isMacOS,
}) => available && !isAndroid && (isWeb || isIOS || isMacOS);
