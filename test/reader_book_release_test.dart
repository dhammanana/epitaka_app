/// Closing a tab must release its book's data. Before the fix every book
/// opened since start-up stayed in memory, and a translation or page-system
/// change reloaded all of them (5 books on the Pixel 8 Pro walk, 2 open).
///
/// Uses the REAL [readerDataProvider] and [readerTabsProvider] with a seeded
/// in-memory database.
library;

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/features/reader/providers/reader_provider.dart';
import 'package:epitaka/features/reader/providers/reader_scroll_controller.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';

const _books = ['b1', 'b2', 'b3'];

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
  for (final b in _books) {
    await db
        .into(db.books)
        .insert(BooksCompanion.insert(bookId: b, bookName: Value(b)));
    for (var p = 1; p <= 3; p++) {
      await db
          .into(db.sentences)
          .insert(
            SentencesCompanion.insert(
              bookId: b,
              paraId: p,
              lineId: 1,
              pali: Value('$b paragraph $p'),
            ),
          );
    }
  }
  return db;
}

void main() {
  late EpitakaDatabase db;
  late ProviderContainer container;
  late List<String> printed;

  setUp(() async {
    db = await _seedDatabase();
    container = ProviderContainer(
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
    addTearDown(db.close);
  });

  /// Collects debugPrint lines for this test (widget tests must leave
  /// debugPrint untouched, so only the plain tests call this).
  void capturePrints() {
    printed = [];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
    addTearDown(() => debugPrint = original);
  }

  ReaderTabsNotifier tabs() => container.read(readerTabsProvider.notifier);

  void open(String bookId) =>
      tabs().openTab(ReaderTabInfo(bookId: bookId, bookName: bookId));

  void close(String bookId) => tabs().closeTab(
    container
        .read(readerTabsProvider)
        .tabs
        .indexWhere((t) => t.bookId == bookId),
  );

  Future<void> load(String bookId) =>
      container.read(readerDataProvider(bookId).notifier).waitUntilLoaded();

  test('a closed tab releases its book and only open books reload', () async {
    capturePrints();
    open('b1');
    open('b2');
    await load('b1');
    await load('b2');

    close('b1');
    await container.pump();
    expect(container.exists(readerDataProvider('b1')), isFalse);
    expect(container.exists(readerDataProvider('b2')), isTrue);
    expect(container.read(readerDataProvider('b2')).isLoaded, isTrue);

    // A page-system change reloads every book still held: only b2 now.
    printed.clear();
    final b2 = container.read(readerDataProvider('b2'));
    final reloaded = container
        .read(readerDataProvider('b2').notifier)
        .stream
        .firstWhere((s) => s.isLoaded && !identical(s.paragraphs, b2.paragraphs));
    final settings = container.read(settingsProvider.notifier);
    settings.state = settings.state.copyWith(pageNumberingSystem: 'pts');
    await reloaded;
    expect(
      printed.where((l) => l.startsWith('[PERF] book reload')).toList(),
      ['[PERF] book reload book=b2'],
    );
  });

  test('a book read while in no tab stays loaded until a tab of it closes', () async {
    open('b2');
    await load('b2');

    // Code may read a book that is in no tab; it keeps today's behaviour.
    final fresh = container.read(readerDataProvider('b1'));
    expect(fresh.isLoaded, isFalse, reason: 'a fresh load starts');
    await load('b1');
    await container.pump();
    expect(container.exists(readerDataProvider('b1')), isTrue);
    expect(container.read(readerDataProvider('b1')).paragraphs, hasLength(3));

    // Once the book has been in a tab, closing that tab releases it.
    open('b1');
    await container.pump();
    close('b1');
    await container.pump();
    expect(container.exists(readerDataProvider('b1')), isFalse);
  });

  test('closing a tab while its book still loads releases it cleanly', () async {
    capturePrints();
    // The database answers only after the tab has closed, so the load is
    // still running when the book is released.
    final gate = Completer<void>();
    final slow = ProviderContainer(
      overrides: [
        epitakaDbProvider.overrideWith((ref) async {
          await gate.future;
          return db;
        }),
        settingsProvider.overrideWith((ref) {
          final notifier = SettingsNotifier(null);
          notifier.state = const AppSettings(showTranslation: false);
          return notifier;
        }),
      ],
    );
    addTearDown(slow.dispose);

    slow
        .read(readerTabsProvider.notifier)
        .openTab(const ReaderTabInfo(bookId: 'b3', bookName: 'b3'));
    slow.read(readerDataProvider('b3'));
    slow.read(readerTabsProvider.notifier).closeTab(0);
    await slow.pump();
    expect(slow.exists(readerDataProvider('b3')), isFalse);

    // Let the abandoned load run to its end; a write to the disposed
    // notifier would surface here as an uncaught error.
    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(printed.where((l) => l.contains('book loaded: b3')), isEmpty);
  });

  testWidgets('a jump still retrying does not bring a closed book back', (
    tester,
  ) async {
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          epitakaDbProvider.overrideWith((r) async => db),
          settingsProvider.overrideWith((r) {
            final notifier = SettingsNotifier(null);
            notifier.state = const AppSettings(showTranslation: false);
            return notifier;
          }),
        ],
        child: Consumer(
          builder: (context, r, _) {
            ref = r;
            return const SizedBox();
          },
        ),
      ),
    );
    final scope = ProviderScope.containerOf(tester.element(find.byType(SizedBox)));

    ref
        .read(readerTabsProvider.notifier)
        .openTab(const ReaderTabInfo(bookId: 'b1', bookName: 'b1'));
    await tester.runAsync(
      () => ref.read(readerDataProvider('b1').notifier).waitUntilLoaded(),
    );

    final appBarCollapsed = ValueNotifier<bool>(false);
    addTearDown(appBarCollapsed.dispose);
    final scroll = ReaderScrollController(
      ref: ref,
      isMounted: () => true,
      isPhone: () => true,
      viewInsetsBottom: () => 0,
      appBarCollapsed: appBarCollapsed,
      onTtsManualScroll: (_, _, _) {},
    );
    addTearDown(scroll.dispose);

    // No list is attached for b1, so the jump retries every frame.
    unawaited(scroll.jumpToParagraph('b1', 2));
    ref.read(readerTabsProvider.notifier).closeTab(0);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(scope.exists(readerDataProvider('b1')), isFalse);
    expect(scroll.suppressAppBarScroll, isFalse);
  });
}
