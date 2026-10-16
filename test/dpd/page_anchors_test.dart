import 'package:epitaka/features/dictionary/widgets/page_anchors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A lazy list like the panel's: 40 cards of 300 px in a 600 px window. A
/// card outside the window has no widget until the list scrolls near it.
Widget page(PageAnchors anchors, ScrollController controller) => MaterialApp(
  home: Scaffold(
    body: ListView(
      controller: controller,
      children: [
        for (var i = 0; i < 40; i++)
          SizedBox(
            key: anchors.keyFor('card_$i'),
            height: 300,
            child: Text('card $i'),
          ),
      ],
    ),
  ),
);

void main() {
  late PageAnchors anchors;
  late ScrollController controller;

  setUp(() {
    anchors = PageAnchors();
    controller = ScrollController();
  });

  tearDown(() => controller.dispose());

  // The jump steps down the list a frame at a time, then keeps checking the
  // card for two seconds, on a timer that pumpAndSettle does not advance.
  Future<void> finish(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Keys are made when a widget asks for one; ask for all of them first so
    // the ids exist, as the page does when it builds its list.
    await tester.pumpWidget(page(anchors, controller));
  }

  testWidgets('a card far below the window is reached', (tester) async {
    await start(tester);
    expect(find.text('card 30'), findsNothing);

    final done = anchors.jumpTo('card_30', controller);
    await finish(tester);
    await done;

    expect(controller.offset, greaterThan(8000));
    final top = tester.getTopLeft(find.text('card 30')).dy;
    expect(top, lessThan(100));
    expect(top, greaterThanOrEqualTo(0));
  });

  // The summary can sit below a card; that card is then above the window and
  // has no widget, so stepping down alone never finds it.
  testWidgets('a card far above the window is reached', (tester) async {
    await start(tester);
    controller.jumpTo(10500);
    await tester.pumpAndSettle();
    expect(find.text('card 2'), findsNothing);

    final done = anchors.jumpTo('card_2', controller);
    await finish(tester);
    await done;

    final top = tester.getTopLeft(find.text('card 2')).dy;
    expect(top, lessThan(100));
    expect(top, greaterThanOrEqualTo(0));
  });

  testWidgets('a card already on screen is reached', (tester) async {
    await start(tester);
    final done = anchors.jumpTo('card_1', controller);
    await finish(tester);
    await done;
    expect(tester.getTopLeft(find.text('card 1')).dy, lessThan(100));
  });

  testWidgets('an unknown id does nothing and does not throw', (tester) async {
    await start(tester);
    await anchors.jumpTo('nope', controller);
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    expect(tester.takeException(), isNull);
  });

  // The real cards show a small loading card first and grow when their text
  // arrives, so a card just above the target changes height after the page
  // stopped. The card sits close enough above the target to stay in the tree.
  Widget pageWithLoadingCard(
    PageAnchors anchors,
    ScrollController controller,
    ValueNotifier<bool> loaded,
  ) => MaterialApp(
    home: Scaffold(
      body: ListView(
        controller: controller,
        children: [
          for (var i = 0; i < 3; i++)
            SizedBox(
              key: anchors.keyFor('card_$i'),
              height: 300,
              child: Text('card $i'),
            ),
          ValueListenableBuilder<bool>(
            valueListenable: loaded,
            builder: (context, done, _) =>
                SizedBox(height: done ? 700 : 80, child: const Text('late')),
          ),
          for (var i = 3; i < 10; i++)
            SizedBox(
              key: anchors.keyFor('card_$i'),
              height: 300,
              child: Text('card $i'),
            ),
        ],
      ),
    ),
  );

  Future<void> pumpUntilAt(WidgetTester tester, double offset) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if ((controller.offset - offset).abs() < 1) return;
    }
    fail('never reached $offset, at ${controller.offset}');
  }

  testWidgets('the title stays in view when a card above it grows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final loaded = ValueNotifier(false);
    addTearDown(loaded.dispose);
    await tester.pumpWidget(pageWithLoadingCard(anchors, controller, loaded));

    final done = anchors.jumpTo('card_3', controller);
    // card_3 starts at 3 x 300 + 80 = 980.
    await pumpUntilAt(tester, 980 - kTitleGap);
    loaded.value = true;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await done;

    final top = tester.getTopLeft(find.text('card 3')).dy;
    expect(top, closeTo(kTitleGap, 2));
  });

  testWidgets('a card that loads a second late is still corrected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final loaded = ValueNotifier(false);
    addTearDown(loaded.dispose);
    await tester.pumpWidget(pageWithLoadingCard(anchors, controller, loaded));

    final done = anchors.jumpTo('card_3', controller);
    await pumpUntilAt(tester, 980 - kTitleGap);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    loaded.value = true;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await done;

    expect(tester.getTopLeft(find.text('card 3')).dy, closeTo(kTitleGap, 2));
  });

  testWidgets('a scroll by the user is not undone by the settling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final loaded = ValueNotifier(false);
    addTearDown(loaded.dispose);
    await tester.pumpWidget(pageWithLoadingCard(anchors, controller, loaded));

    final done = anchors.jumpTo('card_3', controller);
    await pumpUntilAt(tester, 980 - kTitleGap);
    // The user scrolls before the first check, and the card then grows.
    controller.jumpTo(500);
    loaded.value = true;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await done;
    expect(controller.offset, 500);
  });
}
