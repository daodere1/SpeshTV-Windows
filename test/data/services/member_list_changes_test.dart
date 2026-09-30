import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:server_core/server_core.dart';
import 'package:moonfin/data/services/member_list_changes.dart';

class MockClient extends Mock implements MediaServerClient {}

void main() {
  late MockClient client;
  setUp(() {
    client = MockClient();
    when(() => client.userId).thenReturn('member');
    when(() => client.baseUrl).thenReturn('https://server');
  });
  test('changes are isolated by both member and server', () {
    expect(const MemberListChange('https://server', 'member', 'item', MemberListKind.favorite, true).belongsTo(client), isTrue);
    expect(const MemberListChange('https://other', 'member', 'item', MemberListKind.favorite, true).belongsTo(client), isFalse);
    expect(const MemberListChange('https://server', 'other', 'item', MemberListKind.favorite, true).belongsTo(client), isFalse);
  });
  test('successful saves publish their kind and selection', () async {
    final event = MemberListChanges.events.first;
    MemberListChanges.saved(client, 'movie:12', MemberListKind.watchlist, false);
    final change = await event;
    expect(change.item, 'movie:12');
    expect(change.kind, MemberListKind.watchlist);
    expect(change.selected, isFalse);
  });
  test('anonymous clients do not publish changes', () async {
    when(() => client.userId).thenReturn(null);
    final events = <MemberListChange>[];
    final subscription = MemberListChanges.events.listen(events.add);
    MemberListChanges.saved(client, 'item', MemberListKind.favorite, true);
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
    await subscription.cancel();
  });
}
