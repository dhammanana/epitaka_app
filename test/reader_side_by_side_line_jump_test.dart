/// Line jumps must put the target Pāḷi line on screen, on real text.
///
/// 1. A search hit opened in side-by-side mode. Side-by-side draws the Pāḷi
///    and the translation as two joined columns, and the English column is
///    taller, so aiming at the line's share of the whole paragraph lands on
///    the English line and leaves the Pāḷi line screens above. Real rows:
///    Peṭakopadesa 630–642, the user's report ("upadisiyati", para 636 line
///    27 of 29).
/// 2. Find into a one-line paragraph. The find bar is drawn over the top of
///    the reader, and a one-line paragraph used to land flush with that top,
///    under the bar. Real rows: Sumaṅgalavilāsinī 1–40, the user's report
///    ("mārasenamathanānaṃ", a one-line verse at para 10).
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/database/translation_database.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:epitaka/features/reader/widgets/reader_in_book_search_bar.dart';
import 'package:epitaka/router/app_router.dart';
import 'package:epitaka/shared/utils/app_shortcuts.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

const _word = 'upadisiyati';
const _verseWord = 'mārasenamathanānaṃ';

/// `[para_id, line_id, pali, english]`, built by the thread's
/// `export_fixture.py` from the app databases.
List<List<Object?>> _loadRows(String path) => [
      for (final r in jsonDecode(File(path).readAsStringSync()) as List)
        (r as List).cast<Object?>(),
    ];

final _petRows = _loadRows('test/fixtures/pet_636_rows.json');
final _svRows = _loadRows('test/fixtures/sv_i_verse_rows.json');

Future<EpitakaDatabase> _seedPali(
  String bookId,
  String bookName,
  List<List<Object?>> rows,
) async {
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
  await db.into(db.books).insert(
        BooksCompanion.insert(bookId: bookId, bookName: Value(bookName)),
      );
  for (final r in rows) {
    await db.into(db.sentences).insert(
          SentencesCompanion.insert(
            bookId: bookId,
            paraId: r[0] as int,
            lineId: r[1] as int,
            pali: Value(r[2] as String),
          ),
        );
  }
  return db;
}

Future<TranslationDatabase> _seedEnglish(
  String bookId,
  List<List<Object?>> rows,
) async {
  final db = TranslationDatabase(NativeDatabase.memory());
  for (final r in rows) {
    await db.customStatement(
      'INSERT INTO sentences (book_id, para_id, line_id, translation) '
      'VALUES (?, ?, ?, ?)',
      [bookId, r[0], r[1], r[3]],
    );
  }
  return db;
}

/// Mounts the real reader route on [pali] and [english] with English shown
/// in [mode], and returns its provider container.
Future<ProviderContainer> _pumpReader(
  WidgetTester tester, {
  required Size size,
  required TranslationDisplayMode mode,
  required EpitakaDatabase pali,
  required TranslationDatabase english,
}) async {
  final container = ProviderContainer(
    overrides: [
      epitakaDbProvider.overrideWith((ref) async => pali),
      translationDbProvider.overrideWith(
        (ref, code) async => code == 'en' ? english : null,
      ),
      settingsProvider.overrideWith((ref) {
        final notifier = SettingsNotifier(null);
        notifier.state = AppSettings(
          showTranslation: true,
          translationDisplayMode: mode,
          enabledTranslations: const ['en'],
        );
        return notifier;
      }),
    ],
  );
  addTearDown(container.dispose);

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = buildRouter();
  router.go('/reader');
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        supportedLocales: AppLocalizationsDelegate.supportedLocales,
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _pumpFrames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The reader viewport's top edge on screen and its height.
({double top, double height}) _viewport(WidgetTester tester) {
  final scrollable = tester.state<ScrollableState>(
    find
        .descendant(
          of: find.byType(ScrollablePositionedList),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  final top = scrollable.context
      .findRenderObject()!
      .getTransformTo(null)
      .getTranslation()
      .y;
  return (top: top, height: scrollable.position.viewportDimension);
}

/// Tops of every drawn occurrence of [needle], as fractions of the reader
/// viewport (0 = top edge, 1 = bottom edge).
List<double> _drawnTops(
  WidgetTester tester,
  String needle,
  double viewportTop,
  double viewportHeight,
) {
  final tops = <double>[];
  for (final e in find.byType(RichText).evaluate()) {
    final rp = e.renderObject;
    if (rp is! RenderParagraph || !rp.attached || !rp.hasSize) continue;
    final i = rp.text.toPlainText().indexOf(needle);
    if (i < 0) continue;
    final caret = rp.getOffsetForCaret(TextPosition(offset: i), Rect.zero);
    tops.add((rp.localToGlobal(caret).dy - viewportTop) / viewportHeight);
  }
  return tops;
}

void main() {
  final line27 = _petRows.firstWhere((r) => r[0] == 636 && r[1] == 27);
  final paliLine27 = (line27[2] as String).substring(0, 15);
  final englishLine27 = (line27[3] as String).substring(0, 18);

  for (final size in const [Size(600, 800), Size(1400, 900)]) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('side-by-side search jump shows the Pāḷi word ($label)',
        (tester) async {
      final pali = await _seedPali('Pet', 'Peṭakopadesapāḷi', _petRows);
      final english = await _seedEnglish('Pet', _petRows);
      addTearDown(() async {
        await pali.close();
        await english.close();
      });
      final container = await _pumpReader(
        tester,
        size: size,
        mode: TranslationDisplayMode.sideBySide,
        pali: pali,
        english: english,
      );
      await _pumpFrames(tester, 10);

      // What a search-card tap opens (search_panel.dart `_onResultTap`).
      container.read(readerTabsProvider.notifier).openTab(
            const ReaderTabInfo(
              bookId: 'Pet',
              bookName: 'Peṭakopadesapāḷi',
              initialParaId: 636,
              initialLineId: 27,
              searchQuery: _word,
            ),
          );
      await _pumpFrames(tester, 60);

      final viewport = _viewport(tester);
      final lineTops =
          _drawnTops(tester, paliLine27, viewport.top, viewport.height);
      final wordTops = _drawnTops(tester, _word, viewport.top, viewport.height);
      final englishTops =
          _drawnTops(tester, englishLine27, viewport.top, viewport.height);
      debugPrint(
        'JUMP [$label] paliLine27=${lineTops.map((t) => t.toStringAsFixed(3))} '
        'word=${wordTops.map((t) => t.toStringAsFixed(3))} '
        'english27=${englishTops.map((t) => t.toStringAsFixed(3))}',
      );

      expect(lineTops, hasLength(1),
          reason: 'the Pāḷi paragraph holding line 27 must be drawn once');
      // Every line jump aims the line's top at 10% of the viewport.
      expect(
        lineTops.single,
        closeTo(0.1, 0.03),
        reason: 'the Pāḷi line 27 must start at 10% of the viewport; '
            'got ${lineTops.single.toStringAsFixed(3)}',
      );
      // The word is the line's fifth, so it may wrap a row or two lower.
      expect(wordTops, hasLength(1),
          reason: 'the Pāḷi word "$_word" must be drawn once');
      expect(
        wordTops.single,
        inInclusiveRange(0.0, 0.5),
        reason: 'the Pāḷi word "$_word" must be on screen near the top; '
            'got ${wordTops.single.toStringAsFixed(3)}',
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }

  final verse = _svRows.firstWhere((r) => r[0] == 10 && r[1] == 1);
  final verseStart = (verse[2] as String).substring(0, 15);

  for (final mode in TranslationDisplayMode.values) {
    for (final size in const [Size(600, 800), Size(1400, 900)]) {
      final label = '${mode.name} ${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('Find puts a one-line verse below the find bar ($label)',
          (tester) async {
        final pali = await _seedPali('Sv-i', 'Sumaṅgalavilāsinī', _svRows);
        final english = await _seedEnglish('Sv-i', _svRows);
        addTearDown(() async {
          await pali.close();
          await english.close();
        });
        final container = await _pumpReader(
          tester,
          size: size,
          mode: mode,
          pali: pali,
          english: english,
        );
        container.read(readerTabsProvider.notifier).openTab(
              const ReaderTabInfo(
                bookId: 'Sv-i',
                bookName: 'Sumaṅgalavilāsinī',
              ),
            );
        await _pumpFrames(tester, 30);

        container.read(inBookSearchToggleProvider.notifier).toggle();
        await tester.pump();
        await tester.pump();
        await tester.enterText(
          find.descendant(
            of: find.byType(ReaderInBookSearchBar),
            matching: find.byType(TextField),
          ),
          _verseWord,
        );
        await _pumpFrames(tester, 60);

        final viewport = _viewport(tester);
        final barBottom = (tester
                    .getRect(find.byType(ReaderInBookSearchBar))
                    .bottom -
                viewport.top) /
            viewport.height;
        final verseTops =
            _drawnTops(tester, verseStart, viewport.top, viewport.height);
        debugPrint(
          'FIND [$label] barBottom=${barBottom.toStringAsFixed(3)} '
          'verse=${verseTops.map((t) => t.toStringAsFixed(3))}',
        );

        expect(verseTops, hasLength(1),
            reason: 'the matched verse must be drawn once');
        // Upper bound 0.15: at the book's start the verse already sits at
        // 0.23–0.24 in two of these layouts, so a looser bound would pass
        // with no jump at all.
        expect(
          verseTops.single,
          inInclusiveRange(barBottom, 0.15),
          reason: 'the verse must start below the find bar '
              '(bottom ${barBottom.toStringAsFixed(3)}) and near the top; '
              'got ${verseTops.single.toStringAsFixed(3)}',
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }
}
