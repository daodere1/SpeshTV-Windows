import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../data/services/spesh_release_notes.dart';
import 'settings_app_bar.dart';

class SpeshWhatsNewScreen extends StatefulWidget {
  const SpeshWhatsNewScreen({super.key});
  @override
  State<SpeshWhatsNewScreen> createState() => _SpeshWhatsNewScreenState();
}

class _SpeshWhatsNewScreenState extends State<SpeshWhatsNewScreen> {
  late final _notes = SpeshReleaseNotes.load();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: buildSettingsAppBar(context, const Text('What’s New')),
    body: FutureBuilder<String>(
      future: _notes,
      builder: (context, snapshot) => snapshot.hasData
          ? Markdown(
              data: snapshot.data!,
              selectable: true,
              padding: const EdgeInsets.all(24),
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
            )
          : const Center(child: CircularProgressIndicator()),
    ),
  );
}
