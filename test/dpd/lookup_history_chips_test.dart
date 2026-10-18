// The recent-word chips run oldest to newest, left to right, start at the
// newest end, and mark and reveal the word on screen.
library;

import 'package:epitaka/features/dictionary/widgets/lookup_history_chips.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Oldest first, as the history keeps them: w39 is the newest.
  final words = [for (var i = 0; i < 40; i++) 'w$i'];

  Widget app(int current, {List<String>? list, ValueChanged<String>? onTap}) {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 48,
          child: LookupHistoryChips(
            words: list ?? words,
            currentIndex: current,
            colors: scheme,
            labelStyle: const TextStyle(fontSize: 12),
            onTap: onTap ?? (_) {},
          ),
        ),
      ),
    );
  }

  Finder chip(String w) => find.widgetWithText(ActionChip, w);

  testWidgets('oldest on the left, newest on the right', (tester) async {
    await tester.pumpWidget(app(-1, list: ['a', 'b', 'c']));
    final a = tester.getTopLeft(chip('a')).dx;
    final b = tester.getTopLeft(chip('b')).dx;
    final c = tester.getTopLeft(chip('c')).dx;
    expect(a, lessThan(b));
    expect(b, lessThan(c));
  });

  testWidgets('few chips sit at the right edge, not in the middle', (
    tester,
  ) async {
    await tester.pumpWidget(app(-1, list: ['a', 'b', 'c']));
    final right = tester.getRect(chip('c')).right;
    // The row is 300 wide; the newest chip ends within one gap of the edge.
    expect(right, greaterThan(300 - 8));
    expect(tester.getRect(chip('a')).left, greaterThan(0));
  });

  testWidgets('the row starts at the newest end', (tester) async {
    await tester.pumpWidget(app(-1));
    expect(tester.getRect(chip('w39')).right, lessThanOrEqualTo(300));
    expect(tester.getRect(chip('w39')).left, greaterThanOrEqualTo(0));
    expect(chip('w0').hitTestable(), findsNothing, reason: 'the oldest is off screen');
  });

  testWidgets('the current chip uses the accent colour, and no border', (
    tester,
  ) async {
    await tester.pumpWidget(app(38));
    final accent = ColorScheme.fromSeed(seedColor: Colors.teal).primary;
    Color? fill(String w) => tester.widget<ActionChip>(chip(w)).backgroundColor;
    expect(fill('w38'), accent);
    expect(fill('w39'), isNot(accent));
    expect(fill('w39'), fill('w37'));
    expect(tester.widget<ActionChip>(chip('w38')).side, BorderSide.none);
  });

  testWidgets('a current word that moves out of view is scrolled into view', (
    tester,
  ) async {
    await tester.pumpWidget(app(39));
    expect(chip('w0').hitTestable(), findsNothing);

    await tester.pumpWidget(app(0));
    await tester.pumpAndSettle();
    final r = tester.getRect(chip('w0'));
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.right, lessThanOrEqualTo(300));
  });

  // At the history's cap a new word drops the oldest, so the newest keeps the
  // same position; the row must still come back to show it.
  testWidgets('at the cap, a new newest word is scrolled into view', (
    tester,
  ) async {
    await tester.pumpWidget(app(39));
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(tester.getCenter(chip('w38'))));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -2000)));
    await tester.pump();
    expect(chip('w39').hitTestable(), findsNothing);

    final shifted = [for (var i = 1; i <= 40; i++) 'w$i'];
    await tester.pumpWidget(app(39, list: shifted));
    await tester.pumpAndSettle();
    final r = tester.getRect(chip('w40'));
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.right, lessThanOrEqualTo(300));
  });

  testWidgets('a tap hands over the word', (tester) async {
    String? tapped;
    await tester.pumpWidget(app(-1, onTap: (w) => tapped = w));
    await tester.tap(chip('w39'));
    expect(tapped, 'w39');
  });

  testWidgets('the mouse wheel scrolls the row sideways', (tester) async {
    await tester.pumpWidget(app(-1));
    final newest = tester.getRect(chip('w39')).left;
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    final spot = tester.getCenter(chip('w38'));
    await tester.sendEventToBinding(mouse.hover(spot));
    // Wheel up: toward the older chips, so the row moves right.
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -200)));
    await tester.pump();
    expect(tester.getRect(chip('w39')).left, greaterThan(newest + 100));

    // Wheel down comes back toward the newest.
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 200)));
    await tester.pump();
    expect(tester.getRect(chip('w39')).left, newest);
  });

  testWidgets('the wheel stops at the ends', (tester) async {
    await tester.pumpWidget(app(-1));
    final newest = tester.getRect(chip('w39')).left;
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(tester.getCenter(chip('w38'))));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 500)));
    await tester.pump();
    expect(tester.getRect(chip('w39')).left, newest, reason: 'no overscroll');
  });

  testWidgets('a swipe with a finger scrolls the row', (tester) async {
    await tester.pumpWidget(app(-1));
    final newest = tester.getRect(chip('w39')).left;
    await tester.drag(chip('w38'), const Offset(150, 0));
    await tester.pump();
    expect(tester.getRect(chip('w39')).left, greaterThan(newest + 100));
  });
}
