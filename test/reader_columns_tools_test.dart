/// Toolbar tools act on the column the user clicked, not the first one.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/features/reader/providers/reader_search_notifier.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:epitaka/features/reader/widgets/reader_content_with_selection.dart';
import 'package:epitaka/features/reader/widgets/reader_in_book_search_bar.dart';
import 'package:epitaka/shared/utils/app_shortcuts.dart';

import 'helpers/reader_columns_harness.dart';

void main() {
  testWidgets('find searches the focused column only', (tester) async {
    final container = await pumpColumns(tester);
    await tester.tap(columnAt(1));
    await pumpFrames(tester, 2);
    expect(container.read(readerTabsProvider).activeTab!.bookId, 'Mp-v');

    container.read(inBookSearchToggleProvider.notifier).toggle();
    await pumpFrames(tester, 2);
    // "yuttadānāni" is in the aṭṭhakathā's sutta 36 (para 99) only.
    await tester.enterText(
      find.descendant(
        of: find.byType(ReaderInBookSearchBar),
        matching: find.byType(TextField),
      ),
      'yuttadānāni',
    );
    await pumpFrames(tester, 10);

    final search = container.read(inBookSearchProvider);
    expect(search.matchParaIds, [99]);
    // Only the focused column draws the find highlight.
    final queries = {
      for (final content in tester.widgetList<ReaderContentWithSelection>(
        find.byType(ReaderContentWithSelection),
      ))
        content.bookId: content.highlightBundle.searchQuery,
    };
    expect(queries['Mp-v'], isNotNull);
    expect(queries['A-v'], isNull);
    expect(queries['Mp-t-v'], isNull);
    await pumpFrames(tester, 40);
  });

  testWidgets('the jump sheet opens for the focused column', (tester) async {
    final container = await pumpColumns(tester);
    await tester.tap(columnAt(2));
    await pumpFrames(tester, 2);
    expect(container.read(readerTabsProvider).activeTab!.bookId, 'Mp-t-v');

    await tester.tap(find.byIcon(Icons.open_in_new).first);
    await pumpFrames(tester, 5);
    final sheet = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_JumpSheet',
    );
    expect(sheet, findsOneWidget);
    expect((tester.widget(sheet) as dynamic).bookId, 'Mp-t-v');
    expect((tester.widget(sheet) as dynamic).currentParaId, 96);
    await pumpFrames(tester, 40);
  });
}
