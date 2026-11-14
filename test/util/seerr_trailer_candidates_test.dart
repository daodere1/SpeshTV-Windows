import 'package:flutter_test/flutter_test.dart';

import '../../lib/data/services/seerr/seerr_api_models.dart';
import '../../lib/util/seerr_trailer_candidates.dart';

void main() {
  const first = SeerrVideo(site: 'YouTube', key: 'one', type: 'Trailer');
  test('preferred trailer first, distinct alternatives capped at three', () {
    expect(
      seerrTrailerCandidates(first, [
        first,
        const SeerrVideo(site: 'YouTube', key: 'two', type: 'Teaser'),
        const SeerrVideo(url: 'https://example.com/three.mp4', type: 'Trailer'),
        const SeerrVideo(site: 'YouTube', key: 'four', type: 'Trailer'),
      ]),
      [
        'https://www.youtube.com/watch?v=one',
        'https://www.youtube.com/watch?v=two',
        'https://example.com/three.mp4',
      ],
    );
  });
  test('ignores missing URLs, non-trailers and unsupported schemes', () {
    expect(
      seerrTrailerCandidates(first, [
        const SeerrVideo(type: 'Trailer'),
        const SeerrVideo(url: 'file:///private/video.mp4', type: 'Trailer'),
        const SeerrVideo(site: 'YouTube', key: 'clip', type: 'Clip'),
      ]),
      ['https://www.youtube.com/watch?v=one'],
    );
  });
}
