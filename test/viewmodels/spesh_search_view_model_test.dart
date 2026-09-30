import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/repositories/search_repository.dart';
import 'package:moonfin/data/viewmodels/search_view_model.dart';
import 'package:server_core/server_core.dart';

class Client extends Mock implements MediaServerClient {}
class Search extends SearchRepository {
  Search(super.client);
  final requests = <({String query, bool Function() current,
    void Function(List<AggregatedItem>) publish, Completer<void> done})>[];
  final people = Completer<List<AggregatedItem>>();
  var peopleCalls = 0;
  @override
  Future<List<AggregatedItem>> searchLibraries(String query, {
    required SearchSource source, required bool Function() isCurrent,
    required void Function(List<AggregatedItem>) onResults}) async {
    final done = Completer<void>();
    requests.add((query: query, current: isCurrent, publish: onResults, done: done));
    await done.future;
    return [];
  }
  @override
  Future<List<AggregatedItem>> fetchLiveTvChannels() async => [];
  @override
  Future<List<AggregatedItem>> searchPeople(String query,
      {int limit = 24, bool Function()? isCurrent}) {
    peopleCalls++;
    return people.future;
  }
}

AggregatedItem result(String id) => AggregatedItem(id: id, serverId: 's',
  rawData: {'Type': 'Movie', 'Name': id});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Client client;
  late Search repo;
  late SearchViewModel vm;
  setUp(() {
    client = Client();
    when(() => client.gamesApi).thenReturn(null);
    repo = Search(client);
    vm = SearchViewModel(repo, client);
  });
  tearDown(() {
    vm.dispose();
    for (final r in repo.requests) { if (!r.done.isCompleted) r.done.complete(); }
    if (!repo.people.isCompleted) repo.people.complete([]);
  });
  test('library results arrive before optional people search completes', () async {
    vm.searchImmediate('movie');
    repo.requests.single.publish([result('movie')]);
    expect(vm.results.single.items.single.id, 'movie');
    expect(vm.searching, isTrue);
    expect(repo.people.isCompleted, isFalse);
    expect(repo.peopleCalls, 0);
    repo.requests.single.done.complete();
    repo.people.complete([]);
    await Future<void>.delayed(Duration.zero);
    expect(vm.searching, isFalse);
    expect(repo.peopleCalls, 1);
  });
  test('obsolete query does not schedule deferred people search', () async {
    vm.searchImmediate('a');
    vm.searchDebounced('');
    repo.requests.single.done.complete();
    await Future<void>.delayed(Duration.zero);
    expect(repo.peopleCalls, 0);
    expect(vm.state, SearchState.idle);
  });
  test('ABA query and source changes invalidate all older responses', () {
    vm.searchImmediate('a');
    vm.searchImmediate('b');
    vm.searchImmediate('a');
    expect(repo.requests.first.current(), isFalse);
    repo.requests.first.publish([result('stale')]);
    expect(vm.results, isEmpty);
    repo.requests.last.publish([result('fresh')]);
    expect(vm.results.single.items.single.id, 'fresh');
    vm.setSource(SearchSource.vod);
    expect(repo.requests[2].current(), isFalse);
    expect(vm.results, isEmpty);
  });
  test('clearing query invalidates in-flight results', () {
    vm.searchImmediate('a');
    vm.searchDebounced('');
    repo.requests.single.publish([result('stale')]);
    expect(vm.state, SearchState.idle);
    expect(vm.results, isEmpty);
  });
  test('partial failure preserves already published results', () async {
    vm.setSource(SearchSource.local);
    vm.searchImmediate('a');
    repo.requests.single.publish([result('a')]);
    repo.requests.single.done.completeError(StateError('network'));
    await Future<void>.delayed(Duration.zero);
    expect(vm.results.single.items.single.id, 'a');
    expect(vm.errorMessage, isNotEmpty);
    expect(vm.searching, isFalse);
  });
}
