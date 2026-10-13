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
    await tester.pumpAndSettle();
    await done;

    expect(controller.offset, greaterThan(8000));
    final top = tester.getTopLeft(find.text('card 30')).dy;
    expect(top, lessThan(100));
    expect(top, greaterThanOrEqualTo(0));
  });

  testWidgets('a card already on screen is reached', (tester) async {
    await start(tester);
    final done = anchors.jumpTo('card_1', controller);
    await tester.pumpAndSettle();
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
}
