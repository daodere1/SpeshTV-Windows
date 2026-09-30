import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/preference/spesh_recent_channels.dart';

void main() {
  test('previous channel skips the current and unavailable channels', () {
    expect(previousRecentChannel(['b', 'removed', 'a'], 'b', {'a', 'b'}), 'a');
    expect(previousRecentChannel(['b'], 'b', {'a', 'b'}), isNull);
    expect(previousRecentChannel([], 'b', {'a', 'b'}), isNull);
  });
  test('confirmed switches alternate between two channels', () {
    var saved = rememberRecentChannel('', 'a');
    saved = rememberRecentChannel(saved, 'b');
    expect(previousRecentChannel(decodeRecentChannels(saved), 'b', {'a', 'b'}), 'a');
    saved = rememberRecentChannel(saved, 'a');
    expect(previousRecentChannel(decodeRecentChannels(saved), 'a', {'a', 'b'}), 'b');
  });
  test('history deduplicates, moves last watched first and caps at twenty', () {
    var saved = '';
    for (var i = 0; i < 30; i++) { saved = rememberRecentChannel(saved, '$i'); }
    expect(decodeRecentChannels(saved).length, 20);
    expect(decodeRecentChannels(saved).first, '29');
    saved = rememberRecentChannel(saved, '15');
    expect(decodeRecentChannels(saved).first, '15');
    expect(decodeRecentChannels(saved).where((id) => id == '15').length, 1);
  });
  test('invalid saved history is safe and member/server keys differ', () {
    expect(decodeRecentChannels('invalid'), isEmpty);
    expect(decodeRecentChannels('{"a":1}'), isEmpty);
    expect(speshRecentChannelsPreference('s', 'a').key, isNot(speshRecentChannelsPreference('s', 'b').key));
    expect(speshRecentChannelsPreference('s', 'a').key, isNot(speshRecentChannelsPreference('other', 'a').key));
  });
  test('only advancing active playback confirms once', () {
    final tracker = ConfirmedChannelPlayback();
    expect(tracker.sample(Duration.zero, playing: true), isFalse);
    expect(tracker.sample(Duration.zero, playing: true), isFalse);
    expect(tracker.sample(const Duration(seconds: 10), playing: false), isFalse);
    expect(tracker.sample(const Duration(seconds: 10), playing: true), isFalse);
    expect(tracker.sample(const Duration(seconds: 12), playing: true), isTrue);
    expect(tracker.sample(const Duration(seconds: 15), playing: true), isFalse);
    tracker.reset();
    expect(tracker.sample(const Duration(seconds: 1), playing: true), isFalse);
    expect(tracker.sample(const Duration(seconds: 3), playing: true), isTrue);
  });
  test('backward position resets confirmation baseline', () {
    final tracker = ConfirmedChannelPlayback();
    tracker.sample(const Duration(seconds: 100), playing: true);
    expect(tracker.sample(Duration.zero, playing: true), isFalse);
    expect(tracker.sample(const Duration(seconds: 2), playing: true), isTrue);
  });
}
