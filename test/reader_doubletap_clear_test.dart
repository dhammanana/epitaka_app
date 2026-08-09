import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test for "the first double-tap clears the SelectionArea
/// selection after the dictionary sheet opens, but the second time onward
/// the selection (and its context menu) stays and covers the sheet."
///
/// The reader pushes the modal dictionary sheet on the second tap's
/// pointer-DOWN, but SelectionArea creates its word selection on that same
/// gesture AFTER the push (onTapDown fires after the ~100ms press deadline)
/// and shows its context menu on the pointer-UP — over the sheet. The reader
/// fixes this two ways:
///
///  1. `_handleSelectionChanged` clears any selection reported while a sheet
///     is open (event-driven — not timing-sensitive like the old
///     pointer-up/post-frame flag, which missed the second and later
///     double-taps).
///  2. `_buildCopyContextMenu` returns an empty widget while a sheet is open,
///     so the context menu can never render over the sheet even if a
///     selection somehow lingers.
///
/// This harness mirrors the reader's wiring (passive [Listener] inside a
/// [SelectionArea], own double-tap detector, modal sheet pushed on the
/// second tap) plus both fixes. NOTE: in widget tests the framework reports
/// an empty plainText for the double-tap word selection, so the
/// onSelectionChanged guard cannot be exercised here; the menu suppression is
/// the observable, tested behavior.
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
    // Dictionary receives the word FIRST (the counter goes up and the sheet
    // opens before any selection can exist)…
    sheetOpen++;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const SizedBox(
        height: 300,
        child: Center(child: Text('DICT SHEET')),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => sheetOpen--);
    });
    // …then clear any pre-existing selection…
    _regionKey.currentState?.clearSelection();
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
