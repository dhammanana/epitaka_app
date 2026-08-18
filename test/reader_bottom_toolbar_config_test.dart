/// Verifies the reader bottom toolbar renders exactly the actions enabled
/// in the configurable item list (Settings → Toolbar), in that order, and
/// skips actions a surface doesn't wire up.
library;

import 'package:epitaka/core/models/toolbar_item.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/reader/widgets/reader_bottom_toolbar.dart';
import 'package:epitaka/features/settings/providers/tts_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    supportedLocales: AppLocalizationsDelegate.supportedLocales,
    localizationsDelegates: const [AppLocalizationsDelegate()],
    theme: ThemeData(
      useMaterial3: true,
      splashFactory: InkSplash.splashFactory,
    ),
    home: Scaffold(body: Center(child: child)),
  );

  ReaderBottomToolbar toolbar({List<ToolbarItem>? items, bool flat = false}) {
    return ReaderBottomToolbar(
      colors: const ColorScheme.light(),
      displayMode: TranslationDisplayMode.lineByLine,
      showTranslation: true,
      ttsPlayback: TtsPlaybackState.stopped,
      items: items ?? defaultToolbarItems(),
      flat: flat,
      onContentsTap: () {},
      onOutlineTap: () {},
      onSearchTap: () {},
      onDictionaryTap: () {},
      onJumpTap: () {},
      onDisplayLayoutTap: () {},
      onListenTap: () {},
      onStopTap: () {},
      onBookmarkTap: () {},
      onAnnotationsTap: () {},
      onSummarizeTap: () {},
    );
  }

  testWidgets('default config renders every action in natural order', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(toolbar()));
    await tester.pump();

    // All ten pill actions present.
    expect(find.byIcon(Icons.format_list_bulleted), findsOneWidget);
    expect(find.byIcon(Icons.account_tree_outlined), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.menu_book), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(find.byIcon(Icons.view_headline), findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byIcon(Icons.edit_note), findsOneWidget);
    expect(find.byIcon(Icons.summarize_outlined), findsOneWidget);

    // Default order: contents before jump, jump before bookmark.
    final contentsY = tester
        .getTopLeft(find.byIcon(Icons.format_list_bulleted))
        .dx;
    final jumpX = tester.getTopLeft(find.byIcon(Icons.open_in_new)).dx;
    final bookmarkX = tester.getTopLeft(find.byIcon(Icons.bookmark)).dx;
    expect(contentsY, lessThan(jumpX));
    expect(jumpX, lessThan(bookmarkX));
  });

  testWidgets('disabled items are hidden, enabled order is preserved', (
    tester,
  ) async {
    // Move jump to the front and disable search + bookmark.
    final items =
        [
          ToolbarItem(id: ToolbarBuiltins.jump),
          ToolbarItem(id: ToolbarBuiltins.search, enabled: false),
          ...defaultToolbarItems().where(
            (i) =>
                i.id != ToolbarBuiltins.jump && i.id != ToolbarBuiltins.search,
          ),
        ].map((i) {
          if (i.id == ToolbarBuiltins.bookmark)
            return i.copyWith(enabled: false);
          return i;
        }).toList();

    await tester.pumpWidget(wrap(toolbar(items: items)));
    await tester.pump();

    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.byIcon(Icons.bookmark), findsNothing);

    // Jump is now the leftmost button.
    final jumpX = tester.getTopLeft(find.byIcon(Icons.open_in_new)).dx;
    final contentsX = tester
        .getTopLeft(find.byIcon(Icons.format_list_bulleted))
        .dx;
    expect(jumpX, lessThan(contentsX));
  });

  testWidgets('flat status bar skips actions it does not wire up', (
    tester,
  ) async {
    // Flat mode only wires jump/display/listen/bookmark/summarize (like the
    // desktop status bar) — contents/outline/search/dictionary/annotations
    // must be skipped even though they're enabled in the config.
    final flatToolbar = ReaderBottomToolbar(
      colors: const ColorScheme.light(),
      displayMode: TranslationDisplayMode.lineByLine,
      showTranslation: true,
      ttsPlayback: TtsPlaybackState.stopped,
      items: defaultToolbarItems(),
      flat: true,
      onJumpTap: () {},
      onDisplayLayoutTap: () {},
      onListenTap: () {},
      onStopTap: () {},
      onBookmarkTap: () {},
      onSummarizeTap: () {},
    );

    await tester.pumpWidget(wrap(flatToolbar));
    await tester.pump();

    expect(find.byIcon(Icons.format_list_bulleted), findsNothing);
    expect(find.byIcon(Icons.account_tree_outlined), findsNothing);
    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.byIcon(Icons.menu_book), findsNothing);
    expect(find.byIcon(Icons.edit_note), findsNothing);

    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byIcon(Icons.summarize_outlined), findsOneWidget);
  });

  testWidgets('all actions disabled renders nothing', (tester) async {
    final items = [
      for (final id in ToolbarBuiltins.defaults)
        ToolbarItem(id: id, enabled: false),
    ];
    await tester.pumpWidget(wrap(toolbar(items: items)));
    await tester.pump();

    expect(find.byType(ToolbarButton), findsNothing);
    expect(find.byType(SingleChildScrollView), findsNothing);
  });
}
