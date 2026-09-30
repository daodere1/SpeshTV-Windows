import 'dart:convert';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'spesh_view_preferences.dart';

Preference<String> speshRecentChannelsPreference(String server, String? user) =>
    Preference(key: speshViewScope(server, user, 'recent-channels'), defaultValue: '');

List<String> decodeRecentChannels(String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is! List) return const [];
    return decoded.whereType<String>().where((id) => id.isNotEmpty).toSet().take(20).toList();
  } catch (_) {
    return const [];
  }
}

String rememberRecentChannel(String saved, String id) => jsonEncode(
    [id, ...decodeRecentChannels(saved).where((previous) => previous != id)].take(20).toList());

String? previousRecentChannel(List<String> history, String current, Set<String> available) {
  for (final id in history) {
    if (id != current && available.contains(id)) return id;
  }
  return null;
}

/// Playing/buffering flags alone do not prove that media was delivered.
class ConfirmedChannelPlayback {
  Duration? _baseline;
  bool _recorded = false;
  void reset() { _baseline = null; _recorded = false; }
  bool sample(Duration position, {required bool playing}) {
    if (_recorded) return false;
    if (!playing) { _baseline = null; return false; }
    if (_baseline == null || position < _baseline!) {
      _baseline = position;
      return false;
    }
    if (position - _baseline! < const Duration(seconds: 2)) return false;
    _recorded = true;
    return true;
  }
}
