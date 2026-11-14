import '../l10n/app_localizations.dart';
import 'package:playback_core/playback_core.dart';

String playbackMethodLabel({
  required AppLocalizations l10n,
  StreamPlayMethod? playMethod,
  List<String> transcodingReasons = const [],
  String? fallbackPlayMethod,
}) {
  if (playMethod == StreamPlayMethod.directPlay) return l10n.directPlay;
  if (playMethod == StreamPlayMethod.directStream) return l10n.directStreamRemux;
  if (playMethod == StreamPlayMethod.transcode) {
    final reasons = transcodingReasons.map((r) => r.toLowerCase()).toSet();
    if (reasons.any(const {
      'videobitratenotsupported', 'containerbitrateexceedslimit',
      'videobitrateexceedslimit', 'bitratelimitexceeded',
      'containerbitratenotsupported', 'videoresolutionnotsupported',
      'audiobitratenotsupported',
    }.contains)) return l10n.transcodingBitrateOrResolution;
    final video = reasons.any(const {
      'videocodecnotsupported', 'videoprofilenotsupported', 'videolevelnotsupported',
      'videoframeratenotsupported', 'videorangenotsupported', 'videorangetypenotsupported',
      'videobitdepthnotsupported', 'anamorphicvideonotsupported',
      'interlacedvideonotsupported', 'refframesnotsupported',
    }.contains);
    final audio = reasons.any(const {
      'audiocodecnotsupported', 'audiochannelsnotsupported', 'audioprofilenotsupported',
      'audiosampleratenotsupported', 'audiobitdepthnotsupported',
    }.contains);
    if (video && audio) return l10n.transcodingVideoAndAudio;
    if (video) return l10n.transcodingVideo;
    if (audio) return l10n.transcodingAudio;
    return l10n.transcoding;
  }
  return switch (fallbackPlayMethod) {
    'directPlay' => l10n.directPlay,
    'directStream' => l10n.directStream,
    'transcode' => l10n.transcoding,
    _ => l10n.unknown,
  };
}

/// Turns one server transcode reason into something readable, falling back to
/// the raw reason for anything the server adds later.
String transcodeReasonLabel(String reason, AppLocalizations l10n) {
  return switch (reason) {
    'ContainerNotSupported' => l10n.transcodeContainerNotSupported,
    'VideoCodecNotSupported' => l10n.transcodeVideoCodecNotSupported,
    'AudioCodecNotSupported' => l10n.transcodeAudioCodecNotSupported,
    'SubtitleCodecNotSupported' => l10n.transcodeSubtitleCodecNotSupported,
    'AudioProfileNotSupported' => l10n.transcodeAudioProfileNotSupported,
    'VideoProfileNotSupported' => l10n.transcodeVideoProfileNotSupported,
    'VideoLevelNotSupported' => l10n.transcodeVideoLevelNotSupported,
    'VideoResolutionNotSupported' => l10n.transcodeVideoResolutionNotSupported,
    'VideoBitDepthNotSupported' => l10n.transcodeVideoBitDepthNotSupported,
    'VideoFramerateNotSupported' => l10n.transcodeVideoFramerateNotSupported,
    'ContainerBitrateExceedsLimit' =>
      l10n.transcodeContainerBitrateExceedsLimit,
    'VideoBitrateExceedsLimit' => l10n.transcodeVideoBitrateExceedsLimit,
    'AudioBitrateExceedsLimit' => l10n.transcodeAudioBitrateExceedsLimit,
    'AudioChannelsNotSupported' => l10n.transcodeAudioChannelsNotSupported,
    _ => reason,
  };
}
