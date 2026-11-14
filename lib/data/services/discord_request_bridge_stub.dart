import 'package:flutter/foundation.dart';

class DiscordRequestBridge extends ChangeNotifier {
  static final instance = DiscordRequestBridge();
  static const endpoint = 'http://127.0.0.1:47653';
  bool get enabled => false;
  String? get token => null;
  String get status => 'Chat requests are available in the Windows client.';
  Future<void> setEnabled(bool value) async {}
}
