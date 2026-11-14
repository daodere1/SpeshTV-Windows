import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../util/webview_environment.dart';
import '../../data/services/log_service.dart';

const windowsYouTubeAppReferrer = 'https://dev.speshmedia.speshtv/';

String windowsTrailerHtml(String videoId, String origin) {
  if (!RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(videoId)) {
    throw ArgumentError.value(videoId, 'videoId');
  }
  final uri = Uri.parse(origin);
  if (uri.scheme != 'http' || uri.host != '127.0.0.1' || !uri.hasPort) {
    throw ArgumentError.value(origin, 'origin');
  }
  return '''<!doctype html><html><head>
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>html,body,#player{margin:0;width:100%;height:100%;background:#000;overflow:hidden}</style>
</head><body><div id="player"></div>
<script>
function notify(state) {
  if (window.flutter_inappwebview) window.flutter_inappwebview.callHandler('speshTrailer', state);
}
function onYouTubeIframeAPIReady() {
  window.player = new YT.Player('player', {
    videoId:'$videoId', width:'100%', height:'100%',
    playerVars:{autoplay:1,controls:1,playsinline:1,origin:'${uri.origin}',widget_referrer:'$windowsYouTubeAppReferrer'},
    events:{onReady:function(){notify('ready');},
      onStateChange:function(e){if(e.data===1)notify('playing');if(e.data===0)notify('ended');},
      onError:function(e){notify('error:'+e.data);}}
  });
}
</script><script src="https://www.youtube.com/iframe_api"></script></body></html>''';
}

class WindowsYouTubeTrailer extends StatefulWidget {
  const WindowsYouTubeTrailer({super.key, required this.videoId,
    required this.onReady, required this.onCompleted, required this.onUnavailable,
    this.onDiagnostic});
  final String videoId;
  final VoidCallback onReady;
  final VoidCallback onCompleted;
  final VoidCallback onUnavailable;
  final ValueChanged<String>? onDiagnostic;

  @override
  State<WindowsYouTubeTrailer> createState() => _WindowsYouTubeTrailerState();
}

class _WindowsYouTubeTrailerState extends State<WindowsYouTubeTrailer> {
  HttpServer? _server;
  InAppWebViewController? _controller;
  Timer? _startup;
  String? _url;
  bool _failed = false;

  void _log(String message) {
    widget.onDiagnostic?.call(message);
    if (GetIt.instance.isRegistered<LogService>()) {
      GetIt.instance<LogService>().playback('Windows YouTube embed: $message');
    }
  }

  @override
  void initState() {
    super.initState();
    _log('starting build 30000191');
    _startup = Timer(const Duration(seconds: 25), _fail);
    unawaited(_start());
  }

  void _fail() {
    if (!mounted || _failed) return;
    _failed = true;
    _log('unavailable; using trailer fallback');
    _startup?.cancel();
    widget.onUnavailable();
  }

  Future<void> _start() async {
    try {
      // Serve only this player page on loopback. No Jellyfin credentials or
      // library data enter the WebView or this local server.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      if (!mounted) { await server.close(force: true); return; }
      _server = server;
      _log('local player page ready');
      final origin = 'http://127.0.0.1:${server.port}';
      final html = windowsTrailerHtml(widget.videoId, origin);
      server.listen((request) async {
        if (request.method != 'GET' || request.uri.path != '/') {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          request.response.headers.contentType = ContentType.html;
          request.response.headers.set('Cache-Control', 'no-store');
          request.response.write(html);
        }
        await request.response.close();
      }, onError: (_) => _fail());
      setState(() => _url = '$origin/');
    } catch (_) { _log('local player page initialization failed'); _fail(); }
  }

  @override
  void dispose() {
    _startup?.cancel();
    _log('closed');
    unawaited(_controller?.loadUrl(urlRequest: URLRequest(url: WebUri('about:blank'))).catchError((_) {}));
    unawaited(_server?.close(force: true));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_url == null || _failed) return const SizedBox.shrink();
    return InAppWebView(
      webViewEnvironment: gWebViewEnvironment,
      initialUrlRequest: URLRequest(url: WebUri(_url!)),
      initialSettings: InAppWebViewSettings(javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false, supportZoom: false,
        useShouldOverrideUrlLoading: true, useShouldInterceptRequest: true,
        applicationNameForUserAgent: 'SpeshTV-YouTubePlayer/1.0'),
      shouldInterceptRequest: (_, request) async {
        final uri = Uri.tryParse(request.url.toString());
        if (uri?.scheme == 'https' && uri?.host == 'www.youtube.com' &&
            uri!.path.startsWith('/embed/')) {
          String? referrer;
          request.headers?.forEach((name, value) {
            if (name.toLowerCase() == 'referer') referrer = value;
          });
          _log(referrer == windowsYouTubeAppReferrer
            ? 'embed request app Referer verified: $windowsYouTubeAppReferrer'
            : 'embed request app Referer missing or unexpected');
        }
        return null;
      },
      onWebViewCreated: (controller) {
        _controller = controller;
        _log('WebView created');
        controller.addJavaScriptHandler(handlerName: 'speshTrailer', callback: (args) {
          if (!mounted || _failed || args.length != 1) return null;
          final state = args.first;
          if (state is! String) return null;
          if (RegExp(r'^error:\d+$').hasMatch(state)) {
            _log(state);
            _fail();
            return null;
          }
          if (['ready', 'playing', 'ended'].contains(state)) _log(state);
          switch (args.first) {
            case 'ready':
            case 'playing':
              _startup?.cancel();
              widget.onReady();
            case 'ended': widget.onCompleted();
            case 'error': _fail();
          }
          return null;
        });
      },
      shouldOverrideUrlLoading: (_, action) async {
        if (action.isForMainFrame != true) return NavigationActionPolicy.ALLOW;
        final url = action.request.url?.toString();
        return url == _url || url == 'about:blank'
          ? NavigationActionPolicy.ALLOW : NavigationActionPolicy.CANCEL;
      },
      onLoadStop: (_, _) => _log('player page loaded'),
      onReceivedError: (_, request, _) { if (request.isForMainFrame == true) { _log('main page load failed'); _fail(); } },
    );
  }
}
