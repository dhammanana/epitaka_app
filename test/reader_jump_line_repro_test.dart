/// Repro: does a jump with a `lineId` fine-scroll to the exact line, or does
/// it only land at the paragraph start?
///
/// Mirrors the annotation-jump harness (real in-memory DB + real reader).
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:epitaka/router/app_router.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

const _paraCount = 40;
const _linesPerPara = 8;
const _targetParaId = 10;

Future<EpitakaDatabase> _seedDatabase() async {
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
        BooksCompanion.insert(bookId: 'dn1', bookName: const Value('Dīgha Nikāya 1')),
      );

  for (var i = 1; i <= _paraCount; i++) {
    for (var l = 1; l <= _linesPerPara; l++) {
      await db.into(db.sentences).insert(
            SentencesCompanion.insert(
              bookId: 'dn1',
              paraId: i,
              lineId: l,
              pali: Value('pāli text paragraph $i line $l'),
            ),
          );
    }
  }

  return db;
}

void main() {
  late EpitakaDatabase db;

  setUp(() async {
    db = await _seedDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpReader(
    WidgetTester tester, {
    TranslationDisplayMode mode = TranslationDisplayMode.sideBySide,
  }) async {
    final container = ProviderContainer(
      overrides: [
        epitakaDbProvider.overrideWith((ref) async => db),
        // No translation DBs in this test environment — return null so the
        // reader loads pali-only (showTranslation stays true so lineByLine
        // still renders per-line widgets with the fine-scroll keys).
        translationDbProvider.overrideWith((ref, code) async => null),
        settingsProvider.overrideWith((ref) {
          final notifier = SettingsNotifier(null);
          notifier.state = AppSettings(
            // Translations must be shown for lineByLine to actually render
            // per-line widgets (without it, _toParagraphDisplayMode forces
            // joined rendering and the fine-scroll keys can never attach).
            showTranslation: true,
            translationDisplayMode: mode,
          );
          return notifier;
        }),
      ],
    );
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(600, 800);
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
  }

  testWidgets('jump with lineId fine-scrolls to the target line', (tester) async {
    for (final mode in [
      TranslationDisplayMode.sideBySide,
      TranslationDisplayMode.lineByLine,
      TranslationDisplayMode.hideJoinLines,
    ]) {
      await pumpReader(tester, mode: mode);
    final tabs = containerOf(tester).read(readerTabsProvider.notifier);

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    const targetLine = 5;
    tabs.openTab(
      const ReaderTabInfo(
        bookId: 'dn1',
        bookName: 'Dīgha Nikāya 1',
        initialParaId: _targetParaId,
        initialLineId: targetLine,
      ),
    );
    // Give the paragraph scroll + per-line fine-scroll time to settle.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final tab = containerOf(tester).read(readerTabsProvider).activeTab;
    debugPrint('REPRO currentParaId=${tab?.currentParaId} '
        'scrollOffset=${tab?.scrollOffset}');

    // Find the reader's scroll viewport first.
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(ScrollablePositionedList),
        matching: find.byType(Scrollable),
      ).first,
    );
    final viewportTop = scrollable.context.findRenderObject()!
        .getTransformTo(null)
        .getTranslation().y;
    final viewportHeight = scrollable.position.viewportDimension;

    double line5Top;
    if (mode == TranslationDisplayMode.lineByLine) {
      // lineByLine renders each line as its own widget — measure line 5
      // directly.
      final line5Text = find.textContaining(
        'paragraph $_targetParaId line $targetLine',
      );
      expect(line5Text, findsOneWidget,
          reason: '[${mode.name}] the target line text must be rendered');
      line5Top = tester.getTopLeft(line5Text).dy;
    } else {
      // Joined modes render the whole paragraph as a single Text; estimate
      // line 5's top from the paragraph rect (uniform line heights).
      final paraText = find.textContaining('paragraph $_targetParaId line 1');
      expect(paraText, findsOneWidget,
          reason: '[${mode.name}] the target paragraph must be rendered');
      final paraRect = tester.getRect(paraText);
      final lineHeight = paraRect.height / _linesPerPara;
      line5Top = paraRect.top + 4 * lineHeight;
    }

    final line5Fraction = (line5Top - viewportTop) / viewportHeight;

    debugPrint(
      'REPRO [${mode.name}] line5Top=$line5Top viewportTop=$viewportTop '
      'viewportH=$viewportHeight line5Fraction=${line5Fraction.toStringAsFixed(3)}',
    );

    // The target line (not the paragraph start) must sit at ~30% of the
    // viewport (the fine-scroll target). Allow generous tolerance for
    // font-metric differences.
    expect(
      line5Fraction,
      closeTo(0.3, 0.1),
      reason: '[${mode.name}] the target line must land at ~30% of the '
          'viewport, not the paragraph start; got '
          'fraction=${line5Fraction.toStringAsFixed(3)}',
    );

      // Tear down this mode's tree cleanly before the next mode (disposing
      // a live tree mid-animation trips framework assertions).
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
}

ProviderContainer containerOf(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(UncontrolledProviderScope)),
  );
}
