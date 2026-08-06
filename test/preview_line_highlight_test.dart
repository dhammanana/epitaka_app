/// Regression tests for the search-result quickview.
///
/// Holding a search result opens a preview sheet that should:
///  1. scroll to the exact matched line (not stay at the top of the section),
///  2. highlight only that line (not the whole paragraph).
///
/// The line-level highlight is driven by the optional `highlightLineId`
/// parameter on [PreviewContent]; callers that don't pass it keep the old
/// paragraph-wide highlight.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/providers/settings_provider.dart';
import '../lib/core/utils/app_localizations.dart';
import '../lib/shared/widgets/paragraph_preview_sheet.dart';
import '../lib/shared/widgets/preview_content.dart';

void main() {
  Widget wrap(Widget child) => ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) {
            final notifier = SettingsNotifier(null);
            notifier.state = const AppSettings();
            return notifier;
          }),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      );

  /// Containers carrying the match highlight (3px left border).
  List<Container> highlightedContainers(WidgetTester tester) => tester
      .widgetList<Container>(find.byType(Container))
      .where((c) {
        final deco = c.decoration;
        return deco is BoxDecoration &&
            deco.border is Border &&
            (deco.border! as Border).left.width == 3;
      })
      .toList();

  List<PreviewLineData> makeLines(int paras, int linesPerPara) => [
        for (var p = 1; p <= paras; p++)
          for (var l = 1; l <= linesPerPara; l++)
            PreviewLineData(
              paraId: p,
              lineId: l,
              pali: 'para $p line $l pali text',
            ),
      ];

  testWidgets('highlightLineId highlights exactly one line', (tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: PreviewContent(
              lines: makeLines(2, 3),
              highlightParaId: 1,
              highlightLineId: 2,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(PreviewContent), findsOneWidget);
    final highlighted = highlightedContainers(tester);
    expect(highlighted, hasLength(1), reason: 'only the matched line');
    final highlightedFinder = find.byWidgetPredicate(
      (w) => w is Container && identical(w, highlighted.single),
    );
    expect(
      find.descendant(
        of: highlightedFinder,
        matching: find.byWidgetPredicate(
          (w) =>
              w is RichText && w.text.toPlainText().contains('para 1 line 2'),
        ),
      ),
      findsOneWidget,
      reason: 'the highlighted container must wrap the matched line',
    );
  });

  testWidgets('without highlightLineId the whole paragraph is highlighted',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: PreviewContent(
              lines: makeLines(2, 3),
              highlightParaId: 1,
            ),
          ),
        ),
      ),
    );

    expect(
      highlightedContainers(tester),
      hasLength(3),
      reason: 'all three lines of paragraph 1 keep the old behaviour',
    );
  });

  testWidgets('targetLineKey attaches to the exact scroll target line',
      (tester) async {
    final targetKey = GlobalKey();
    await tester.pumpWidget(
      wrap(
        SingleChildScrollView(
          child: PreviewContent(
            lines: makeLines(3, 3),
            scrollToParaId: 2,
            scrollToLineId: 3,
            targetLineKey: targetKey,
          ),
        ),
      ),
    );

    expect(find.byKey(targetKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(targetKey),
        matching: find.byWidgetPredicate(
          (w) =>
              w is RichText && w.text.toPlainText().contains('para 2 line 3'),
        ),
      ),
      findsOneWidget,
      reason: 'the key must sit on the exact para 2 / line 3 widget',
    );
  });

  testWidgets('preview sheet scrolls the target line into view',
      (tester) async {
    final openKey = GlobalKey();
    final targetKey = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) {
            final notifier = SettingsNotifier(null);
            notifier.state = const AppSettings();
            return notifier;
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizationsDelegate()],
          home: Builder(
            key: openKey,
            builder: (context) => const Scaffold(body: SizedBox()),
          ),
        ),
      ),
    );
    // Let the async localization load + home build complete before opening.
    await tester.pumpAndSettle();
    expect(openKey.currentContext, isNotNull);

    showParagraphPreviewSheet(
      openKey.currentContext!,
      title: 'Section title',
      lines: makeLines(30, 3), // target sits ~line 75, far below the fold
      highlightParaId: 25,
      highlightLineId: 2,
      scrollToParaId: 25,
      scrollToLineId: 2,
      targetLineKey: targetKey,
    );
    await tester.pumpAndSettle();

    final scrollFinder = find.byType(SingleChildScrollView);
    expect(scrollFinder, findsWidgets, reason: 'the sheet must be open');
    final scrollBox = tester.renderObject<RenderBox>(scrollFinder.last);

    final targetFinder = find.byWidgetPredicate(
      (w) =>
          w is RichText && w.text.toPlainText().contains('para 25 line 2'),
    );
    expect(targetFinder, findsWidgets, reason: 'target line must be built');
    final targetBox = tester.renderObject<RenderBox>(targetFinder.first);

    final scrollTop = scrollBox.localToGlobal(Offset.zero).dy;
    final scrollBottom = scrollTop + scrollBox.size.height;
    final targetTop = targetBox.localToGlobal(Offset.zero).dy;
    final targetBottom = targetTop + targetBox.size.height;

    expect(
      targetBottom > scrollTop && targetTop < scrollBottom,
      isTrue,
      reason: 'target line (y=$targetTop..$targetBottom) must be within the '
          'sheet viewport (y=$scrollTop..$scrollBottom) — it was not '
          'scrolled into view',
    );
  });
}
