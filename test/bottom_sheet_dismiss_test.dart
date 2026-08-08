import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test for tap-outside-to-dismiss on phone bottom sheets.
///
/// `showModalBottomSheet` is dismissible by default (its modal barrier pops
/// the route on tap), but a `DraggableScrollableSheet` built with the default
/// `expand: true` wraps itself in `SizedBox.expand`, so its scrollable's
/// opaque hit-test region covers the *whole* screen and swallows the tap
/// before it ever reaches the barrier. Setting `expand: false` (as the
/// dictionary / AI Q&A sheets now do) restricts the hit region to the sheet
/// itself and restores barrier dismissal.
void main() {
  Future<void> openSheet(WidgetTester tester, Widget sheet) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => sheet,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ));
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
  }

  testWidgets('DraggableScrollableSheet sheet with expand:false dismisses on barrier tap', (tester) async {
    await openSheet(
      tester,
      DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.25,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          color: Colors.white,
          child: ListView(
            controller: scrollController,
            children: const [Text('SHEET'), Text('ITEM1'), Text('ITEM2')],
          ),
        ),
      ),
    );

    expect(find.text('SHEET'), findsOneWidget);

    // Tap in the top space above the 70%-tall sheet — the barrier area.
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();

    expect(find.text('SHEET'), findsNothing, reason: 'tap outside the sheet should dismiss it');
  });

  testWidgets('plain Container sheet (quickview/book-link style) dismisses on barrier tap', (tester) async {
    await openSheet(
      tester,
      Container(
        height: 400,
        color: Colors.white,
        child: const Text('PLAIN'),
      ),
    );

    expect(find.text('PLAIN'), findsOneWidget);

    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();

    expect(find.text('PLAIN'), findsNothing, reason: 'plain modal sheets already dismiss on barrier tap');
  });

  testWidgets('dragging the expand:false sheet still resizes it', (tester) async {
    await openSheet(
      tester,
      DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.25,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          color: Colors.white,
          child: ListView(
            controller: scrollController,
            children: const [Text('DRAGME'), Text('ITEM1'), Text('ITEM2')],
          ),
        ),
      ),
    );

    final before = tester.getSize(find.byType(DraggableScrollableSheet)).height;
    await tester.drag(find.text('DRAGME'), const Offset(0, -200));
    await tester.pumpAndSettle();
    final after = tester.getSize(find.byType(DraggableScrollableSheet)).height;

    expect(after, greaterThan(before), reason: 'expand:false must keep drag-to-resize working');
  });
}
