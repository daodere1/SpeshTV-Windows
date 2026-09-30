import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/models/search_source.dart';

void main() {
  test('deployed catalog search identities parse and group', () {
    final fixture = File('verification/search-fixture.json');
    if (!fixture.existsSync()) return;
    final rows = jsonDecode(fixture.readAsStringSync()) as List;
    final items = rows.map((row) => AggregatedItem(
      id: row['Id']?.toString() ?? '', serverId: row['ServerId']?.toString() ?? '',
      rawData: Map<String, dynamic>.from(row as Map),
    )).toList();
    expect(preferLocalSearchResults(items), isNotEmpty);
  });
}
