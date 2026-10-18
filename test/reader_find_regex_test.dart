/// Find in book with the rx button on: the REAL [ReaderSearchNotifier] over
/// the REAL [readerDataProvider], loaded from seeded in-memory databases with
/// an English translation (the `reader_find_cache_test.dart` set-up), and the
/// Find bar widget itself.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/database/translation_database.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/reader/providers/reader_provider.dart';
import 'package:epitaka/features/reader/providers/reader_search_notifier.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:epitaka/features/reader/widgets/reader_in_book_search_bar.dart';
import 'package:epitaka/shared/widgets/regex_toggle_button.dart';
import 'package:epitaka/shared/widgets/velthuis_help_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/regex_hotkey.dart';
import 'helpers/type_keys.dart';

const _bookId = 'dn1';

/// (paraId, lineId, pali). Paragraph 3 holds `dhammā` only inside a variant
/// bracket.
const _pali = [
  (1, 1, 'evaṃ me sutaṃ'),
  (1, 2, 'dhammacakkaṃ pavattitaṃ'),
  (2, 1, 'dhammo ca [dhammo] ca'),
  (3, 1, 'sabbe [dhammā] saṅkhārā'),
  (4, 1, 'bhikkhave'),
  // DN 1, 7 words: `([^ ]+ ?)+x` backtracks on it for about 30 s.
  (5, 1, 'ekaṃ samayaṃ bhagavā antarā ca rājagahaṃ antarā'),
];

const _english = [(1, 1, 'Thus have I heard'), (4, 1, 'monks, the wheel')];

Future<EpitakaDatabase> _canon() async {
  final db = EpitakaDatabase(NativeDatabase.memory());
  await db.customStatement(
    'CREATE TABLE books ('
    'id INTEGER PRIMARY KEY AUTOINCREMENT, ref_id INTEGER, vri_id TEXT, '
    'book_id TEXT, category TEXT, nikaya TEXT, sub_nikaya TEXT, '
    'book_name TEXT, description TEXT, mula_ref TEXT, attha_ref TEXT, '
    'tika_ref TEXT, para_id INTEGER, chapter_len INTEGER)',
  );
  await db.customStatement(
    'CREATE TABLE headings ('
    'book_id TEXT NOT NULL, para_id INTEGER NOT NULL, level INTEGER, '
    'title TEXT, chapter_len INTEGER, parent INTEGER, sc_id TEXT, '
    'PRIMARY KEY (book_id, para_id))',
  );
  await db.customStatement(
    'CREATE TABLE sentences ('
    'book_id TEXT NOT NULL, para_id INTEGER NOT NULL, line_id INTEGER NOT NULL, '
    'vripara TEXT, thaipage TEXT, vripage TEXT, ptspage TEXT, mypage TEXT, '
    'pali TEXT, PRIMARY KEY (book_id, para_id, line_id))',
  );
  await db
      .into(db.books)
      .insert(
        BooksCompanion.insert(bookId: _bookId, bookName: const Value('DN 1')),
      );
  for (final (para, line, pali) in _pali) {
    await db
        .into(db.sentences)
        .insert(
          SentencesCompanion.insert(
            bookId: _bookId,
            paraId: para,
            lineId: line,
            pali: Value(pali),
          ),
        );
  }
  return db;
}

Future<TranslationDatabase> _translation() async {
  final db = TranslationDatabase(NativeDatabase.memory());
  for (final (para, line, text) in _english) {
    await db.customStatement(
      'INSERT INTO sentences(book_id, para_id, line_id, translation) '
      'VALUES (?, ?, ?, ?)',
      [_bookId, para, line, text],
    );
  }
  return db;
}

List<(int, int)> _matches(InBookSearchState s) => [
  for (var i = 0; i < s.matchParaIds.length; i++)
    (s.matchParaIds[i], s.matchLineIds[i]),
];

/// The book open and loaded, the find provider kept alive, rx on.
Future<(ProviderContainer, ReaderSearchNotifier)> _openBook({
  bool hideVariants = false,
}) async {
  final canon = await _canon();
  final english = await _translation();
  addTearDown(() async {
    await english.close();
    await canon.close();
  });
  final container = ProviderContainer(
    overrides: [
      epitakaDbProvider.overrideWith((ref) async => canon),
      translationDbProvider('en').overrideWith((ref) async => english),
      settingsProvider.overrideWith((ref) {
        final n = SettingsNotifier(null);
        n.state = AppSettings(
          showTranslation: true,
          enabledTranslations: const ['en'],
          stripVariantAnnotations: hideVariants,
        );
        return n;
      }),
    ],
  );
  addTearDown(container.dispose);
  container
      .read(readerTabsProvider.notifier)
      .openTab(const ReaderTabInfo(bookId: _bookId, bookName: 'DN 1'));
  await container.read(readerDataProvider(_bookId).notifier).waitUntilLoaded();
  container.listen(inBookSearchProvider, (_, _) {});
  container.read(findRegexProvider.notifier).state = true;
  return (container, container.read(inBookSearchProvider.notifier));
}

Future<InBookSearchState> _find(
  ProviderContainer c,
  ReaderSearchNotifier find,
  String pattern,
) async {
  find.onSubmitted(pattern);
  // The match runs in a regex job in another isolate: wait on the real
  // clock for its answer.
  for (var i = 0; i < 500; i++) {
    final s = c.read(inBookSearchProvider);
    if (s.query == pattern || s.patternError != null || s.patternTooSlow) {
      return s;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('no answer for $pattern in 5 s');
}

void main() {
  // toggleSearchBar focuses the field after the next frame.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a pattern matches inside a word; the reader gets the matched '
      'pieces to highlight', () async {
    final (c, find) = await _openBook();
    find.toggleSearchBar();
    final s = await _find(c, find, 'cakka');
    expect(_matches(s), [(1, 2)]);
    expect(s.query, 'cakka');
    expect(s.effectiveQuery, 'cakka');
  });

  test('a line matches in its Pāḷi or in one translation; `^` is the start '
      'of that one text', () async {
    final (c, find) = await _openBook();
    expect(_matches(await _find(c, find, 'bhikkhave')), [(4, 1)]);
    expect(_matches(await _find(c, find, 'wheel')), [(4, 1)]);
    expect(_matches(await _find(c, find, '^thus')), [(1, 1)]);
    expect(_matches(await _find(c, find, '^evaṃ')), [(1, 1)]);
    expect(_matches(await _find(c, find, 'heard\$')), [(1, 1)]);
  });

  test('diacritics are exact; matches come in reading order', () async {
    final (c, find) = await _openBook();
    expect(_matches(await _find(c, find, 'dhamm[oā]')), [(2, 1), (3, 1)]);
    expect(_matches(await _find(c, find, 'dhammā')), [(3, 1)]);
    expect(_matches(await _find(c, find, 'dhamma ')), isEmpty);
  });

  test('hiding variant readings hides their words from a pattern', () async {
    final (c, find) = await _openBook(hideVariants: true);
    expect(_matches(await _find(c, find, 'dhammā')), isEmpty);
    expect(_matches(await _find(c, find, 'dhammo')), [(2, 1)]);
  });

  test(
    'the exact cache is built once per book, and never with rx off',
    () async {
      final (c, find) = await _openBook();
      c.read(findRegexProvider.notifier).state = false;
      await _find(c, find, 'dhamma');
      expect(find.exactBuildCount, 0);
      expect(find.cachedExactLineCount, 0);

      c.read(findRegexProvider.notifier).state = true;
      await _find(c, find, 'dhamma');
      await _find(c, find, 'cakka');
      expect(find.exactBuildCount, 1);
      expect(find.cachedExactLineCount, _pali.length);
    },
  );

  test('a runaway pattern ends as too slow instead of freezing', () async {
    final (c, find) = await _openBook();
    final s = await _find(c, find, r'([^ ]+ ?)+x');
    expect(s.patternTooSlow, isTrue);
    expect(s.matchParaIds, isEmpty);
  });

  test('closing the bar during a runaway find leaves no late answer', () async {
    final (c, find) = await _openBook();
    find.toggleSearchBar();
    find.onSubmitted(r'([^ ]+ ?)+x');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    find.toggleSearchBar();
    await Future<void>.delayed(const Duration(milliseconds: 3500));
    final s = c.read(inBookSearchProvider);
    expect(s.showSearchBar, isFalse);
    expect(s.patternTooSlow, isFalse, reason: 'no late answer');
  });

  test('a big book builds the exact cache in a background isolate', () async {
    final saved = ReaderSearchNotifier.backgroundMinLines;
    ReaderSearchNotifier.backgroundMinLines = 0;
    addTearDown(() => ReaderSearchNotifier.backgroundMinLines = saved);
    final (c, find) = await _openBook();
    expect(find.cachedExactLineCount, 0);
    expect(_matches(await _find(c, find, 'cakka')), [(1, 2)]);
    expect(find.cachedExactLineCount, _pali.length);
    expect(find.exactBuildCount, 1);
  });

  test('a pattern that does not compile says why and finds nothing', () async {
    final (c, find) = await _openBook();
    final s = await _find(c, find, '(');
    expect(s.patternError, isNotNull);
    expect(s.matchParaIds, isEmpty);
    expect(s.effectiveQuery, isNull);
  });

  test('switching rx finds the box text again in the new mode', () async {
    final (c, find) = await _openBook();
    find.toggleSearchBar();
    find.searchController.text = 'dhamm[oā]';
    find.toggleRegex(); // off: the brackets are cleaned away
    await pumpEventQueue();
    expect(c.read(findRegexProvider), isFalse);
    expect(_matches(c.read(inBookSearchProvider)), isEmpty);

    find.toggleRegex();
    await pumpEventQueue();
    expect(_matches(c.read(inBookSearchProvider)), [(2, 1), (3, 1)]);
  });

  group('the Find bar', () {
    Future<(TextEditingController, List<String>)> pumpBar(
      WidgetTester tester, {
      required bool regexOn,
      String? patternError,
      bool patternTooSlow = false,
    }) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final events = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ReaderInBookSearchBar(
                colors: Theme.of(context).colorScheme,
                controller: controller,
                focusNode: FocusNode(),
                matchCount: 0,
                currentMatchIndex: -1,
                query: '',
                regexOn: regexOn,
                patternError: patternError,
                patternTooSlow: patternTooSlow,
                onToggleRegex: () => events.add('toggle'),
                onClose: () {},
                onQueryChanged: (_) => setState(() {}),
                onSubmitted: (_) {},
                onPrevious: () {},
                onNext: () {},
                onSearchEntire: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return (controller, events);
    }

    testWidgets('rx sits after the clear button and reports a tap', (
      tester,
    ) async {
      final (_, events) = await pumpBar(tester, regexOn: false);
      await typeKeys(tester, find.byType(TextField), 'a');
      await tester.pump();
      expect(
        tester.getCenter(find.byType(RegexToggleButton)).dx,
        greaterThan(tester.getCenter(find.byIcon(Icons.clear)).dx),
      );
      await tester.tap(find.byType(RegexToggleButton));
      expect(events, ['toggle']);
    });

    testWidgets('Alt+R in the box reports a toggle', (tester) async {
      final (_, events) = await pumpBar(tester, regexOn: false);
      await regexHotkeyIn(tester, find.byType(TextField));
      expect(events, ['toggle']);
    });

    testWidgets('rx on keeps `.m` and hides the Velthuis help; off turns it '
        'into ṃ', (tester) async {
      var (controller, _) = await pumpBar(tester, regexOn: true);
      await typeKeys(tester, find.byType(TextField), 'a.m');
      expect(controller.text, 'a.m');
      expect(find.byType(VelthuisHelpIcon), findsNothing);

      (controller, _) = await pumpBar(tester, regexOn: false);
      await typeKeys(tester, find.byType(TextField), 'a.m');
      expect(controller.text, 'aṃ');
      expect(find.byType(VelthuisHelpIcon), findsOneWidget);
    });

    testWidgets('an invalid pattern shows in place of the count', (
      tester,
    ) async {
      await pumpBar(tester, regexOn: true, patternError: 'Unterminated group');
      expect(find.text('Invalid pattern: Unterminated group'), findsOneWidget);
    });

    testWidgets('"Pattern too slow" shows whole, not cut short', (
      tester,
    ) async {
      await pumpBar(tester, regexOn: true, patternTooSlow: true);
      final text = find.text('Pattern too slow');
      expect(text, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(text);
      expect(paragraph.didExceedMaxLines, isFalse, reason: 'ellipsis');
    });
  });
}
