import 'package:epitaka/shared/widgets/history_nav.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

KeyEvent down(LogicalKeyboardKey k) => KeyDownEvent(
  physicalKey: PhysicalKeyboardKey.keyA,
  logicalKey: k,
  timeStamp: Duration.zero,
);

KeyEvent repeat(LogicalKeyboardKey k) => KeyRepeatEvent(
  physicalKey: PhysicalKeyboardKey.keyA,
  logicalKey: k,
  timeStamp: Duration.zero,
);

void main() {
  late HistoryNav nav;
  late List<int> activated;
  late int changes;

  setUp(() {
    activated = [];
    changes = 0;
    nav = HistoryNav(onChanged: () => changes++, onActivate: activated.add);
  });

  const downKey = LogicalKeyboardKey.arrowDown;
  const upKey = LogicalKeyboardKey.arrowUp;

  test('Down twice gives index 1', () {
    nav.handle(down(downKey), 3);
    nav.handle(down(downKey), 3);
    expect(nav.index, 1);
  });

  test('Down past the end stays on the last row', () {
    for (var i = 0; i < 6; i++) {
      nav.handle(down(downKey), 3);
    }
    expect(nav.index, 2);
  });

  test('Up from 1 gives 0, Up from 0 gives -1 and is handled', () {
    nav.handle(down(downKey), 3);
    nav.handle(down(downKey), 3);
    expect(nav.handle(down(upKey), 3), KeyEventResult.handled);
    expect(nav.index, 0);
    expect(nav.handle(down(upKey), 3), KeyEventResult.handled);
    expect(nav.index, -1);
  });

  test('Up and Enter at -1 are ignored', () {
    expect(nav.handle(down(upKey), 3), KeyEventResult.ignored);
    expect(nav.handle(down(LogicalKeyboardKey.enter), 3),
        KeyEventResult.ignored);
    expect(activated, isEmpty);
  });

  test('Enter at 1 activates row 1 once, a repeat does nothing', () {
    nav.handle(down(downKey), 3);
    nav.handle(down(downKey), 3);
    expect(nav.handle(down(LogicalKeyboardKey.enter), 3),
        KeyEventResult.handled);
    expect(nav.handle(repeat(LogicalKeyboardKey.enter), 3),
        KeyEventResult.handled);
    expect(activated, [1]);
  });

  test('count 0 ignores everything', () {
    expect(nav.handle(down(downKey), 0), KeyEventResult.ignored);
    expect(nav.index, -1);
  });

  test('a changed row count drops the highlight, an equal one keeps it', () {
    nav.clamp(3);
    nav.handle(down(downKey), 3);
    nav.handle(down(downKey), 3);
    nav.clamp(3);
    expect(nav.index, 1);
    // A row was deleted: the rows moved under the highlight.
    nav.clamp(2);
    expect(nav.index, -1);
  });

  test('reset clears the highlight and tells the host', () {
    nav.handle(down(downKey), 3);
    changes = 0;
    nav.reset();
    expect(nav.index, -1);
    expect(changes, 1);
  });
}
