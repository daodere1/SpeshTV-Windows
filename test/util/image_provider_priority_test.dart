import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/image_source.dart';
import 'package:moonfin/util/image_fetch_priority.dart';

void main() {
  tearDown(() => artworkRequestPromoter = null);

  test('visible providers promote queued artwork', () {
    ImageFetchPriority? promoted;
    artworkRequestPromoter = (_, priority) => promoted = priority;
    offlineAwareImageProvider('https://example.test/cast', priority: ImageFetchPriority.high);
    expect(promoted, ImageFetchPriority.high);
  });

  test('prefetch headers retain low priority without promotion', () {
    var promoted = false;
    artworkRequestPromoter = (_, _) => promoted = true;
    offlineAwareImageProvider('https://example.test/poster',
      headers: {imageFetchPriorityHeader: 'low'});
    expect(promoted, isFalse);
  });
}
