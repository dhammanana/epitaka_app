/// A search hit opened in side-by-side mode must put the Pāḷi word on
/// screen. Side-by-side draws the Pāḷi and the translation as two joined
/// columns, and the English column is taller, so aiming at the line's share
/// of the whole paragraph lands on the English line and leaves the Pāḷi
/// line screens above. Real rows: Peṭakopadesa 630–642, the user's report
/// ("upadisiyati", para 636 line 27 of 29).
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
import 'package:epitaka/router/app_router.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

const _word = 'upadisiyati';

/// `[para_id, line_id, pali, english]`, built by the thread's
/// `export_fixture.py` from the app databases.
final List<List<Object?>> _rows = [
  for (final r in jsonDecode(
    File('test/fixtures/pet_636_rows.json').readAsStringSync(),
  ) as List)
    (r as List).cast<Object?>(),
];

Future<EpitakaDatabase> _seedPali() async {
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
        BooksCompanion.insert(
          bookId: 'Pet',
          bookName: const Value('Peṭakopadesapāḷi'),
        ),
      );
  for (final r in _rows) {
    await db.into(db.sentences).insert(
          SentencesCompanion.insert(
            bookId: 'Pet',
            paraId: r[0] as int,
            lineId: r[1] as int,
            pali: Value(r[2] as String),
          ),
        );
  }
  return db;
}

Future<TranslationDatabase> _seedEnglish() async {
  final db = TranslationDatabase(NativeDatabase.memory());
  for (final r in _rows) {
    await db.customStatement(
      'INSERT INTO sentences (book_id, para_id, line_id, translation) '
      'VALUES (?, ?, ?, ?)',
      ['Pet', r[0], r[1], r[3]],
    );
  }
  return db;
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
  final line27 = _rows.firstWhere((r) => r[0] == 636 && r[1] == 27);
  final paliLine27 = (line27[2] as String).substring(0, 15);
  final englishLine27 = (line27[3] as String).substring(0, 18);

  for (final size in const [Size(600, 800), Size(1400, 900)]) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('side-by-side search jump shows the Pāḷi word ($label)',
        (tester) async {
      final pali = await _seedPali();
      final english = await _seedEnglish();
      addTearDown(() async {
        await pali.close();
        await english.close();
      });
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
              translationDisplayMode: TranslationDisplayMode.sideBySide,
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
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

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
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ScrollablePositionedList),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final viewportTop = scrollable.context
          .findRenderObject()!
          .getTransformTo(null)
          .getTranslation()
          .y;
      final viewportHeight = scrollable.position.viewportDimension;

      final lineTops =
          _drawnTops(tester, paliLine27, viewportTop, viewportHeight);
      final wordTops = _drawnTops(tester, _word, viewportTop, viewportHeight);
      final englishTops =
          _drawnTops(tester, englishLine27, viewportTop, viewportHeight);
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
}
