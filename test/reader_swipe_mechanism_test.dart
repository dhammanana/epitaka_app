import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test for the reader's tab-swipe mechanism.
///
/// The reader detects horizontal tab swipes with a passive [Listener]
/// nested INSIDE a [SelectionArea] (see ReaderContentWithSelection), then
/// converts the raw pointer movement into a drag that slides the content
/// and commits a tab switch on release. If the SelectionArea ever swallows
/// the pointer stream — or someone moves the Listener out of the hit-test
/// path — the swipe silently stops working, which surfaced as a bug report
/// ("swipe left/right to change tabs no longer works on mobile").
///
/// This test pins the framework behavior this feature depends on: the inner
/// Listener must receive down/move/up events with the correct horizontal
/// travel for a plain finger drag.
void main() {
  testWidgets(
    'Listener inside SelectionArea receives a horizontal drag',
    (tester) async {
      final events = <String>[];
      Offset? downPos;
      Offset? lastMovePos;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionArea(
              child: Listener(
                onPointerDown: (e) {
                  downPos = e.localPosition;
                  events.add('down');
                },
                onPointerMove: (e) {
                  lastMovePos = e.localPosition;
                  events.add('move');
                },
                onPointerUp: (e) => events.add('up'),
                onPointerCancel: (e) => events.add('cancel'),
                child: ListView.builder(
                  itemCount: 20,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Paragraph $i with some long pali text '
                      'bhagavā sāvatthiṃ anuppatto',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(200, 300));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(-12, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();

      expect(events, contains('down'));
      expect(events, contains('move'));
      expect(events, contains('up'));
      expect(events, isNot(contains('cancel')));
      expect(downPos, isNotNull);
      expect(lastMovePos, isNotNull);
      expect(
        lastMovePos!.dx - downPos!.dx,
        lessThan(-100),
        reason: 'the inner Listener must see ~-120px of horizontal travel',
      );
    },
  );
}
