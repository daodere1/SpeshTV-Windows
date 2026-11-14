import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:moonfin/ui/widgets/windows_youtube_trailer.dart';
import 'package:moonfin/util/webview_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final profile = await Directory.systemTemp.createTemp('speshtv-trailer-smoke-');
  gWebViewEnvironment = await WebViewEnvironment.create(
    settings: WebViewEnvironmentSettings(userDataFolder: profile.path),
  );
  var finishing = false;
  void finish(int code) {
    if (finishing) return;
    finishing = true;
    stdout.writeln('SMOKE_RESULT=$code');
    Timer(const Duration(seconds: 2), () => exit(code));
  }
  Timer(const Duration(seconds: 40), () => finish(2));
  runApp(MaterialApp(home: Scaffold(
    backgroundColor: Colors.black,
    body: Center(child: AspectRatio(aspectRatio: 16 / 9,
      child: WindowsYouTubeTrailer(
        videoId: 'M7lc1UVf-VE',
        onReady: () => stdout.writeln('SMOKE_READY'),
        onCompleted: () {},
        onUnavailable: () => finish(1),
        onDiagnostic: (state) {
          stdout.writeln('SMOKE_EVENT=$state');
          if (state == 'playing') finish(0);
        },
      ),
    )),
  )));
}
