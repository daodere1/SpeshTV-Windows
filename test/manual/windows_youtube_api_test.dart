import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:moonfin/ui/widgets/windows_youtube_trailer.dart';
import 'package:moonfin/util/webview_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final profile = await Directory.systemTemp.createTemp('speshtv-api-test-');
    gWebViewEnvironment = await WebViewEnvironment.create(
      settings: WebViewEnvironmentSettings(userDataFolder: profile.path),
    ).timeout(const Duration(seconds: 15));
  } catch (_) {
    runApp(const MaterialApp(home: Scaffold(body: Center(child: Text(
      'WebView2 could not start. Check that Microsoft Edge WebView2 Runtime is installed.',
    )))));
    return;
  }
  runApp(const MaterialApp(home: ApiTrailerTest()));
}

class ApiTrailerTest extends StatefulWidget {
  const ApiTrailerTest({super.key});
  @override
  State<ApiTrailerTest> createState() => _ApiTrailerTestState();
}

class _ApiTrailerTestState extends State<ApiTrailerTest> {
  final _key = TextEditingController();
  final _query = TextEditingController(text: 'Coyote vs Acme official trailer');
  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20)));
  bool _busy = false;
  String _status = '';
  List<Map<String, String>> _videos = [];
  String? _selected;

  Future<void> _search() async {
    if (_busy || _key.text.trim().isEmpty || _query.text.trim().isEmpty) return;
    setState(() { _busy = true; _status = 'Searching'; _selected = null; _videos = []; });
    try {
      // No logging interceptors: the key is sent only to Google's API.
      final response = await _dio.get<Map<String, dynamic>>(
        'https://www.googleapis.com/youtube/v3/search',
        queryParameters: {'part': 'snippet', 'type': 'video',
          'videoEmbeddable': 'true', 'maxResults': 5, 'q': _query.text.trim(),
          'key': _key.text.trim()},
      );
      final videos = <Map<String, String>>[];
      for (final item in response.data?['items'] as List? ?? []) {
        final id = item['id']?['videoId'];
        final title = item['snippet']?['title'];
        if (id is String && title is String) videos.add({'id': id, 'title': title});
      }
      if (!mounted) return;
      setState(() { _videos = videos; _status = 'Search succeeded: ${videos.length} results'; });
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      // Never print the exception or request URL, which contains the key.
      setState(() => _status = status == null
        ? 'Search failed: network or timeout'
        : 'Search failed: HTTP $status. Check API enablement, key restrictions and quota.');
    } catch (_) {
      if (mounted) setState(() => _status = 'Search failed: unexpected response');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _key.clear();
    _key.dispose();
    _query.dispose();
    _dio.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SpeshTV YouTube API Test')),
    body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      TextField(controller: _key, obscureText: true, autocorrect: false,
        enableSuggestions: false, decoration: const InputDecoration(labelText: 'YouTube Data API v3 key')),
      TextField(controller: _query, decoration: const InputDecoration(labelText: 'Trailer search')),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _busy ? null : _search,
        icon: const Icon(Icons.search), label: const Text('Search with API key')),
      SizedBox(height: 100, child: SingleChildScrollView(child: SelectableText(_status))),
      if (_selected == null) Expanded(child: ListView(children: _videos.map((video) => ListTile(
        title: Text(video['title']!), trailing: const Icon(Icons.play_arrow),
        onTap: () => setState(() { _selected = video['id']; _status = 'Embedded playback starting'; }),
      )).toList()))
      else ...[
        TextButton.icon(onPressed: () => setState(() => _selected = null),
          icon: const Icon(Icons.arrow_back), label: const Text('Back to results')),
        Expanded(child: Center(child: AspectRatio(aspectRatio: 16 / 9,
          child: WindowsYouTubeTrailer(key: ValueKey(_selected), videoId: _selected!,
            onReady: () {}, onCompleted: () {}, onUnavailable: () {},
            onDiagnostic: (event) {
              // WebView callbacks can fire during widget creation.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _status += '\nPlayer: $event');
              });
            },
          ),
        ))),
      ],
    ])),
  );
}
