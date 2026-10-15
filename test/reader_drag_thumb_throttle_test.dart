/// Dragging the scroll thumb moves the reader at most every 100 ms. Each jump
/// builds a fresh screen of paragraphs; jumping on every pointer move (about
/// 330 jumps in a 3 s drag of Pācity-y) put the worst 10% of frames at
/// 26–28 ms on a Pixel 8 Pro. The thumb itself still follows every move, the
/// reader catches up when the finger rests, and the release shows the exact
/// paragraph under the thumb.
library;

import 'package:epitaka/features/reader/providers/reader_provider.dart';
import 'package:epitaka/features/reader/widgets/reader_drag_thumb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class _RecordingController extends ItemScrollController {
  final jumps = <int>[];

  @override
  void jumpTo({required int index, double alignment = 0}) => jumps.add(index);
}

const _paragraphs = 3000;
const _trackHeight = 632.0; // 600 px of thumb travel plus the 32 px thumb

Widget _app(_RecordingController controller, int paragraphs) => MaterialApp(
  home: Align(
    alignment: Alignment.topRight,
    child: SizedBox(
      width: 40,
      height: _trackHeight,
      child: ReaderDragThumb(
        readerState: ReaderDataState(
          bookId: 'b1',
          isLoaded: true,
          paragraphs: [
            for (var p = 1; p <= paragraphs; p++) ParagraphData(paraId: p),
          ],
        ),
        itemScrollController: controller,
      ),
    ),
  ),
);

Future<_RecordingController> _pump(WidgetTester tester) async {
  final controller = _RecordingController();
  await tester.pumpWidget(_app(controller, _paragraphs));
  return controller;
}

void main() {
  testWidgets('a drag jumps at most every 100 ms and ends on the thumb', (
    tester,
  ) async {
    final controller = await _pump(tester);
    final topRight = tester.getTopRight(find.byType(ReaderDragThumb));
    final gesture = await tester.startGesture(topRight + const Offset(-6, 16));

    // 30 moves of 10 px, one per 16 ms frame: about 480 ms of dragging.
    for (var i = 0; i < 30; i++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller.jumps.length, inInclusiveRange(4, 7));

    // A resting finger: the reader catches up without a release.
    final beforeRest = controller.jumps.length;
    await tester.pump(const Duration(milliseconds: 150));
    expect(controller.jumps.length, beforeRest + 1);
    final restIndex = controller.jumps.last;

    // The first move jumps at once and starts the interval; the second
    // lands inside it, so only the release can show it.
    await gesture.moveBy(const Offset(0, 10));
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.jumps.last, greaterThan(restIndex));
    final inInterval = controller.jumps.last;
    await gesture.moveBy(const Offset(0, 40));
    await gesture.up();
    await tester.pump();
    // The release jumps to the paragraph under the thumb at once. The drag
    // begins once the finger passes the touch slop, so the thumb ends about
    // 370 of its 600 px down: paragraph index 1848, as this gesture measured.
    expect(controller.jumps.last, 1848);
    expect(inInterval, lessThan(1848));
    final afterRelease = controller.jumps.length;
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.jumps.length, afterRelease, reason: 'no late jump');
  });

  testWidgets('a book that reloads mid-drag gets no late jump', (tester) async {
    final controller = await _pump(tester);
    final topRight = tester.getTopRight(find.byType(ReaderDragThumb));
    final gesture = await tester.startGesture(topRight + const Offset(-6, 16));
    await gesture.moveBy(const Offset(0, 10));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(0, 10));
    final jumps = controller.jumps.length;

    // The book reloads with one paragraph: the thumb hides and its drag
    // recognizer goes without an end callback.
    await tester.pumpWidget(_app(controller, 1));
    await tester.pump(const Duration(milliseconds: 150));
    expect(controller.jumps.length, jumps);
    await gesture.up();
  });
}
