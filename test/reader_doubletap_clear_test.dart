import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the double-tap → dictionary flow:
///
/// 1. The word selection (its highlight pin) that SelectionArea creates on
///    the opening double-tap must never remain behind — neither over the
///    sheet nor after it closes. The reader clears it synchronously in
///    `_onWordLookup` and re-suppresses it (clear + hideToolbar +
///    ContextMenuController.removeAny) on every frame for ~250ms while the
///    sheet is open — the framework's tap-UP can land many frames after the
///    lookup and re-creates the selection AND its toolbar (in the root
///    overlay, so it survives the sheet and reappears with the real menu
///    afterwards). It also drops the cached selection state.
/// 2. The context menu is suppressed while a sheet is open.
/// 3. Scrolling invalidates the pending double-tap state regardless of any
///    lingering selection — so closing the dictionary and scrolling can
///    never be misread as a double-tap that opens the dictionary for a
///    random word.
///
/// This harness mirrors the reader's wiring (passive [Listener] inside a
/// [SelectionArea], own double-tap detector, modal sheet pushed on the
/// second tap) plus those fixes. NOTE: in widget tests the framework reports
/// an empty plainText for the double-tap word selection, so the
/// onSelectionChanged guard cannot be exercised here; the menu suppression
/// and the tap-state invalidation are the observable, tested behaviors.
void main() {
  testWidgets('baseline: a double-tap shows the context menu', (tester) async {
    // Proves the double-tap gesture in this harness really produces a word
    // selection + context menu when no sheet interferes (i.e. the harness
    // exercises the same framework path as the reader).
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SelectionArea(
              contextMenuBuilder: (context, state) =>
                  const Text('CTX-MENU', textDirection: TextDirection.ltr),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'bhagavā etad avoca sāvatthiṃ anuppatto '
                  'dhammaṃ deseti bhikkhūnaṃ',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await _doubleTapAt(tester, const Offset(200, 300));
    await tester.pumpAndSettle();
    expect(find.text('CTX-MENU'), findsOneWidget,
        reason: 'a real double-tap selects the word and shows the context menu');
  });

  testWidgets('double-tap lookup never shows the context menu over the sheet',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _DoubleTapHarness(),
        ),
      ),
    );

    final sheetFinder = find.text('DICT SHEET', skipOffstage: false);

    // Double-tap: sheet opens, and the leftover context menu is suppressed
    // (the reader's _buildCopyContextMenu returns an empty widget while the
    // sheet-open counter is > 0).
    await _doubleTapAt(tester, const Offset(200, 300));
    await tester.pumpAndSettle();
    final state = tester.state<_DoubleTapHarnessState>(
      find.byType(_DoubleTapHarness),
    );
    expect(state.doubleTapCount, 1, reason: 'double-tap was detected');
    expect(state.sheetOpen, 1, reason: 'sheet opened');
    expect(sheetFinder, findsOneWidget, reason: 'sheet opens');
    expect(find.text('CTX-MENU'), findsNothing,
        reason: 'the context menu must never cover the sheet');
  });

  testWidgets('no toolbar after closing the sheet — two consecutive flows',
      (tester) async {
    // Regression for "close the dictionary → the selected text and the
    // context menu are still there": SelectionArea shows its double-tap
    // toolbar in the root overlay on the second tap's pointer-UP; once the
    // sheet closes that toolbar rebuilds with the real menu. The harness
    // mirrors the reader's suppression (clear + hideToolbar post-frames),
    // so the toolbar must never be visible after either sheet closes, and
    // the second double-tap must still register (the leftover toolbar used
    // to swallow it).
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _DoubleTapHarness(),
        ),
      ),
    );

    // Flow 1: double-tap opens the sheet, then close it.
    await _doubleTapAt(tester, const Offset(200, 300));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('CTX-MENU', skipOffstage: false), findsNothing,
        reason: 'no toolbar may reappear after the first sheet closes');

    // Flow 2: double-tap again at the same spot and close again.
    await _doubleTapAt(tester, const Offset(200, 300));
    await tester.pumpAndSettle();
    final state = tester.state<_DoubleTapHarnessState>(
      find.byType(_DoubleTapHarness),
    );
    expect(state.doubleTapCount, 2,
        reason: 'the second double-tap must still be detected');

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('CTX-MENU', skipOffstage: false), findsNothing,
        reason: 'no toolbar may reappear after the second sheet closes');
  });

  testWidgets('a scroll invalidates the pending double-tap state',
      (tester) async {
    // Regression for "close the dictionary, scroll, and the scroll becomes a
    // double-tap that opens the dictionary for a new word". A scroll must
    // clear the cached tap-down so the NEXT pointer-down (a second fling, or
    // a tap right after a scroll) can never be misread as the second tap of
    // a double-tap. Mirrors the reader's [_handlePointerMoveForTabSwipe]
    // clearing, which runs before any selection-based early return.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _ScrollInvalidatesTapStateHarness(),
        ),
      ),
    );

    // Scroll: pointer down, move well beyond tap slop, lift.
    final g = await tester.startGesture(const Offset(200, 300));
    await tester.pump();
    await g.moveBy(const Offset(0, 120));
    await tester.pump();
    await g.up();
    await tester.pump();

    // A quick tap right where the scroll started — within the double-tap
    // time window and position slop of the scroll's pointer-down. Without
    // the invalidation this would be detected as a double-tap.
    await tester.tapAt(const Offset(200, 300));
    await tester.pump();

    final state = tester.state<_ScrollInvalidatesTapStateHarnessState>(
      find.byType(_ScrollInvalidatesTapStateHarness),
    );
    expect(state.lookupCount, 0,
        reason: 'scrolling must invalidate the pending double-tap state');
  });
}

/// Mirrors the reader's double-tap detector + the fixed
/// [_handlePointerMoveForTabSwipe] clearing: movement invalidates the
/// pending double-tap state.
class _ScrollInvalidatesTapStateHarness extends StatefulWidget {
  const _ScrollInvalidatesTapStateHarness();

  @override
  State<_ScrollInvalidatesTapStateHarness>
  createState() => _ScrollInvalidatesTapStateHarnessState();
}

class _ScrollInvalidatesTapStateHarnessState
    extends State<_ScrollInvalidatesTapStateHarness> {
  int lookupCount = 0;

  // ── Mirror of reader_screen.dart ────────────────────────────────────
  int? _lastTapDownTime;
  Offset? _lastTapDownPosition;

  void _onPointerDown(PointerDownEvent event) {
    final now = event.timeStamp.inMilliseconds;
    final lastTime = _lastTapDownTime;
    final lastPos = _lastTapDownPosition;
    _lastTapDownTime = now;
    _lastTapDownPosition = event.localPosition;

    if (lastTime != null && lastPos != null) {
      final dt = now - lastTime;
      final dist = (event.localPosition - lastPos).distance;
      const kDoubleTapTime = 400;
      const kDoubleTapSlop = 40.0;
      if (dt >= 0 && dt <= kDoubleTapTime && dist <= kDoubleTapSlop) {
        _lastTapDownTime = null;
        _lastTapDownPosition = null;
        lookupCount++;
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    // Mirror of the reader's fixed handler: invalidate pending double-tap
    // state on any real movement, before any selection-state early return.
    final tapDownPos = _lastTapDownPosition;
    if (tapDownPos != null &&
        (event.localPosition - tapDownPos).distance > 10.0) {
      _lastTapDownTime = null;
      _lastTapDownPosition = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'bhagavā etad avoca sāvatthiṃ anuppatto',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}

/// Two taps at [pos] ~90ms apart, the second held past kPressTimeout (100ms)
/// so the recognizer's delayed onTapDown (word selection) actually fires.
Future<void> _doubleTapAt(WidgetTester tester, Offset pos) async {
  final g1 = await tester.startGesture(pos);
  await tester.pump();
  await g1.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 90));
  final g2 = await tester.startGesture(pos);
  await tester.pump(const Duration(milliseconds: 150));
  await g2.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

class _DoubleTapHarness extends StatefulWidget {
  const _DoubleTapHarness();

  @override
  State<_DoubleTapHarness> createState() => _DoubleTapHarnessState();
}

class _DoubleTapHarnessState extends State<_DoubleTapHarness> {
  final GlobalKey<SelectableRegionState> _regionKey = GlobalKey();

  /// Mirror of [dictionarySheetOpenProvider].
  int sheetOpen = 0;

  int doubleTapCount = 0;

  // ── Mirror of reader_screen.dart ────────────────────────────────────
  int? _lastTapDownTime;
  Offset? _lastTapDownPosition;

  void _onPointerDown(PointerDownEvent event) {
    final now = event.timeStamp.inMilliseconds;
    final lastTime = _lastTapDownTime;
    final lastPos = _lastTapDownPosition;
    _lastTapDownTime = now;
    _lastTapDownPosition = event.localPosition;

    if (lastTime != null && lastPos != null) {
      final dt = now - lastTime;
      final dist = (event.localPosition - lastPos).distance;
      const kDoubleTapTime = 400;
      const kDoubleTapSlop = 40.0;
      if (dt >= 0 && dt <= kDoubleTapTime && dist <= kDoubleTapSlop) {
        _lastTapDownTime = null;
        _lastTapDownPosition = null;
        _onWordLookup(event.position);
      }
    }
  }

  void _onWordLookup(Offset globalPosition) {
    doubleTapCount++;
    // Mirror of the reader: SelectionArea actually lands its word selection
    // on the second tap's pointer-DOWN BEFORE this runs (the framework's
    // recognizer dispatches first), so the counter below is a backstop, not
    // a guarantee — the clears are what remove the pin.
    sheetOpen++;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const SizedBox(
        height: 300,
        child: Center(child: Text('DICT SHEET')),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => sheetOpen--);
      // Mirror of the reader's sheet-close cleanup: anything the framework
      // left behind after the suppression window is dismissed now.
      final region = _regionKey.currentState;
      region?.clearSelection();
      ContextMenuController.removeAny();
    });
    // …then clear any pre-existing selection, and for the next ~250ms while
    // the sheet is open re-clear, hide handles, and dismiss the global
    // context menu (mirror of the reader's post-frame suppression):
    // SelectionArea shows its double-tap toolbar on the second tap's
    // pointer-UP, in the ROOT overlay — it would survive the sheet and
    // reappear with the real menu afterwards. The suppression re-schedules
    // itself each frame because that tap-up can land many frames later.
    _regionKey.currentState?.clearSelection();
    final suppressUntil =
        DateTime.now().add(const Duration(milliseconds: 250));
    void suppressLeftoverSelection() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (sheetOpen <= 0) return;
        final region = _regionKey.currentState;
        region?.clearSelection();
        region?.hideToolbar();
        ContextMenuController.removeAny();
        if (DateTime.now().isBefore(suppressUntil)) {
          suppressLeftoverSelection();
        }
      });
    }

    suppressLeftoverSelection();
  }

  /// Mirror of [_handleSelectionChanged]'s guard: any selection reported
  /// while a sheet is open is a leftover of the opening double-tap — clear it.
  void _onSelectionChanged(SelectedContent? selection) {
    if (selection != null && sheetOpen > 0) {
      _regionKey.currentState?.clearSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SelectionArea(
        key: _regionKey,
        onSelectionChanged: _onSelectionChanged,
        // Mirror of the reader's _buildCopyContextMenu: never show the
        // context menu while a sheet is open.
        contextMenuBuilder: (context, state) => sheetOpen > 0
            ? const SizedBox.shrink()
            : const Text('CTX-MENU', textDirection: TextDirection.ltr),
        child: Listener(
          onPointerDown: _onPointerDown,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'bhagavā etad avoca sāvatthiṃ anuppatto '
              'dhammaṃ deseti bhikkhūnaṃ',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ),
      ),
    );
  }
}
