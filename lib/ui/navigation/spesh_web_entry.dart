class SpeshWebEntry {
  String? _pending;

  SpeshWebEntry(String? entry) {
    capture(entry);
  }

  void capture(String? entry) {
    if (entry == '/live-tv' || entry == '/live-tv/guide') {
      _pending = entry;
    }
  }

  String? take() {
    final destination = _pending;
    _pending = null;
    return destination;
  }
}
