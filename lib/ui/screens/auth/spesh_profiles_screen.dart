import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../util/focus/dpad_keys.dart';

import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/repositories/session_repository.dart';
import '../../../data/services/spesh_profile_service.dart';
import '../../navigation/destinations.dart';
import '../../widgets/spesh_brand.dart';
import '../../widgets/spesh_profile_avatar.dart';

class SpeshProfilesScreen extends StatefulWidget {
  const SpeshProfilesScreen({super.key, this.api, this.session});
  final SpeshProfilesApi? api;
  final SessionRepository? session;
  @override
  State<SpeshProfilesScreen> createState() => _SpeshProfilesScreenState();
}

class _SpeshProfilesScreenState extends State<SpeshProfilesScreen> {
  late final SessionRepository _session =
      widget.session ?? GetIt.instance<SessionRepository>();
  late final SpeshProfilesApi _api =
      widget.api ?? _session.createSpeshProfilesApi();
  List<SpeshViewingProfile>? _profiles;
  bool _busy = false, _manage = false, _compatible = true;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    if (widget.api == null) _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _api.list();
      if (mounted && generation == _generation)
        setState(() {
          _profiles = result;
          _compatible = true;
        });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      final unsupported =
          e is DioException &&
          (e.response == null ||
              [404, 405, 501].contains(e.response?.statusCode));
      setState(() {
        _compatible = !unsupported;
        _error = unsupported
            ? 'Viewing profiles are unavailable. Connect to compatible Spesh Core, or continue with your original account.'
            : 'Profiles could not be loaded. Please retry or sign out.';
      });
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _choose(SpeshViewingProfile profile) async {
    if (_manage) {
      await _edit(profile);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final selection = await _api.select(profile);
      if (!mounted) return;
      await _session.activateSpeshProfile(selection, expectedOwner: _api.owner);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'The profile could not be opened. Please retry.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([SpeshViewingProfile? profile]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _Editor(api: _api, profile: profile),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _continue() async {
    setState(() => _busy = true);
    try {
      await _session.continueWithSpeshOwner();
    } catch (_) {
      if (mounted)
        setState(
          () =>
              _error = 'Your account could not be restored. Retry or sign out.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SpeshBrand(height: 48),
                  const SizedBox(height: 32),
                  Text(
                    _manage ? 'Manage profiles' : 'Who’s watching?',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 24,
                    runSpacing: 24,
                    children: [
                      for (var i = 0; i < (_profiles?.length ?? 0); i++)
                        SizedBox(
                          width: 148,
                          child: Column(
                            children: [
                              OutlinedButton(
                                autofocus: i == 0,
                                onPressed: _busy
                                    ? null
                                    : () => _choose(_profiles![i]),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.all(8),
                                ),
                                child: Stack(
                                  children: [
                                    SpeshProfileAvatar(
                                      avatar: _profiles![i].avatar,
                                    ),
                                    if (_manage)
                                      const Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _profiles![i].name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      if (_profiles != null && _profiles!.length < 3)
                        SizedBox(
                          width: 148,
                          child: Column(
                            children: [
                              SizedBox(
                                height: 130,
                                width: 130,
                                child: OutlinedButton(
                                  onPressed: _busy ? null : () => _edit(),
                                  child: const Icon(Icons.add, size: 64),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text('Add profile'),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_busy) const CircularProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
                  if (!_compatible)
                    FilledButton(
                      onPressed: _busy ? null : _continue,
                      child: const Text('Continue with account'),
                    ),
                  if (_error != null)
                    TextButton(
                      onPressed: _busy ? null : _load,
                      child: const Text('Retry'),
                    ),
                  if (_profiles != null)
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _manage = !_manage),
                      child: Text(_manage ? 'Done' : 'Manage profiles'),
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await _session.destroyCurrentSession();
                            if (context.mounted)
                              context.go(Destinations.startup);
                          },
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Editor extends StatefulWidget {
  const _Editor({required this.api, this.profile});
  final SpeshProfilesApi api;
  final SpeshViewingProfile? profile;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final _name = TextEditingController(text: widget.profile?.name ?? '');
  late String _avatar = widget.profile?.avatar ?? 'blue';
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _name.text.trim().runes.length > 24) {
      setState(() => _error = 'Enter a name of 1–24 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.save(
        profile: widget.profile,
        name: _name.text,
        avatar: _avatar,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is DioException && e.response?.statusCode == 409
              ? 'This account already has three profiles.'
              : 'The profile could not be saved. Please retry.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: (_, event) {
      if (event is KeyDownEvent && event.logicalKey.isBackKey && !_busy) {
        Navigator.of(context).maybePop();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(widget.profile == null ? 'Add profile' : 'Edit profile'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _name,
                  maxLength: 24,
                  enabled: !_busy,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Profile name'),
                  onSubmitted: (_) {
                    if (!_busy) _save();
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final avatar in speshProfileAvatars)
                      Semantics(
                        label: '$avatar avatar',
                        selected: _avatar == avatar,
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _avatar = avatar),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(5),
                            side: BorderSide(
                              width: 3,
                              color: _avatar == avatar
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                            ),
                          ),
                          child: SpeshProfileAvatar(avatar: avatar, size: 56),
                        ),
                      ),
                  ],
                ),
                if (_error != null) Text(_error!),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    ),
  );
}
