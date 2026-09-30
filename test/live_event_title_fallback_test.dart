import 'package:flutter_test/flutter_test.dart';
import '../lib/data/viewmodels/live_tv_guide_view_model.dart';

void main() {
  test('missing EPG uses provider channel name without fabricating a programme', () {
    const event = 'LIVE EVENT 01 - 7pm Dana White Contender Series S10W08';
    for (final title in [null, '', ' No title ', 'No information available', 'TBA']) {
      expect(hasGuideTitle(title), isFalse);
      expect(guideDisplayTitle(title, event), event);
    }
  });

  test('valid EPG title takes precedence', () {
    expect(guideDisplayTitle('Round 1', 'UFC 00'), 'Round 1');
    expect(hasGuideTitle('No Country for Old Men'), isTrue);
  });
}
