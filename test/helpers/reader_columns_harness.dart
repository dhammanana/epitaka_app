/// The real reader route with AN 5.36 and its aṭṭhakathā and ṭīkā, for the
/// column tests. Rows copied from epitaka.db (`fixtures/an5_columns_rows.json`).
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
import 'package:shared_preferences/shared_preferences.dart';

import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/models/context_menu_action.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:epitaka/features/reader/services/book_family_service.dart';
import 'package:epitaka/features/reader/widgets/reader_column.dart';
import 'package:epitaka/router/app_router.dart';

final an5Fixture =
    jsonDecode(File('test/fixtures/an5_columns_rows.json').readAsStringSync())
        as Map<String, dynamic>;

const an5Books = ['A-v', 'Mp-v', 'Mp-t-v'];

Future<EpitakaDatabase> seedAn5() async {
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
  await db.customStatement(
    'CREATE TABLE book_links ('
    'src_book TEXT NOT NULL, src_para INTEGER NOT NULL, '
    'src_line INTEGER NOT NULL, dst_book TEXT NOT NULL, '
    'dst_para INTEGER NOT NULL, dst_line INTEGER NOT NULL, '
    'word TEXT NOT NULL)',
  );
  for (final bookId in an5Books) {
    final entry = an5Fixture[bookId] as Map<String, dynamic>;
    final book = entry['book'] as List;
    await db
        .into(db.books)
        .insert(
          BooksCompanion.insert(
            bookId: bookId,
            bookName: Value(book[0] as String),
            category: Value(book[1] as String),
            mulaRef: Value(book[2] as String?),
            atthaRef: Value(book[3] as String?),
            tikaRef: Value(book[4] as String?),
          ),
        );
    for (final r in entry['rows'] as List) {
      await db
          .into(db.sentences)
          .insert(
            SentencesCompanion.insert(
              bookId: bookId,
              paraId: r[0] as int,
              lineId: r[1] as int,
              vripara: Value(r[2] as String?),
              pali: Value(r[3] as String),
            ),
          );
    }
    for (final h in entry['headings'] as List) {
      await db
          .into(db.headings)
          .insert(
            HeadingsCompanion.insert(
              bookId: bookId,
              paraId: h[0] as int,
              level: Value(h[1] as int),
              title: Value(h[2] as String),
            ),
          );
    }
  }
  return db;
}

final an5Family = buildBookFamilies([
  for (final bookId in an5Books)
    BookRefsRow(
      bookId: bookId,
      category: (an5Fixture[bookId]['book'] as List)[1] as String,
      mulaRef: (an5Fixture[bookId]['book'] as List)[2] as String?,
      atthaRef: (an5Fixture[bookId]['book'] as List)[3] as String?,
      tikaRef: (an5Fixture[bookId]['book'] as List)[4] as String?,
    ),
])['A-v']!;

String bookName(String bookId) =>
    (an5Fixture[bookId]['book'] as List)[0] as String;

/// Mounts the reader route at [size] with AN 5 open at sutta 36 and, when
/// [withColumns], its aṭṭhakathā and ṭīkā as columns.
Future<ProviderContainer> pumpColumns(
  WidgetTester tester, {
  Size size = const Size(1500, 900),
  bool withColumns = true,
  TranslationDisplayMode mode = TranslationDisplayMode.lineByLine,
  List<Override> overrides = const [],
}) async {
  final db = await tester.runAsync(seedAn5);
  final container = ProviderContainer(
    overrides: [
      epitakaDbProvider.overrideWith((ref) async => db!),
      translationDbProvider.overrideWith((ref, code) async => null),
      settingsProvider.overrideWith((ref) {
        final notifier = SettingsNotifier(null);
        notifier.state = AppSettings(
          showTranslation: false,
          translationDisplayMode: mode,
          // One action, so the phone-style toolbar has no overflow menu.
          contextMenuActions: const [
            ContextMenuAction(
              id: 'builtin:showBeside',
              kind: ContextMenuActionKind.builtin,
              builtinId: ContextMenuBuiltins.showBeside,
            ),
          ],
        );
        return notifier;
      }),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  // A tap that focuses a column also looks its word up, which saves the
  // dictionary panel as open; left behind, it narrows later files' layout.
  addTearDown(() => SharedPreferences.setMockInitialValues({}));

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final tabs = container.read(readerTabsProvider.notifier);
  tabs.openTab(
    ReaderTabInfo(bookId: 'A-v', bookName: bookName('A-v'), initialParaId: 222),
  );
  if (withColumns) {
    tabs.toggleFamilyColumn(
      ReaderTabInfo(
        bookId: 'Mp-v',
        bookName: bookName('Mp-v'),
        initialParaId: 99,
      ),
      sourceBookId: 'A-v',
      family: an5Family,
    );
    tabs.toggleFamilyColumn(
      ReaderTabInfo(
        bookId: 'Mp-t-v',
        bookName: bookName('Mp-t-v'),
        initialParaId: 96,
      ),
      sourceBookId: 'A-v',
      family: an5Family,
    );
  }

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
  await pumpFrames(tester, 20);
  return container;
}

Future<void> pumpFrames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The plain text of every paragraph drawn inside [of].
String drawnText(WidgetTester tester, Finder of) {
  final buffer = StringBuffer();
  for (final e
      in find.descendant(of: of, matching: find.byType(RichText)).evaluate()) {
    final rp = e.renderObject;
    if (rp is RenderParagraph && rp.attached) {
      buffer.writeln(rp.text.toPlainText());
    }
  }
  return buffer.toString();
}

Finder columnAt(int index) => find.byType(ReaderColumn).at(index);

/// The middle of the first drawn [needle], in global coordinates. With
/// [within], the first [needle] inside the paragraph that draws [within]
/// (for a word that other paragraphs draw too).
Offset wordCenter(WidgetTester tester, String needle, {String? within}) {
  for (final e in find.byType(RichText).evaluate()) {
    final rp = e.renderObject;
    if (rp is! RenderParagraph || !rp.attached || !rp.hasSize) continue;
    final text = rp.text.toPlainText();
    final from = within == null ? 0 : text.indexOf(within);
    if (from < 0) continue;
    final i = text.indexOf(needle, from);
    if (i < 0) continue;
    final box = rp
        .getBoxesForSelection(
          TextSelection(baseOffset: i, extentOffset: i + needle.length),
        )
        .first;
    return rp.localToGlobal(box.toRect().center);
  }
  throw StateError('"$needle" is not drawn');
}

Finder levelButton(String level) =>
    find.byKey(ValueKey('commentary-level-$level')).first;
