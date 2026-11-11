/// The Gavesana question history: rows in the idle area, the keyboard model,
/// a tap that restores saved results with no AI call, and `restore` itself.
library;

import 'package:epitaka/core/database/app_database.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/gavesana/providers/ai_search_provider.dart';
import 'package:epitaka/features/gavesana/providers/gavesana_history_provider.dart';
import 'package:epitaka/features/gavesana/widgets/gavesana_search_view.dart';
import 'package:epitaka/features/search/providers/search_history_provider.dart';
import 'package:epitaka/features/search/providers/search_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/type_keys.dart';

const _p1 = AiPassageRef(bookId: 'dn1', paraId: 2);
const _p2 = AiPassageRef(bookId: 'mn1', paraId: 9);

String _entry(String q, {List<AiPassageRef> passages = const [_p1, _p2]}) =>
    encodeGavesana(question: q, terms: ['t-$q'], passages: passages);

class FakeAi extends AiSearchNotifier {
  FakeAi(super.ref);
  final searches = <String>[];
  final restores = <String>[];

  @override
  Future<void> search(String query) async => searches.add(query);

  @override
  Future<void> restore(GavesanaEntry entry) async =>
      restores.add(entry.question);
}

/// Stands in for the database: reports how many of the passages "exist".
class FakeSearch extends SearchNotifier {
  FakeSearch(super.ref, this.found);
  final int found;
  List<AiPassageRef>? shownPassages;
  String? shownQuery;
  bool cleared = false;

  @override
  Future<void> ensureIndexBuilt() async {}

  @override
  Future<List<SearchSuggestion>> getSuggestions(String prefix) async => [];

  @override
  Future<void> showAiResults({
    required String query,
    required List<AiPassageRef> passages,
    List<String> highlightTerms = const [],
  }) async {
    shownQuery = query;
    shownPassages = passages;
    state = SearchResults(
      query: query,
      totalResults: found,
      bookSummaries: const [],
    );
  }

  @override
  void clear() {
    cleared = true;
    state = const SearchIdle();
  }
}

late FakeAi fakeAi;
late ProviderContainer container;

Future<void> pumpView(WidgetTester tester, List<String> saved) async {
  SharedPreferences.setMockInitialValues({'gavesana_search_history': saved});
  container = ProviderContainer(
    overrides: [aiSearchProvider.overrideWith((ref) => fakeAi = FakeAi(ref))],
  );
  addTearDown(container.dispose);
  container.read(gavesanaHistoryProvider);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        supportedLocales: AppLocalizationsDelegate.supportedLocales,
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: GavesanaSearchView(autoFocus: true)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.tap(find.byType(TextField).first);
  await tester.pump();
}

bool highlighted(WidgetTester tester, String q) {
  final key = _entry(q);
  final m = tester.widget<Material>(
    find
        .descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Material))
        .first,
  );
  return m.color ==
        Theme.of(tester.element(find.byKey(ValueKey(key)))).colorScheme.primaryContainer;
}

Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await tester.pump();
}

void main() {
  testWidgets('an empty box shows the saved questions, newest first', (
    tester,
  ) async {
    await pumpView(tester, [_entry('what is dukkha'), _entry('what is nibbana')]);
    expect(find.text('what is dukkha'), findsOneWidget);
    expect(find.text('what is nibbana'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('what is dukkha')).dy <
          tester.getTopLeft(find.text('what is nibbana')).dy,
      isTrue,
    );
  });

  testWidgets('a corrupt saved row is dropped', (tester) async {
    await pumpView(tester, ['not json', _entry('q one')]);
    expect(find.text('q one'), findsOneWidget);
    expect(container.read(gavesanaHistoryProvider).length, 1);
  });

  testWidgets('Down, Down, Up, Up leaves no highlight and typing works', (
    tester,
  ) async {
    await pumpView(tester, [_entry('q one'), _entry('q two')]);
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(highlighted(tester, 'q two'), isTrue);
    await key(tester, LogicalKeyboardKey.arrowUp);
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(highlighted(tester, 'q one'), isFalse);
    expect(highlighted(tester, 'q two'), isFalse);
    await typeKeys(tester, find.byType(TextField).first, 'k');
    await tester.pump();
    expect(find.text('q one'), findsNothing);
  });

  testWidgets('Down then Enter restores that question with no AI call', (
    tester,
  ) async {
    await pumpView(tester, [_entry('q one'), _entry('q two')]);
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.enter);
    expect(fakeAi.restores, ['q two']);
    expect(fakeAi.searches, isEmpty);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'q two',
    );
  });

  testWidgets('a tap restores saved results and starts no AI search', (
    tester,
  ) async {
    await pumpView(tester, [_entry('q one')]);
    await tester.tap(find.text('q one'));
    await tester.pump();
    expect(fakeAi.restores, ['q one']);
    expect(fakeAi.searches, isEmpty);
  });

  testWidgets('Enter on the filled box does start a new AI search', (
    tester,
  ) async {
    await pumpView(tester, [_entry('q one')]);
    await typeKeys(tester, find.byType(TextField).first, 'abc');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(fakeAi.searches, ['abc']);
    expect(fakeAi.restores, isEmpty);
  });

  testWidgets('X removes one row; Clear empties only the Gavesana store', (
    tester,
  ) async {
    await pumpView(tester, [_entry('q one'), _entry('q two')]);
    container.read(searchHistoryProvider.notifier).add('main word');
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump();
    expect(container.read(gavesanaHistoryProvider).length, 1);
    await tester.tap(find.text('Clear history'));
    await tester.pump();
    expect(container.read(gavesanaHistoryProvider), isEmpty);
    expect(container.read(searchHistoryProvider), ['main word']);
  });

  group('restore', () {
    Future<(ProviderContainer, FakeSearch)> make(int found) async {
      SharedPreferences.setMockInitialValues({});
      late FakeSearch search;
      final c = ProviderContainer(
        overrides: [
          searchProvider.overrideWith((ref) => search = FakeSearch(ref, found)),
        ],
      );
      addTearDown(c.dispose);
      c.read(searchProvider);
      return (c, search);
    }

    final entry = GavesanaEntry(
      question: 'q one',
      terms: const ['dukkha'],
      passages: const [_p1, _p2],
    );

    test('shows the saved passages as the finished view', () async {
      final (c, search) = await make(2);
      await c.read(aiSearchProvider.notifier).restore(entry);
      final state = c.read(aiSearchProvider);
      expect(state, isA<AiSearchDone>());
      expect((state as AiSearchDone).passageCount, 2);
      expect(state.termsUsed, ['dukkha']);
      expect(search.shownQuery, 'q one');
      expect(search.shownPassages!.length, 2);
      // A filter toggle must not run a text search on the question.
      expect(search.cleared, isFalse);
    });

    test('the count follows what the database still has', () async {
      final (c, _) = await make(1);
      await c.read(aiSearchProvider.notifier).restore(entry);
      expect((c.read(aiSearchProvider) as AiSearchDone).passageCount, 1);
    });

    test('no passage left gives the idle state', () async {
      final (c, search) = await make(0);
      await c.read(aiSearchProvider.notifier).restore(entry);
      expect(c.read(aiSearchProvider), isA<AiSearchIdle>());
      expect(search.cleared, isTrue);
    });
  });

  test('showing AI results writes nothing to the Search history', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c
        .read(searchProvider.notifier)
        .showAiResults(query: 'what is dukkha', passages: const []);
    expect(c.read(searchHistoryProvider), isEmpty);
  });
}
