import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../preference/preference_constants.dart';
import '../../preference/user_preferences.dart';
import '../../util/platform_detection.dart';
import 'spesh_brand.dart';

/// Presentation only: selecting another theme restores its existing layouts.
bool get speshCinematic =>
    speshWeb && ThemeRegistry.active.id == 'spesh-cinematic';

NavbarPosition cinematicNavbarPosition(UserPreferences prefs) =>
    speshCinematic && !PlatformDetection.useMobileUi
    ? NavbarPosition.left
    : prefs.get(UserPreferences.navbarPosition);

String cinematicMediaBarMode(UserPreferences prefs) {
  final stored = UserPreferences.normalizeMediaBarMode(
    prefs.get(UserPreferences.mediaBarMode),
  );
  // Off remains an explicit choice. Cinematic otherwise uses the existing
  // trailer player, including its audio, visibility and performance policies.
  return resolveCinematicMediaBarMode(stored, cinematic: speshCinematic);
}

String resolveCinematicMediaBarMode(String stored, {required bool cinematic}) =>
    cinematic && stored != UserPreferences.mediaBarModeOff
    ? UserPreferences.mediaBarModeMoonfin
    : stored;

class CinematicShelf extends StatelessWidget {
  const CinematicShelf({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF090A0C),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xFF202227)),
    ),
    child: child,
  );
}

class CinematicArtworkTitle extends StatelessWidget {
  const CinematicArtworkTitle({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xDD000000)],
          stops: [0.25, 1],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFF3F5F6),
              fontSize: 20,
              height: 1.1,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ),
    ),
  );
}

/// A route-sized frame keeps deep links, browser Back and the existing details
/// view model/player intact. The content gets the modal's real logical size.
class CinematicDetailFrame extends StatelessWidget {
  const CinematicDetailFrame({
    super.key,
    required this.child,
    required this.onClose,
  });
  final Widget child;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose},
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onClose,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: const ColoredBox(color: Color(0xB3000000)),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1120,
                  maxHeight: 1000,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF303238)),
                      ),
                      child: MediaQuery(
                        data: mq.copyWith(
                          size: constraints.biggest,
                          padding: EdgeInsets.zero,
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(child: child),
                            Positioned(
                              top: 16,
                              right: 16,
                              child: IconButton.filledTonal(
                                autofocus: false,
                                tooltip: MaterialLocalizations.of(context)
                                    .closeButtonTooltip,
                                onPressed: onClose,
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
