/// The mūla, aṭṭhakathā and ṭīkā of AN 5.36 as three columns of the real
/// reader route.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/features/reader/providers/reader_columns_controller.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:epitaka/features/reader/services/book_family_service.dart';
import 'package:epitaka/features/reader/widgets/reader_column.dart';

import 'helpers/reader_columns_harness.dart';

void main() {
  testWidgets('the mūla, aṭṭhakathā and ṭīkā show side by side', (
    tester,
  ) async {
    await pumpColumns(tester);

    expect(find.byType(ReaderColumn), findsNWidgets(3));
    for (final (i, bookId) in an5Books.indexed) {
      expect(
        find.descendant(of: columnAt(i), matching: find.text(bookName(bookId))),
        findsOneWidget,
        reason: 'header of $bookId',
      );
    }
    expect(drawnText(tester, columnAt(0)), contains('kāladānāni'));
    expect(drawnText(tester, columnAt(1)), contains('yuttadānāni'));
    expect(drawnText(tester, columnAt(2)), contains('phalārāmato'));
    // Each column draws only its own book.
    expect(drawnText(tester, columnAt(0)), isNot(contains('yuttadānāni')));
  });

  testWidgets('a tap in a column makes it the active tab; columns never '
      'slide sideways', (tester) async {
    final container = await pumpColumns(tester);
    expect(container.read(readerTabsProvider).activeTab!.bookId, 'A-v');

    await tester.tap(columnAt(1));
    await tester.pump();
    expect(container.read(readerTabsProvider).activeTab!.bookId, 'Mp-v');
    for (final t in tester.widgetList<Transform>(
      find.descendant(
        of: find.byType(ReaderColumn),
        matching: find.byType(Transform),
      ),
    )) {
      expect(t.transform.getTranslation().x, 0);
    }
    await pumpFrames(tester, 5);
    expect(find.byType(ReaderColumn), findsNWidgets(3));
  });

  testWidgets('the header button closes the book', (tester) async {
    final container = await pumpColumns(tester);

    await tester.tap(
      find.descendant(of: columnAt(2), matching: find.byIcon(Icons.close)),
    );
    await pumpFrames(tester, 5);

    final state = container.read(readerTabsProvider);
    expect(state.columns, ['A-v', 'Mp-v']);
    expect(state.tabs.map((t) => t.bookId), ['A-v', 'Mp-v']);
    expect(find.byType(ReaderColumn), findsNWidgets(2));
  });

  testWidgets('closing the focused column keeps the other two on screen', (
    tester,
  ) async {
    final container = await pumpColumns(tester);
    await tester.tap(columnAt(1));
    await pumpFrames(tester, 2);
    await tester.tap(
      find.descendant(of: columnAt(1), matching: find.byIcon(Icons.close)),
    );
    await pumpFrames(tester, 5);

    expect(container.read(readerTabsProvider).columns, ['A-v', 'Mp-t-v']);
    expect(find.byType(ReaderColumn), findsNWidgets(2));
    expect(drawnText(tester, columnAt(1)), contains('phalārāmato'));
  });

  testWidgets('closing a column tab takes its column out', (tester) async {
    final container = await pumpColumns(tester);
    final tabs = container.read(readerTabsProvider);
    container
        .read(readerTabsProvider.notifier)
        .closeTab(tabs.tabs.indexWhere((t) => t.bookId == 'Mp-v'));
    await pumpFrames(tester, 5);

    expect(container.read(readerTabsProvider).columns, ['A-v', 'Mp-t-v']);
    expect(find.byType(ReaderColumn), findsNWidgets(2));
    expect(drawnText(tester, columnAt(1)), contains('phalārāmato'));
  });

  testWidgets('below 840 px wide only the active tab shows', (tester) async {
    final container = await pumpColumns(tester, size: const Size(830, 900));

    expect(find.byType(ReaderColumn), findsNothing);
    expect(container.read(readerTabsProvider).columns, hasLength(3));
    final text = drawnText(tester, find.byType(MaterialApp));
    expect(text, contains('kāladānāni'));
    expect(text, isNot(contains('yuttadānāni')));
  });

  group('m a ṭ buttons', () {
    testWidgets('A on AN 5.36 opens the aṭṭhakathā at its sutta 36; '
        'A again takes it out', (tester) async {
      final container = await pumpColumns(tester, withColumns: false);
      final controller = container.read(readerColumnsControllerProvider);
      expect(controller.readingParaId('A-v'), 222);
      // The tab's saved place goes through a 50 ms real-time throttle, so
      // after a jump it can still name an earlier paragraph. Set that state
      // here; the test clock cannot produce it reliably.
      container
          .read(readerTabsProvider.notifier)
          .updateScrollOffset(0, 0, paraId: 200);

      await tester.tap(levelButton('attha'));
      await pumpFrames(tester, 20);

      expect(container.read(readerTabsProvider).columns, ['A-v', 'Mp-v']);
      expect(container.read(readerTabsProvider).activeTab!.bookId, 'A-v');
      expect(controller.readingParaId('Mp-v'), 99);
      expect(controller.readingParaId('A-v'), 222, reason: 'the mūla stays');

      await tester.tap(levelButton('tika'));
      await pumpFrames(tester, 20);
      expect(container.read(readerTabsProvider).columns, [
        'A-v',
        'Mp-v',
        'Mp-t-v',
      ]);
      expect(controller.readingParaId('Mp-t-v'), 96);

      await tester.tap(levelButton('attha'));
      await pumpFrames(tester, 5);
      expect(container.read(readerTabsProvider).columns, ['A-v', 'Mp-t-v']);

      await tester.tap(levelButton('tika'));
      await pumpFrames(tester, 5);
      expect(container.read(readerTabsProvider).columns, isEmpty);
      expect(controller.readingParaId('A-v'), 222, reason: 'back to one tab');
      // Let the 3 s reading-history save the moves started run out.
      await pumpFrames(tester, 40);
    });

    testWidgets('below the width gate, A opens the aṭṭhakathā as a tab at '
        'sutta 36', (tester) async {
      final container = await pumpColumns(
        tester,
        size: const Size(830, 900),
        withColumns: false,
      );
      final controller = container.read(readerColumnsControllerProvider);

      await tester.tap(levelButton('attha'));
      await pumpFrames(tester, 20);
      var state = container.read(readerTabsProvider);
      expect(state.activeTab!.bookId, 'Mp-v');
      expect(state.columns, isEmpty);
      expect(find.byType(ReaderColumn), findsNothing);
      expect(controller.readingParaId('Mp-v'), 99);

      await tester.tap(levelButton('mula'));
      await pumpFrames(tester, 20);
      state = container.read(readerTabsProvider);
      expect(state.activeTab!.bookId, 'A-v');
      expect(controller.readingParaId('A-v'), 222);
      // Let the 3 s reading-history save the moves started run out.
      await pumpFrames(tester, 40);
    });

    testWidgets('a book with no family shows no m a ṭ', (tester) async {
      await pumpColumns(
        tester,
        withColumns: false,
        overrides: [bookFamiliesProvider.overrideWith((ref) async => const {})],
      );
      expect(
        find.byKey(const ValueKey('commentary-level-attha')),
        findsNothing,
      );

      // The selection entry hides too, under either of its labels.
      await tester.longPressAt(wordCenter(tester, 'kāladānāni'));
      await pumpFrames(tester, 3);
      expect(find.text('Show beside'), findsNothing);
      expect(find.text('Open mūla / aṭṭhakathā / ṭīkā'), findsNothing);
      await pumpFrames(tester, 40);
    });
  });

  testWidgets('side-by-side gives way to line-by-line while columns show', (
    tester,
  ) async {
    final container = await pumpColumns(
      tester,
      mode: TranslationDisplayMode.sideBySide,
    );
    TranslationDisplayMode mode() =>
        container.read(settingsProvider).translationDisplayMode;
    expect(mode(), TranslationDisplayMode.lineByLine);

    final tabs = container.read(readerTabsProvider.notifier);
    int indexOf(String bookId) => container
        .read(readerTabsProvider)
        .tabs
        .indexWhere((t) => t.bookId == bookId);
    tabs.closeTab(indexOf('Mp-t-v'));
    await pumpFrames(tester, 2);
    expect(mode(), TranslationDisplayMode.lineByLine, reason: 'two columns');

    tabs.closeTab(indexOf('Mp-v'));
    await pumpFrames(tester, 2);
    expect(find.byType(ReaderColumn), findsNothing);
    expect(mode(), TranslationDisplayMode.sideBySide);
  });

  testWidgets('the right-click entry reaches the same state as the A button', (
    tester,
  ) async {
    final container = await pumpColumns(tester, withColumns: false);
    final controller = container.read(readerColumnsControllerProvider);
    ({List<String> columns, int? para}) current() => (
      columns: container.read(readerTabsProvider).columns,
      para: controller.readingParaId('Mp-v'),
    );

    // AN 5.36's first line: "36.‘‘ Pañcimāni, bhikkhave, kāladānāni."
    await tester.longPressAt(wordCenter(tester, 'kāladānāni'));
    await pumpFrames(tester, 3);
    await tester.tap(find.text('Show beside'));
    await pumpFrames(tester, 3);
    await tester.tap(find.textContaining('aṭṭhakathā — '));
    await pumpFrames(tester, 20);
    final viaMenu = current();
    expect(viaMenu.columns, ['A-v', 'Mp-v']);
    expect(viaMenu.para, 99);
    expect(controller.readingParaId('A-v'), 222, reason: 'the mūla stays');

    await tester.tap(levelButton('attha'));
    await pumpFrames(tester, 5);
    expect(container.read(readerTabsProvider).columns, isEmpty);
    await tester.tap(levelButton('attha'));
    await pumpFrames(tester, 20);
    expect(current().columns, viaMenu.columns);
    expect(current().para, viaMenu.para);
    // Let the 3 s reading-history save the moves started run out.
    await pumpFrames(tester, 40);
  });

  testWidgets('below the gate the selection entry opens the book as a tab', (
    tester,
  ) async {
    final container = await pumpColumns(
      tester,
      size: const Size(830, 900),
      withColumns: false,
    );
    final controller = container.read(readerColumnsControllerProvider);

    await tester.longPressAt(wordCenter(tester, 'kāladānāni'));
    await pumpFrames(tester, 3);
    expect(find.text('Show beside'), findsNothing);
    await tester.tap(find.text('Open mūla / aṭṭhakathā / ṭīkā'));
    await pumpFrames(tester, 3);
    await tester.tap(find.textContaining('aṭṭhakathā — '));
    await pumpFrames(tester, 20);

    final state = container.read(readerTabsProvider);
    expect(state.activeTab!.bookId, 'Mp-v');
    expect(state.columns, isEmpty);
    expect(controller.readingParaId('Mp-v'), 99);
    // Let the 3 s reading-history save the moves started run out.
    await pumpFrames(tester, 40);
  });

  testWidgets('a word that sutta 35 also has still opens sutta 36', (
    tester,
  ) async {
    final container = await pumpColumns(tester, withColumns: false);
    final asked = <int>[];
    container.listen(readerTabsProvider, (_, next) {
      final para = next.tabs
          .where((t) => t.bookId == 'Mp-v')
          .firstOrNull
          ?.initialParaId;
      if (para != null) asked.add(para);
    });

    // "bhikkhave" is in the last line of sutta 36 and in sutta 35's lines,
    // which sit inside the window the selection is matched in.
    await tester.longPressAt(
      wordCenter(tester, 'bhikkhave', within: 'imāni kho'),
    );
    await pumpFrames(tester, 3);
    await tester.tap(find.text('Show beside'));
    await pumpFrames(tester, 3);
    await tester.tap(find.textContaining('aṭṭhakathā — '));
    await pumpFrames(tester, 20);

    // The paragraph the column was asked for. The tab drops it once the
    // column has jumped, and the drawn reading paragraph cannot tell 97
    // from 99 (Mp-v 97 and 98 are one short line each).
    expect(asked.first, 99, reason: 'sutta 36, not 35 (Mp-v 97)');
    await pumpFrames(tester, 40);
  });

  testWidgets('closing the reader while columns show restores the saved mode', (
    tester,
  ) async {
    final container = await pumpColumns(
      tester,
      mode: TranslationDisplayMode.sideBySide,
    );
    TranslationDisplayMode mode() =>
        container.read(settingsProvider).translationDisplayMode;
    expect(mode(), TranslationDisplayMode.lineByLine);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(mode(), TranslationDisplayMode.sideBySide);
  });
}
