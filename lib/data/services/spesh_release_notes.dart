import 'package:flutter/services.dart';

/// The same bundled Markdown is used in-app and for this Windows release.
class SpeshReleaseNotes {
  static Future<String> load({String? version, AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    try {
      version ??= RegExp(
        r'^version:\s*([^\s]+)',
        multiLine: true,
      ).firstMatch(await assets.loadString('pubspec.yaml'))?.group(1);
      if (version != null &&
          RegExp(r'^\d+\.\d+\.\d+\+\d+$').hasMatch(version)) {
        final notes = await assets.loadString(
          'assets/release_notes/$version.md',
        );
        if (notes.trim().isNotEmpty) return notes;
      }
    } catch (_) {
      /* An older or incomplete bundle still gets useful copy. */
    }
    return '# What’s New in SpeshTV\n\nRelease notes are not available for this build. '
        'You can continue using SpeshTV normally. Check the SpeshTV Windows release page for details.';
  }
}
