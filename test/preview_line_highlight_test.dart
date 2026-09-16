/// Regression tests for the paragraph preview sheet (book-link sections,
/// AI-citation and search-result quickviews).
///
/// The sheet should:
///  1. scroll to the exact matched line (not the paragraph beginning),
///  2. highlight only that line (not the whole paragraph),
///  3. reach a deep target promptly even when rows are tall (a fixed
///     pixel-per-row estimate undershoots and retries the same offset
///     forever, leaving the sheet at the wrong position).
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
  List<Container> highlightedContainers(WidgetTester tester) =>
      tester.widgetList<Container>(find.byType(Container)).where((c) {
        final deco = c.decoration;
        return deco is BoxDecoration &&
            deco.border is Border &&
            (deco.border! as Border).left.width == 3;
      }).toList();

  List<PreviewLineData> makeLines(int paras, int linesPerPara) => [
    for (var p = 1; p <= paras; p++)
      for (var l = 1; l <= linesPerPara; l++)
        PreviewLineData(
          paraId: p,
          lineId: l,
          pali: 'para $p line $l pali text',
        ),
  ];

  /// Lines with long translations so each rendered row is tall (wraps to
  /// many visual lines), mimicking real Pāli + translation rows on device.
  /// Tall rows defeat any fixed pixel-per-row jump estimate: the true
  /// offset of a deep target far exceeds index × ~96px.
  List<PreviewLineData> makeTallLines(int paras, int linesPerPara) {
    final longakka = List.filled(12, 'lorem ipsum dolor sit amet').join(' ');
    return [
      for (var p = 1; p <= paras; p++)
        for (var l = 1; l <= linesPerPara; l++)
          PreviewLineData(
            paraId: p,
            lineId: l,
            pali: 'para $p line $l pali text',
            translations: {'en': 'para $p line $l $longakka'},
          ),
    ];
  }

  Future<GlobalKey> openSheet(
    WidgetTester tester, {
    required List<PreviewLineData> lines,
    required int scrollToParaId,
    required int scrollToLineId,
    int? highlightParaId,
    int? highlightLineId,
  }) async {
    final openKey = GlobalKey();
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
      lines: lines,
      highlightParaId: highlightParaId ?? scrollToParaId,
      highlightLineId: highlightLineId,
      scrollToParaId: scrollToParaId,
      scrollToLineId: scrollToLineId,
      actionLabel: 'Open',
      onAction: (paraId, lineId) {},
    );
    return openKey;
  }

  /// Asserts the target line's text is laid out inside the sheet viewport.
  void expectTargetVisible(WidgetTester tester, String targetText) {
    final viewportFinder = find.byType(Viewport);
    expect(viewportFinder, findsWidgets, reason: 'the sheet must be open');
    final viewportBox = tester.renderObject<RenderBox>(viewportFinder.first);

    final targetFinder = find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains(targetText),
    );
    expect(targetFinder, findsWidgets, reason: 'target line must be built');
    final targetBox = tester.renderObject<RenderBox>(targetFinder.first);

    final scrollTop = viewportBox.localToGlobal(Offset.zero).dy;
    final scrollBottom = scrollTop + viewportBox.size.height;
    final targetTop = targetBox.localToGlobal(Offset.zero).dy;
    final targetBottom = targetTop + targetBox.size.height;

    expect(
      targetBottom > scrollTop && targetTop < scrollBottom,
      isTrue,
      reason:
          'target line (y=$targetTop..$targetBottom) must be within the '
          'sheet viewport (y=$scrollTop..$scrollBottom) — it was not '
          'scrolled into view',
    );
  }

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

  testWidgets('without highlightLineId the whole paragraph is highlighted', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: PreviewContent(lines: makeLines(2, 3), highlightParaId: 1),
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

  testWidgets('targetLineKey attaches to the exact line at its index', (
    tester,
  ) async {
    final targetKey = GlobalKey();
    await tester.pumpWidget(
      wrap(
        SingleChildScrollView(
          child: PreviewContent(
            lines: makeLines(3, 3),
            // para 2 line 3 is the 6th line → index 5.
            targetLineKey: targetKey,
            targetLineIndex: 5,
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

  testWidgets('preview sheet scrolls the target line into view', (
    tester,
  ) async {
    await openSheet(
      tester,
      lines: makeLines(30, 3), // target sits ~line 75, far below the fold
      highlightParaId: 25,
      highlightLineId: 2,
      scrollToParaId: 25,
      scrollToLineId: 2,
    );
    await tester.pumpAndSettle();

    expectTargetVisible(tester, 'para 25 line 2');
  });

  testWidgets('deep target with tall rows lands promptly on the line', (
    tester,
  ) async {
    await openSheet(
      tester,
      // 90 tall rows; target para 25 line 2 sits at index 73 (~line 74).
      // Tall rows defeat any fixed pixel-per-row jump estimate, so the
      // sheet must page forward to the row instead of stalling at the top.
      lines: makeTallLines(30, 3),
      highlightParaId: 25,
      highlightLineId: 2,
      scrollToParaId: 25,
      scrollToLineId: 2,
    );
    // Bounded budget: first frame + entrance, then a handful of 100ms
    // scroll retries. Must NOT need the full give-up loop to get there.
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expectTargetVisible(tester, 'para 25 line 2');
  });

  testWidgets('missing line lands on the closest line of the paragraph', (
    tester,
  ) async {
    await openSheet(
      tester,
      lines: makeLines(3, 3),
      highlightParaId: 2,
      scrollToParaId: 2,
      // Line 9 does not exist in para 2 (which holds lines 1-3): the
      // sheet must land on line 3, not the paragraph beginning.
      scrollToLineId: 9,
    );
    await tester.pumpAndSettle();

    expectTargetVisible(tester, 'para 2 line 3');
  });

  testWidgets('action reports the line the user stopped reading at', (
    tester,
  ) async {
    final openKey = GlobalKey();
    (int, int?)? reported;

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
    await tester.pumpAndSettle();
    expect(openKey.currentContext, isNotNull);

    showParagraphPreviewSheet(
      openKey.currentContext!,
      title: 'Section title',
      lines: makeLines(30, 3),
      scrollToParaId: 10,
      scrollToLineId: 1,
      actionLabel: 'Open',
      onAction: (paraId, lineId) => reported = (paraId, lineId),
    );
    await tester.pumpAndSettle();

    // Scroll the sheet well past the original target (para 10) to para ~25.
    final scrollable = tester.widget<Scrollable>(find.byType(Scrollable));
    final controller = scrollable.controller!;
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();

    // Tap the action button (the sheet header's "Open").
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(reported, isNotNull, reason: 'the action must have fired');
    expect(
      reported!.$1,
      inInclusiveRange(27, 30),
      reason:
          'after scrolling to the bottom the reported paragraph must be near '
          'the end, NOT the original scroll target 10 — got ${reported!.$1}',
    );
  });
}
