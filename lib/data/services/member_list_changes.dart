import 'dart:async';
import 'package:server_core/server_core.dart';

enum MemberListKind { favorite, watchlist }

class MemberListChange {
  final String server, user, item;
  final MemberListKind kind;
  final bool selected;
  const MemberListChange(this.server, this.user, this.item, this.kind, this.selected);
  bool belongsTo(MediaServerClient client) => user.isNotEmpty && user == client.userId && server == client.baseUrl;
}

/// Session-only notifications after successful saves; no credentials or history retained.
class MemberListChanges {
  static final _events = StreamController<MemberListChange>.broadcast();
  static Stream<MemberListChange> get events => _events.stream;
  static void saved(MediaServerClient client, String item, MemberListKind kind, bool selected) {
    if (client.userId?.isNotEmpty != true) return;
    _events.add(MemberListChange(client.baseUrl, client.userId!, item, kind, selected));
  }
}
