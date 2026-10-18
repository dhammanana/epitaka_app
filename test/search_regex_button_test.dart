/// The rx button in the Search screen (phone) and the Search sidebar
/// (desktop): where it sits, what it switches off, and how searches run.
library;

import 'package:epitaka/core/database/app_database.dart';
import 'package:epitaka/core/models/app_models.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/search/providers/search_provider.dart';
import 'package:epitaka/features/search/services/regex_search.dart';
import 'package:epitaka/features/search/widgets/search_panel.dart';
import 'package:epitaka/features/search/widgets/search_screen.dart';
import 'package:epitaka/shared/utils/app_navigation.dart';
import 'package:epitaka/shared/widgets/regex_toggle_button.dart';
import 'package:epitaka/shared/widgets/velthuis_help_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/regex_hotkey.dart';
import 'helpers/type_keys.dart';

class _FakeSearchNotifier extends SearchNotifier {
  _FakeSearchNotifier(super.ref);

  final calls = <({String query, bool regex})>[];

  /// When set, a search answers with two books of results.
  bool answer = false;

  /// With [answer], the search finds no book at all.
  bool noHits = false;

  /// The books the list asked to unfold, by position.
  final expanded = <int>[];

  @override
  Future<void> expandBook(int summaryIndex) async => expanded.add(summaryIndex);

  @override
  Future<void> ensureIndexBuilt() async {}

  @override
  Future<List<SearchSuggestion>> getSuggestions(String prefix) async => [
    const SearchSuggestion(pali: 'dhammassa', fuzzy: 'dhammassa', count: 7),
  ];

  @override
  Future<void> search({
    required String query,
    int distance = 0,
    bool regex = false,
  }) async {
    calls.add((query: query, regex: regex));
    if (answer) {
      state = SearchResults(
        query: query,
        totalResults: noHits ? 0 : 2,
        regex: regex,
        bookSummaries: noHits
            ? []
            : [
          BookResultSummary(
            book: BookInfo(id: 1, bookId: 'b1', bookName: 'Book One'),
            totalCount: 1,
          ),
          BookResultSummary(
            book: BookInfo(id: 2, bookId: 'b2', bookName: 'Book Two'),
            totalCount: 1,
          ),
        ],
      );
      return;
    }
    // The one state this file checks beyond the calls: the invalid-pattern
    // error the real notifier sets, shown at the field.
    if (regex) {
      final error = regexError(query);
      if (error != null) {
        state = SearchError(
          'Invalid pattern: $error',
          patternError: error,
          query: query,
        );
      }
    }
  }
}

const _localizations = <LocalizationsDelegate<dynamic>>[
  AppLocalizationsDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Mounts one box; returns the fake notifier and the provider container.
typedef _Mounted = ({_FakeSearchNotifier fake, ProviderContainer container});

Future<_Mounted> _pumpScreen(WidgetTester tester) async {
  late _FakeSearchNotifier fake;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        searchProvider.overrideWith((ref) => fake = _FakeSearchNotifier(ref)),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/search',
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) =>
                  SearchScreen(initialQuery: state.uri.queryParameters['q']),
            ),
          ],
        ),
        supportedLocales: AppLocalizationsDelegate.supportedLocales,
        localizationsDelegates: _localizations,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return (
    fake: fake,
    container: ProviderScope.containerOf(
      tester.element(find.byType(SearchScreen)),
    ),
  );
}

Future<_Mounted> _pumpPanel(WidgetTester tester) async {
  late _FakeSearchNotifier fake;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        searchProvider.overrideWith((ref) => fake = _FakeSearchNotifier(ref)),
      ],
      child: MaterialApp(
        supportedLocales: AppLocalizationsDelegate.supportedLocales,
        localizationsDelegates: _localizations,
        home: const Scaffold(
          body: SizedBox(width: 320, height: 700, child: SearchPanel()),
        ),
      ),
    ),
  );
  await tester.pump();
  return (
    fake: fake,
    container: ProviderScope.containerOf(
      tester.element(find.byType(SearchPanel)),
    ),
  );
}

Finder get _field => find.byType(TextField).first;
Finder get _rx => find.byType(RegexToggleButton);
Finder get _help =>
    find.descendant(of: _field, matching: find.byType(VelthuisHelpIcon));

String _text(WidgetTester tester) =>
    tester.widget<TextField>(_field).controller!.text;

Future<void> _toggle(WidgetTester tester) async {
  await tester.tap(_rx);
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (name, pump) in [
    ('Search screen', _pumpScreen),
    ('Search sidebar', _pumpPanel),
  ]) {
    group(name, () {
      testWidgets('rx shows on an empty box and sits after the clear button', (
        tester,
      ) async {
        await pump(tester);
        expect(_rx, findsOneWidget);

        await typeKeys(tester, _field, 'dhamma');
        await tester.pump(const Duration(milliseconds: 200));
        final clear = find.byIcon(Icons.clear);
        expect(clear, findsOneWidget);
        expect(
          tester.getCenter(_rx).dx,
          greaterThan(tester.getCenter(clear).dx),
        );
      });

      testWidgets('rx on keeps `.m` as typed; rx off turns it into ṃ', (
        tester,
      ) async {
        await pump(tester);
        await typeKeys(tester, _field, 'a.m');
        expect(_text(tester), 'aṃ');

        await tester.enterText(_field, '');
        await _toggle(tester);
        await typeKeys(tester, _field, 'a.m');
        expect(_text(tester), 'a.m');
      });

      testWidgets('rx on hides the Velthuis help, the distance chip and '
          'the suggestions', (tester) async {
        await pump(tester);
        await typeKeys(tester, _field, 'dhamm');
        await tester.pump(const Duration(milliseconds: 200));
        expect(_help, findsOneWidget);
        expect(find.text('Dist'), findsOneWidget);
        expect(find.text('dhammassa'), findsOneWidget);

        await _toggle(tester);
        await typeKeys(tester, _field, 'a');
        await tester.pump(const Duration(milliseconds: 200));
        expect(_help, findsNothing);
        expect(find.text('Dist'), findsNothing);
        expect(find.text('dhammassa'), findsNothing);
      });

      testWidgets('a search runs in the mode of the button, and switching '
          'it runs the search again', (tester) async {
        final (:fake, :container) = await pump(tester);
        await typeKeys(tester, _field, 'cakka');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();

        await _toggle(tester);
        expect(container.read(searchRegexProvider), isTrue);
        await _toggle(tester);

        expect(fake.calls, [
          (query: 'cakka', regex: false),
          (query: 'cakka', regex: true),
          (query: 'cakka', regex: false),
        ]);
      });

      testWidgets('an invalid pattern shows its message at the field', (
        tester,
      ) async {
        await pump(tester);
        await _toggle(tester);
        await typeKeys(tester, _field, '(');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();

        final atField = find.descendant(
          of: _field,
          matching: find.textContaining('Invalid pattern:'),
        );
        expect(atField, findsOneWidget);

        // Editing the pattern hides the field error until the next run.
        await typeKeys(tester, _field, ')');
        await tester.pump();
        expect(atField, findsNothing);
      });

      testWidgets('rx on or off, by key or by tap, keeps the cursor in a box '
          'that holds a word', (tester) async {
        final m = await pump(tester);
        await tester.enterText(_field, 'dhamma');
        await tester.pump();
        await tester.showKeyboard(_field);
        toggleRegexInFocusedBox();
        await tester.pump();
        await tester.pump();
        expect(m.fake.calls.last, (query: 'dhamma', regex: true));
        expect(fieldHasFocus(tester, _field), isTrue, reason: 'key on');
        toggleRegexInFocusedBox();
        await tester.pump();
        await tester.pump();
        expect(m.fake.calls.last, (query: 'dhamma', regex: false));
        expect(fieldHasFocus(tester, _field), isTrue, reason: 'key off');
        await _toggle(tester);
        await tester.pump();
        expect(m.fake.calls.last, (query: 'dhamma', regex: true));
        expect(fieldHasFocus(tester, _field), isTrue, reason: 'tap on');
      });

      testWidgets('Enter keeps the cursor in the box, rx on or off', (
        tester,
      ) async {
        final m = await pump(tester);
        await _toggle(tester);
        await tester.enterText(_field, 'dhamma');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();
        await tester.pump();
        expect(m.fake.calls.last, (query: 'dhamma', regex: true));
        expect(fieldHasFocus(tester, _field), isTrue, reason: 'rx on');
        await _toggle(tester);
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();
        await tester.pump();
        expect(m.fake.calls.last, (query: 'dhamma', regex: false));
        expect(fieldHasFocus(tester, _field), isTrue, reason: 'rx off');
      });

      testWidgets('Down arrow moves from the box to the results, rx on or '
          'off; Esc comes back', (tester) async {
        final m = await pump(tester);
        await tester.showKeyboard(_field);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(fieldHasFocus(tester, _field), isTrue, reason: 'no results');

        m.fake.answer = true;
        for (final rx in [false, true]) {
          if (rx) await _toggle(tester);
          await tester.enterText(_field, 'dhamma');
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await tester.pump();
          await tester.pump();
          expect(m.fake.calls.last.regex, rx);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pump();
          expect(fieldHasFocus(tester, _field), isFalse, reason: 'rx $rx');
          // Only the results list answers Esc, by giving the box the cursor.
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();
          expect(fieldHasFocus(tester, _field), isTrue, reason: 'rx $rx');
        }
      });

      testWidgets('Down lands on the first row every time; Right unfolds it; '
          'Up on the first row returns to the box', (tester) async {
        final m = await pump(tester);
        m.fake.answer = true;
        await tester.enterText(_field, 'dhamma');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // row 1
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(fieldHasFocus(tester, _field), isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(fieldHasFocus(tester, _field), isFalse);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(m.fake.expanded, [0], reason: 'the first book, not the second');

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(fieldHasFocus(tester, _field), isTrue);
      });

      testWidgets('arrows and Enter walk the suggestions before the results',
          (tester) async {
        final m = await pump(tester);
        m.fake.answer = true;
        await tester.enterText(_field, 'dhamma');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();
        await tester.pump();
        final searches = m.fake.calls.length;

        await tester.enterText(_field, 'dham');
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();
        expect(find.text('dhammassa'), findsOneWidget, reason: 'suggestions');

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(fieldHasFocus(tester, _field), isTrue, reason: 'stays in box');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.pump();
        expect(m.fake.calls.length, searches + 1);
        expect(m.fake.calls.last.query, 'dhammassa');

        // With no suggestions showing, Down goes to the results again.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(fieldHasFocus(tester, _field), isFalse);
      });

      testWidgets('Down with zero hits leaves the cursor in the box', (
        tester,
      ) async {
        final m = await pump(tester);
        m.fake.answer = true;
        m.fake.noHits = true;
        await tester.enterText(_field, 'dhamma');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(fieldHasFocus(tester, _field), isTrue);
      });

      testWidgets('the selected row is drawn highlighted only while the list '
          'has the cursor', (tester) async {
        final m = await pump(tester);
        m.fake.answer = true;
        await tester.enterText(_field, 'dhamma');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();
        await tester.pump();
        int highlighted() => tester
            .widgetList(
              find.byWidgetPredicate((w) {
                final n = w.runtimeType.toString();
                return n == '_SearchRowHighlight' || n == 'GroupRowHighlight';
              }),
            )
            .where((w) => (w as dynamic).selected as bool)
            .length;

        expect(highlighted(), 0, reason: 'cursor in the box');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(highlighted(), 1, reason: 'cursor in the list');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(highlighted(), 0, reason: 'back in the box');
      });

      testWidgets('Alt+R in the box turns rx on, then off', (tester) async {
        await pump(tester);
        expect(rxOnIn(tester, _field), isFalse);
        await regexHotkeyIn(tester, _field);
        await tester.pump();
        expect(rxOnIn(tester, _field), isTrue);
        await regexHotkeyIn(tester, _field);
        await tester.pump();
        expect(rxOnIn(tester, _field), isFalse);
      });
    });
  }

  testWidgets('a search from outside the app runs with rx off', (tester) async {
    final (:fake, :container) = await _pumpScreen(tester);
    await _toggle(tester);
    expect(container.read(searchRegexProvider), isTrue);

    openSearchRoute(tester.element(find.byType(SearchScreen)), 'dhamma');
    await tester.pump();

    expect(container.read(searchRegexProvider), isFalse);
    expect(fake.calls.last, (query: 'dhamma', regex: false));
  });
}
