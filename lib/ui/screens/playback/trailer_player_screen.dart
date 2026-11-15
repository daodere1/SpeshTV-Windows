import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:playback_core/playback_core.dart';

import '../../../data/models/aggregated_item.dart';
import '../../../data/services/sponsorblock_service.dart';
import '../../../data/services/youtube_stream_resolver.dart';
import '../../../l10n/app_localizations.dart';
import '../../../playback/appletv_preview_player.dart';
import '../../../playback/mpv_client_certificate.dart';
import '../../../preference/user_preferences.dart';
import '../../../util/platform_detection.dart';
import '../../../util/detail_trailer.dart';
import '../../screensaver/screensaver_controller.dart';
import '../../widgets/adaptive/sf_symbol.dart';
import '../../widgets/web_youtube_trailer.dart';
import '../../widgets/windows_youtube_trailer.dart';

class TrailerPlayerScreen extends StatefulWidget {
  final String? videoId;
  final String? trailerUrl;
  final bool retryAlternative;

  const TrailerPlayerScreen({
    super.key,
    this.videoId,
    this.trailerUrl,
    this.retryAlternative = false,
  });

  @override
  State<TrailerPlayerScreen> createState() => _TrailerPlayerScreenState();
}

class _TrailerPlayerScreenState extends State<TrailerPlayerScreen> {
  static const _openTimeout = Duration(seconds: 12);
  static const _resolveTimeout = Duration(seconds: 10);

  Player? _player;
  Timer? _startupTimer;
  StreamSubscription<Duration>? _startupPositionSub;
  VideoController? _controller;
  AppleTvPreviewPlayer? _appleTvPlayer;
  StreamSubscription<void>? _appleTvCompletedSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<String>? _errorSub;
  bool _closing = false;
  bool _youtubeFallbackAttempted = false;
  StreamSubscription<Duration>? _sponsorBlockPositionSub;
  final _sponsorBlockService = SponsorBlockService();
  final _sponsorBlockSession = SponsorBlockSkipSession();
  bool _loading = true;
  String? _error;
  String? _webVideoId;
  bool _useEmbeddedYouTube = false;
  bool _embedFallbackTriggered = false;
  bool _sponsorBlockSeekInFlight = false;
  int _sponsorBlockToken = 0;
  final _screensaverController = GetIt.instance<ScreensaverController>();
  final _showCaptions = GetIt.instance<UserPreferences>().get(
    UserPreferences.mediaBarTrailerCaptions,
  );

  bool get _supportsEmbeddedYouTubePlatform {
    return PlatformDetection.isWindows ||
        PlatformDetection.isIOS ||
        PlatformDetection.isMacOS;
  }

  @override
  void initState() {
    super.initState();
    // Keep the screen awake and the screensaver disarmed while a trailer plays,
    // matching the other full-screen players.
    _screensaverController.setPlaybackActive(true);
    // Background music would otherwise keep playing under the trailer.
    final manager = GetIt.instance<PlaybackManager>();
    final current = manager.queueService.currentItem;
    if (current is AggregatedItem && current.isAudioLike) {
      unawaited(manager.stop(userInitiated: false));
    }
    final resolvedVideoId = _resolvedVideoId();

    if (kIsWeb) {
      if (resolvedVideoId == null || resolvedVideoId.isEmpty) {
        _error = AppLocalizations.of(context).unableToLoadTrailerStream;
      } else {
        _webVideoId = resolvedVideoId;
      }
      _loading = false;
      return;
    }

    if (_supportsEmbeddedYouTubePlatform &&
        resolvedVideoId != null &&
        resolvedVideoId.isNotEmpty) {
      _useEmbeddedYouTube = true;
      _webVideoId = resolvedVideoId;
      _loading = true;
      return;
    }

    _startStreamPlaybackPath();
  }

  String? _resolvedVideoId() {
    final videoId = widget.videoId;
    if (videoId != null && videoId.isNotEmpty) {
      return videoId;
    }
    final trailerUrl = widget.trailerUrl;
    if (trailerUrl == null || trailerUrl.isEmpty) {
      return null;
    }
    return YouTubeStreamResolver.extractVideoId(trailerUrl);
  }

  void _startStreamPlaybackPath() {
    if (PlatformDetection.useApplePreviewPlayer) {
      unawaited(_openTrailerAppleTv());
      return;
    }
    _startupTimer?.cancel();
    _startupTimer = Timer(const Duration(seconds: 25), () {
      if (mounted && !_closing) {
        _failTrailer(AppLocalizations.of(context).trailerTimedOut);
      }
    });
    _player ??= Player(configuration: const PlayerConfiguration(libass: false));
    _startupPositionSub ??= _player!.stream.position.listen((position) {
      if (position > Duration.zero) _startupTimer?.cancel();
    });
    _controller ??= VideoController(
      _player!,
      configuration: VideoControllerConfiguration(
        hwdec: PlatformDetection.isLinux ? 'auto-safe' : null,
      ),
    );
    _completedSub ??= _player!.stream.completed.listen((completed) {
      if (completed && mounted && !_closing) {
        _closing = true;
        Navigator.of(context).pop(true);
      }
    });
    _errorSub ??= _player!.stream.error.listen((_) {
      if (mounted) {
        _failTrailer(AppLocalizations.of(context).playbackFailedForTrailer);
      }
    });
    unawaited(_openTrailer());
  }

  void _failTrailer(String message) {
    if (!mounted || _closing) return;
    _startupTimer?.cancel();
    setState(() {
      _loading = false;
      _error = message;
    });
    final videoId = _resolvedVideoId();
    if (!_youtubeFallbackAttempted &&
        canAutoFallbackToYouTube() &&
        videoId != null &&
        youtubeTrailerId('https://www.youtube.com/watch?v=$videoId') != null) {
      _closing = true;
      _youtubeFallbackAttempted = true;
      unawaited(_launchYouTubeFallback(videoId, message));
      return;
    }
    _showTrailerFailure(message);
  }

  Future<void> _launchYouTubeFallback(String videoId, String message) async {
    _clearSponsorBlockTracking();
    try {
      await _player?.stop().timeout(const Duration(seconds: 2));
    } catch (_) {}
    if (!mounted) return;
    final opened = await launchTrailerExternally(
      'https://www.youtube.com/watch?v=$videoId',
    );
    if (!mounted) return;
    if (opened) {
      // Mark this attempt handled so Seerr does not launch another candidate.
      Navigator.of(context).pop(true);
    } else {
      _closing = false;
      _showTrailerFailure(message);
    }
  }

  void _showTrailerFailure(String message) {
    if (!mounted) return;
    if (widget.retryAlternative) {
      _closing = true;
      Navigator.of(context).pop(false);
    } else {
      setState(() {
        _loading = false;
        _error = message;
      });
    }
  }

  void _onEmbeddedPlaybackStarted() {
    if (!mounted || !_loading) {
      return;
    }
    setState(() => _loading = false);
  }

  void _fallBackToStreamPlayback() {
    if (_embedFallbackTriggered || !_useEmbeddedYouTube) {
      return;
    }
    if (PlatformDetection.isAndroid || PlatformDetection.isWindows) {
      _embedFallbackTriggered = true;
      _failTrailer(AppLocalizations.of(context).playbackFailedForTrailer);
      return;
    }
    // AVFoundation cannot decode what the resolver pulls out of YouTube, so
    // on Apple the embed is the only thing that can play this. Leave it up for
    // the viewer to start rather than falling back to a stream path with
    // nothing behind it.
    if (PlatformDetection.useApplePreviewPlayer) {
      if (_loading) setState(() => _loading = false);
      return;
    }
    _embedFallbackTriggered = true;
    setState(() {
      _useEmbeddedYouTube = false;
      _error = null;
      _loading = true;
    });
    _startStreamPlaybackPath();
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    _startupPositionSub?.cancel();
    _screensaverController.setPlaybackActive(false);
    _sponsorBlockPositionSub?.cancel();
    _appleTvCompletedSub?.cancel();
    _completedSub?.cancel();
    _errorSub?.cancel();
    unawaited(_appleTvPlayer?.dispose());
    _player?.stop();
    _player?.dispose();
    super.dispose();
  }

  Future<
    ({
      String? streamUrl,
      String? sponsorBlockVideoId,
      bool useYouTubeHeaders,
      String? audioLanguage,
    })
  >
  _resolveStreamUrl() async {
    String? streamUrl;
    String? sponsorBlockVideoId;
    bool useYouTubeHeaders = false;
    String? audioLanguage;

    if (widget.videoId != null && widget.videoId!.isNotEmpty) {
      sponsorBlockVideoId = widget.videoId;
      final stream = await YouTubeStreamResolver.resolve(
        widget.videoId!,
        maxHeight: PlatformDetection.isAndroid ? 360 : null,
      ).timeout(_resolveTimeout, onTimeout: () => null);
      streamUrl = stream?.url;
      audioLanguage = stream?.audioLanguage;
      if (streamUrl != null && streamUrl.isNotEmpty) {
        useYouTubeHeaders = true;
      } else {
        streamUrl = unresolvedTrailerPlaybackUrl(
          'https://www.youtube.com/watch?v=${widget.videoId!}',
        );
        useYouTubeHeaders = false;
      }
    } else if (widget.trailerUrl != null && widget.trailerUrl!.isNotEmpty) {
      final trailerUrl = widget.trailerUrl!;
      final youtubeVideoId = YouTubeStreamResolver.extractVideoId(trailerUrl);
      sponsorBlockVideoId = youtubeVideoId;
      final stream = await YouTubeStreamResolver.resolveFromUrl(
        trailerUrl,
        maxHeight: PlatformDetection.isAndroid ? 360 : null,
      ).timeout(_resolveTimeout, onTimeout: () => null);
      streamUrl = stream?.url;
      audioLanguage = stream?.audioLanguage;
      if (streamUrl != null && streamUrl.isNotEmpty) {
        useYouTubeHeaders = youtubeVideoId != null;
      } else {
        streamUrl = unresolvedTrailerPlaybackUrl(trailerUrl);
        useYouTubeHeaders = false;
      }
    }

    return (
      streamUrl: streamUrl,
      sponsorBlockVideoId: sponsorBlockVideoId,
      useYouTubeHeaders: useYouTubeHeaders,
      audioLanguage: audioLanguage,
    );
  }

  Future<void> _openTrailerAppleTv() async {
    final resolved = await _resolveStreamUrl();
    if (!mounted) return;
    final streamUrl = resolved.streamUrl;
    if (streamUrl == null || streamUrl.isEmpty) {
      final l10n = AppLocalizations.of(context);
      setState(() {
        _loading = false;
        _error = l10n.unableToLoadTrailerStream;
      });
      return;
    }

    try {
      final player = AppleTvPreviewPlayer();
      _appleTvPlayer = player;
      _appleTvCompletedSub = player.completedStream.listen((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      await player
          .open(
            streamUrl,
            headers: resolved.useYouTubeHeaders
                ? YouTubeStreamResolver.youtubeHeaders
                : null,
            volume: 100,
            audioLanguage: resolved.audioLanguage,
          )
          .timeout(_openTimeout);
      if (!mounted) {
        await player.dispose();
        return;
      }
      await player.resume();
      if (!mounted) {
        await player.dispose();
        return;
      }
      setState(() => _loading = false);
    } on TimeoutException {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _loading = false;
        _error = l10n.trailerTimedOut;
      });
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _loading = false;
        _error = l10n.playbackFailedForTrailer;
      });
    }
  }

  Future<void> _openTrailer() async {
    try {
      final resolved = await _resolveStreamUrl();
      final streamUrl = resolved.streamUrl;
      final sponsorBlockVideoId = resolved.sponsorBlockVideoId;
      final useYouTubeHeaders = resolved.useYouTubeHeaders;

      if (!mounted || _closing) return;

      if (streamUrl == null || streamUrl.isEmpty) {
        final l10n = AppLocalizations.of(context);
        _failTrailer(l10n.unableToLoadTrailerStream);
        return;
      }

      final media = useYouTubeHeaders
          ? Media(streamUrl, httpHeaders: YouTubeStreamResolver.youtubeHeaders)
          : Media(streamUrl);
      await YouTubeStreamResolver.preferAudioLanguage(
        _player!,
        resolved.audioLanguage,
      ).timeout(const Duration(seconds: 3));
      await YouTubeStreamResolver.showCaptions(
        _player!,
        _showCaptions,
        language: GetIt.instance<UserPreferences>().get(
          UserPreferences.defaultSubtitleLanguage,
        ),
      ).timeout(const Duration(seconds: 3));
      await applyMpvClientCertificate(_player!, streamUrl);
      await _player!.open(media).timeout(_openTimeout);
      if (!mounted || _closing) return;
      setState(() {
        _loading = false;
      });

      if (sponsorBlockVideoId != null && sponsorBlockVideoId.isNotEmpty) {
        _startSponsorBlockTracking(sponsorBlockVideoId);
      } else {
        _clearSponsorBlockTracking();
      }
    } on TimeoutException {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      _failTrailer(l10n.trailerTimedOut);
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      _failTrailer(l10n.playbackFailedForTrailer);
    }
  }

  void _clearSponsorBlockTracking() {
    _sponsorBlockToken++;
    _sponsorBlockPositionSub?.cancel();
    _sponsorBlockPositionSub = null;
    _sponsorBlockSeekInFlight = false;
    _sponsorBlockSession.clear();
  }

  void _startSponsorBlockTracking(String videoId) {
    final player = _player;
    if (player == null) {
      _clearSponsorBlockTracking();
      return;
    }

    _clearSponsorBlockTracking();
    final token = ++_sponsorBlockToken;
    _sponsorBlockPositionSub = player.stream.position.listen((position) {
      _handleSponsorBlockPosition(position);
    });

    unawaited(() async {
      final segments = await _sponsorBlockService.fetchSegments(
        videoId,
        categories: sponsorBlockDefaultCategories,
      );
      if (!mounted || token != _sponsorBlockToken) {
        return;
      }
      _sponsorBlockSession.setSegments(segments);
    }());
  }

  void _handleSponsorBlockPosition(Duration position) {
    final player = _player;
    if (player == null || _sponsorBlockSeekInFlight) {
      return;
    }

    final decision = _sponsorBlockSession.checkPosition(position);
    if (!decision.shouldSkip || decision.skipTo == null) {
      return;
    }

    final skipTo = decision.skipTo!;
    if (skipTo <= position + const Duration(milliseconds: 500)) {
      return;
    }

    _sponsorBlockSeekInFlight = true;
    unawaited(() async {
      try {
        await player.seek(skipTo);
      } catch (_) {
      } finally {
        _sponsorBlockSeekInFlight = false;
      }
    }());
  }

  void _closeTrailer() {
    if (_closing || !mounted) return;
    _closing = true;
    _startupTimer?.cancel();
    _startupPositionSub?.cancel();
    _sponsorBlockPositionSub?.cancel();
    unawaited(_player?.stop());
    unawaited(_appleTvPlayer?.stop());
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _closeTrailer,
        const SingleActivator(LogicalKeyboardKey.goBack): _closeTrailer,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black,
                  child:
                      ((kIsWeb || _useEmbeddedYouTube) && _webVideoId != null)
                      ? Center(
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: PlatformDetection.isWindows
                                ? WindowsYouTubeTrailer(
                                    videoId: _webVideoId!,
                                    onReady: _onEmbeddedPlaybackStarted,
                                    onCompleted: () {
                                      if (mounted && !_closing) {
                                        _closing = true;
                                        Navigator.of(context).pop(true);
                                      }
                                    },
                                    onUnavailable: _fallBackToStreamPlayback,
                                  )
                                : WebYouTubeTrailer(
                                    videoId: _webVideoId!,
                                    suspended: _error != null,
                                    muted: false,
                                    showCaptions: _showCaptions,
                                    loop: false,
                                    showControls: true,
                                    autoplayTimeout: const Duration(
                                      seconds: 15,
                                    ),
                                    onPlaybackStarted:
                                        _onEmbeddedPlaybackStarted,
                                    onCompleted: () {
                                      if (mounted && !_closing) {
                                        _closing = true;
                                        Navigator.of(context).pop(true);
                                      }
                                    },
                                    onEmbeddedUnavailable: _useEmbeddedYouTube
                                        ? _fallBackToStreamPlayback
                                        : null,
                                    onAutoplayFailed: _useEmbeddedYouTube
                                        ? _fallBackToStreamPlayback
                                        : null,
                                  ),
                          ),
                        )
                      : PlatformDetection.useApplePreviewPlayer
                      ? (_appleTvPlayer?.textureId != null
                            ? FittedBox(
                                fit: BoxFit.contain,
                                clipBehavior: Clip.hardEdge,
                                child: SizedBox(
                                  width: 1920,
                                  height: 1080,
                                  child: Texture(
                                    textureId: _appleTvPlayer!.textureId!,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink())
                      : (_controller != null
                            ? Video(
                                controller: _controller!,
                                controls: AdaptiveVideoControls,
                                fit: BoxFit.contain,
                                pauseUponEnteringBackgroundMode: false,
                                fill: Colors.black,
                              )
                            : const SizedBox.shrink()),
                ),
              ),
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        if (_resolvedVideoId() != null) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Open in YouTube'),
                            onPressed: () async {
                              final opened = await launchTrailerExternally(
                                'https://www.youtube.com/watch?v=${_resolvedVideoId()}',
                              );
                              if (opened &&
                                  mounted &&
                                  context.mounted &&
                                  !_closing) {
                                _closing = true;
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: IconButton.filledTonal(
                      key: const ValueKey('trailer_back'),
                      tooltip: 'Back',
                      icon: const AdaptiveIcon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                      onPressed: _closeTrailer,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
