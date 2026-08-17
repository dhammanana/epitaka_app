/// Verifies the desktop full-width selection context menu:
///   • spans the reader content column (the widget size),
///   • sits just above the selection anchor (clamped to the screen),
///   • falls back to the stock anchored toolbar when the content widget
///     isn't measurable or the anchors are the zero fallback.
library;

import 'package:epitaka/features/reader/widgets/reader_context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget button(String label) => ContextMenuButton(
    icon: Icons.copy,
    label: label,
    onTap: () {},
    colors: const ColorScheme.light(),
  );

  Widget wrap(Widget child) => MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      splashFactory: InkSplash.splashFactory,
    ),
    home: Scaffold(body: child),
  );

  testWidgets('bar spans the content column and sits above the anchor', (
    tester,
  ) async {
    final contentKey = GlobalKey();
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;

    await tester.pumpWidget(
      wrap(
        Stack(
          children: [
            // A content column with a known global rect.
            Positioned(
              left: 100,
              top: 100,
              width: 400,
              height: 200,
              child: ColoredBox(
                color: Colors.red,
                child: SizedBox(key: contentKey),
              ),
            ),
            FullWidthSelectionToolbar(
              anchors: const TextSelectionToolbarAnchors(
                primaryAnchor: Offset(300, 250),
              ),
              contentHitTestKey: contentKey,
              children: [button('Copy'), button('Excerpt')],
            ),
          ],
        ),
      ),
    );
    // Second frame: the post-frame callback flips the widget to the
    // full-width path once the content box has a size.
    await tester.pump();

    final bar = find.descendant(
      of: find.byType(FullWidthSelectionToolbar),
      matching: find.byType(Material),
    );
    expect(bar, findsOneWidget);

    // Full width of the content column (400px at x=100), not the intrinsic
    // button width.
    final barSize = tester.getSize(bar);
    expect(barSize.width, moreOrLessEquals(400, epsilon: 0.1));

    // Positioned above the anchor (300, 250): bottom of the bar is ~12px
    // above the anchor's y.
    final barTopLeft = tester.getTopLeft(bar);
    expect(barTopLeft.dx, moreOrLessEquals(100, epsilon: 0.1));
    expect(
      barTopLeft.dy + barSize.height + 12,
      moreOrLessEquals(250, epsilon: 2.0),
    );

    // The actions are all present, spread across the bar.
    expect(
      find.descendant(of: find.byType(FullWidthSelectionToolbar), matching: find.byType(ContextMenuButton)),
      findsNWidgets(2),
    );

    // Sanity: the test view is wide enough that the bar fits on screen.
    expect(size.width, greaterThan(500));
  });

  testWidgets('falls below the anchor when there is no room above', (
    tester,
  ) async {
    final contentKey = GlobalKey();

    await tester.pumpWidget(
      wrap(
        Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: 300,
              height: 200,
              child: ColoredBox(
                color: Colors.red,
                child: SizedBox(key: contentKey),
              ),
            ),
            FullWidthSelectionToolbar(
              anchors: const TextSelectionToolbarAnchors(
                primaryAnchor: Offset(150, 5),
              ),
              contentHitTestKey: contentKey,
              children: [button('Copy')],
            ),
          ],
        ),
      ),
    );
    // Second frame: let the post-frame callback switch to the full-width
    // path now that the content box is laid out.
    await tester.pump();

    final bar = find.descendant(
      of: find.byType(FullWidthSelectionToolbar),
      matching: find.byType(Material),
    );
    // Anchor is at y=5 — no room above, so the bar's top edge sits ~12px
    // below the anchor.
    final barTopLeft = tester.getTopLeft(bar);
    expect(barTopLeft.dy, moreOrLessEquals(5 + 12, epsilon: 2.0));
  });

  testWidgets('falls back to the stock toolbar when the content is unmeasurable',
      (tester) async {
    // Unattached key → content render box is null.
    await tester.pumpWidget(
      wrap(
        FullWidthSelectionToolbar(
          anchors: const TextSelectionToolbarAnchors(
            primaryAnchor: Offset(100, 100),
          ),
          contentHitTestKey: GlobalKey(),
          children: [button('Copy')],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AdaptiveTextSelectionToolbar),
        matching: find.byType(ContextMenuButton),
      ),
      findsOneWidget,
    );
  });

  testWidgets('falls back to the stock toolbar for the zero anchor guard', (
    tester,
  ) async {
    final contentKey = GlobalKey();

    await tester.pumpWidget(
      wrap(
        Stack(
          children: [
            Positioned(
              left: 10,
              top: 10,
              width: 200,
              height: 200,
              child: ColoredBox(
                color: Colors.red,
                child: SizedBox(key: contentKey),
              ),
            ),
            FullWidthSelectionToolbar(
              // Zero anchor = the crash-guard fallback; never position the
              // full-width bar at the screen corner.
              anchors: const TextSelectionToolbarAnchors(
                primaryAnchor: Offset.zero,
              ),
              contentHitTestKey: contentKey,
              children: [button('Copy')],
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
  });
}
