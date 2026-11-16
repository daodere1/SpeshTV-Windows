import '../navigation/destinations.dart';

import 'package:flutter/material.dart';

class StreamingServiceIcon extends StatelessWidget {
  const StreamingServiceIcon(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) {
    final slug = switch (name) {
      'Netflix' => 'netflix',
      'Disney+' => 'disneyplus',
      'Prime Video' => 'amazonprime',
      'Apple TV+' => 'appletv',
      'Hulu' => 'hulu',
      'HBO Max' => 'hbo',
      'Paramount+' => 'paramountplus',
      'Peacock' => 'peacock',
      _ => 'discoveryplus',
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/icons/streaming/$slug.png',
        width: 52,
        height: 52,
        cacheWidth: 156,
        semanticLabel: name,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Original service artwork with a persistent label for mouse, touch and remotes.
class StreamingServiceTile extends StatelessWidget {
  const StreamingServiceTile(this.name, {super.key, required this.onPressed});
  final String name;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 72,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: StreamingServiceIcon(name)),
          const SizedBox(height: 6),
          if (name == 'Paramount+')
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                name,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    ),
  );
}

/// Curated network discovery, not an assertion of regional streaming rights.
/// IDs reuse the existing Seerr network catalogue; HBO Max is TMDB network 3186.
const speshStreamingServices = <({String name, int networkId})>[
  (name: 'Netflix', networkId: 213),
  (name: 'Disney+', networkId: 2739),
  (name: 'Prime Video', networkId: 1024),
  (name: 'Apple TV+', networkId: 2552),
  (name: 'Hulu', networkId: 453),
  (name: 'HBO Max', networkId: 3186),
  (name: 'Paramount+', networkId: 4330),
  (name: 'Peacock', networkId: 3353),
  (name: 'Discovery+', networkId: 4353),
];

String streamingServiceRoute(String name) {
  final service = speshStreamingServices.firstWhere(
    (service) => service.name == name,
  );
  return Destinations.seerrBrowseWith(
    filterId: '${service.networkId}',
    filterName: service.name,
    mediaType: 'tv',
    filterType: 'network',
  );
}

/// Shared mobile chooser so toolbar and bottom navigation expose the same services.
Future<String?> pickSpeshStudio(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      showDragHandle: true,
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Studios & streaming services',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  CloseButton(),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final service in speshStreamingServices)
                    StreamingServiceTile(
                      service.name,
                      onPressed: () => Navigator.of(context).pop(service.name),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
