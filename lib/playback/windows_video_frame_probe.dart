import 'package:flutter/widgets.dart';

/// Windows inactive means unfocused, not hidden. Visible video still renders.
bool windowsVideoWatchVisible(AppLifecycleState? state) =>
    state == null ||
    state == AppLifecycleState.resumed ||
    state == AppLifecycleState.inactive;

bool windowsVideoWatchNeedsReset(
  AppLifecycleState? before,
  AppLifecycleState after,
) => windowsVideoWatchVisible(before) != windowsVideoWatchVisible(after);

class WindowsVideoFrameProbe {
  WindowsVideoFrameProbe.fromMap(Map? value) {
    if (value?['schema'] is int) schema = value!['schema'] as int;
    if (value == null || value['schema'] != 2) {
      status = 'native_schema_mismatch';
      return;
    }
    if (value['minimized'] == true || value['visible'] == false) {
      status = 'native_hidden';
      return;
    }
    if (value['minimized'] is! bool || value['visible'] is! bool) {
      status = 'native_visibility_unknown';
      return;
    }
    final raw = value['fresh'];
    if (raw is! int || raw < 0) {
      status = 'native_output_unavailable';
      return;
    }
    fresh = raw;
    status = raw == 0 ? 'awaiting_first_frame' : 'texture';
    stats = [
      for (final key in ['rendered', 'redraw', 'repeat', 'infoErrors'])
        if (value[key] is int) '$key=${value[key]}',
    ].join(' ');
  }
  String status = 'not_sampled';
  int? fresh;
  int? schema;
  String stats = '';
  String? get signal => fresh == null ? null : 'texture:$fresh';
}
