/// Regression: tapping an annotation (or any explicit jump request) for the
/// paragraph the reader is already on must still jump — and fine-scroll to
/// the annotated line.
///
/// The reader used to skip the jump when the target paragraph equalled the
/// last-jumped paragraph (`_lastJumpedParaId` guard), so clicking an
/// annotation in the paragraph you were reading did nothing (no scroll to
/// the highlighted line). Explicit jump requests are now stamped with a
/// fresh `initialJumpId` by the tabs provider, and the reader compares ids
/// instead of paragraph values.
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

/// Paragraphs in the test book, each carrying 8 lines so a jump to the
/// "same paragraph, different line" is distinguishable from a no-op.
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
        BooksCompanion.insert(
          bookId: 'dn1',
          bookName: const Value('Dīgha Nikāya 1'),
        ),
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

  Future<ProviderContainer> pumpReader(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        epitakaDbProvider.overrideWith((ref) async => db),
        settingsProvider.overrideWith((ref) {
          final notifier = SettingsNotifier(null);
          notifier.state = const AppSettings(showTranslation: false);
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
    return container;
  }

  testWidgets(
      'opening the same annotation paragraph again still jumps and consumes '
      'the request', (tester) async {
    final container = await pumpReader(tester);

    final tabs = container.read(readerTabsProvider.notifier);

    // Give the reader a moment to finish loading and lay out its items.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // ── First explicit jump: para 10, line 5 ─────────────────────────
    tabs.openTab(
      const ReaderTabInfo(
        bookId: 'dn1',
        bookName: 'Dīgha Nikāya 1',
        initialParaId: _targetParaId,
        initialLineId: 5,
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // The jump ran and consumed the request (initialParaId cleared).
    var tab = container.read(readerTabsProvider).activeTab;
    expect(tab, isA<ReaderTabInfo>());
    expect(
      tab!.currentParaId,
      inInclusiveRange(_targetParaId - 2, _targetParaId),
      reason: 'the reader must be at para ~$_targetParaId after the jump',
    );
    expect(tab.initialParaId, null,
        reason: 'the first jump must clear the requested position');

    // ── Second request for the SAME paragraph (line 1 instead of 5) ──
    // This is the annotation-tap scenario: the tab is already at para 10
    // but the user taps another annotation in the same paragraph.
    tabs.openTab(
      const ReaderTabInfo(
        bookId: 'dn1',
        bookName: 'Dīgha Nikāya 1',
        initialParaId: _targetParaId,
        initialLineId: 1,
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    tab = container.read(readerTabsProvider).activeTab;
    expect(tab, isA<ReaderTabInfo>());
    expect(
      tab!.initialParaId,
      null,
      reason:
          'a repeat jump request for the paragraph the reader is already '
          'on must still be honored (its position consumed by the jump); '
          'otherwise the annotated line is never scrolled to',
    );
    expect(
      tab.currentParaId,
      inInclusiveRange(_targetParaId - 2, _targetParaId),
      reason: 'the reader must stay at para ~$_targetParaId',
    );
  });
}
