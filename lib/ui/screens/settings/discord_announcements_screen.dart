import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/services/discord_request_bridge.dart';

import '../../../data/services/discord_stage_announcer.dart';
import 'settings_app_bar.dart';

class DiscordAnnouncementsScreen extends StatefulWidget {
  const DiscordAnnouncementsScreen({super.key});
  @override
  State<DiscordAnnouncementsScreen> createState() =>
      _DiscordAnnouncementsScreenState();
}

class _DiscordAnnouncementsScreenState
    extends State<DiscordAnnouncementsScreen> {
  final _service = DiscordStageAnnouncer.instance;
  final _url = TextEditingController();
  final _role = TextEditingController();
  bool _busy = false;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _loadCustomization();
  }

  Future<void> _loadCustomization() async {
    await _service.load();
    if (mounted) {
      setState(() => _role.text = _service.roleId ?? '');
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _role.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() operation) async {
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: buildSettingsAppBar(context, const Text('Discord announcements')),
    body: ListenableBuilder(
      listenable: _service,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Announce when movies and episodes start or finish in the Discord channel selected by your webhook.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Use a different webhook to announce in a different channel. Role pings are optional.',
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _url,
            obscureText: !_visible,
            enableSuggestions: false,
            autocorrect: false,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Discord webhook URL',
              hintText: _service.configured
                  ? 'Webhook saved. Enter a new URL to replace it.'
                  : 'https://discord.com/api/webhooks/…',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _visible ? 'Hide URL' : 'Show URL',
                icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _visible = !_visible),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'The URL is stored securely on this Windows account. Saving verifies the webhook with Discord. Its channel is selected in the Discord webhook settings.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: _busy || !_service.ready
                    ? null
                    : () => _run(() async {
                        await _service.save(_url.text);
                        _url.clear();
                      }),
                child: const Text('Save webhook'),
              ),
              OutlinedButton(
                onPressed: _busy || !_service.configured
                    ? null
                    : () => _run(_service.sendTest),
                child: Text(
                  _service.roleId == null
                      ? 'Send test announcement'
                      : 'Send test (pings saved role)',
                ),
              ),
              TextButton(
                onPressed: _busy || !_service.configured
                    ? null
                    : () => _run(() async {
                        await _service.forget();
                        _role.clear();
                      }),
                child: const Text('Remove webhook'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Announcement customization',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _role,
            enabled: !_busy && _service.ready,
            keyboardType: TextInputType.number,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Role ID to ping (optional)',
              hintText: 'Leave blank for no role pings',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Only new-item announcements ping this saved role. Finished messages never ping anyone. The role must belong to the webhook server and allow mentions.',
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: _busy || !_service.ready
                  ? null
                  : () => _run(() => _service.saveRole(_role.text)),
              child: const Text('Save customization'),
            ),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Announce to Discord'),
            subtitle: const Text(
              'Turn on when you stream in Discord. Resets to off when SpeshTV launches.',
            ),
            value: _service.enabled,
            onChanged: _busy || !_service.configured
                ? null
                : _service.setEnabled,
          ),
          const SizedBox(height: 12),
          Text(_service.status),
          const SizedBox(height: 32),
          ListenableBuilder(
            listenable: DiscordRequestBridge.instance,
            builder: (context, _) {
              final bridge = DiscordRequestBridge.instance;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discord chat requests',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable chat requests'),
                    subtitle: const Text(
                      'Run the bundled request bot on this PC. Turns off when SpeshTV closes.',
                    ),
                    value: bridge.enabled,
                    onChanged: _busy
                        ? null
                        : (value) => _run(() => bridge.setEnabled(value)),
                  ),
                  const Text(
                    'Requesters choose a movie, or series / season / episode, and confirm it. Standby requests start playback; requests made during playback join the queue.',
                  ),
                  const SizedBox(height: 12),
                  Text(bridge.status),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: !bridge.enabled || bridge.token == null
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(text: bridge.token!),
                            );
                            if (context.mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Connection token copied. Paste it into the bot .env file.',
                                  ),
                                ),
                              );
                          },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy connection token'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Local bot connection: ${DiscordRequestBridge.endpoint}. Setup instructions are in Discord-Request-Bot/README.md inside the portable ZIP.',
                  ),
                ],
              );
            },
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    ),
  );
}
