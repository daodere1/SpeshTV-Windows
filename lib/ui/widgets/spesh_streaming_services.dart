import '../navigation/destinations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    return Semantics(
      label: name,
      child: SvgPicture.asset(
        'assets/icons/streaming/$slug.svg',
        width: 36,
        height: 28,
        colorFilter: name == 'Peacock'
            ? null
            : const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      ),
    );
  }
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
Future<String?> pickSpeshStudio(BuildContext context) => showModalBottomSheet<String>(
  context: context,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const Expanded(child: Text('Studios & streaming services',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
        CloseButton(),
      ]),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final service in speshStreamingServices)
          SizedBox(width: 76, height: 64, child: IconButton.filledTonal(
            tooltip: service.name,
            onPressed: () => Navigator.of(context).pop(service.name),
            icon: StreamingServiceIcon(service.name),
          )),
      ]),
    ]),
  ),
);
