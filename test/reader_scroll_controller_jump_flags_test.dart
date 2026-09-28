/// Regression test for the reader's collapsible app bar / floating bottom
/// toolbar getting stuck hidden (reported on Android as "bottombar is off
/// below the bottom screen").
///
/// The show/hide state (`_appBarCollapsed`) is driven by finger scrolls in
/// [ReaderScrollController.onScrollOffsetChanged], which ignores all scroll
/// input while [ReaderScrollController.suppressAppBarScroll] /
/// [ReaderScrollController.isInitialJumpPending] hold. Those flags are
/// ref-counted around every programmatic [ReaderScrollController.jumpToParagraph]
/// via begin/endControlledScroll — so any jump exit that skips the matching
/// end wedges the flags forever: the app bar can never re-expand and the
/// bottom toolbar (AnimatedPositioned below the Stack when collapsed) stays
/// stuck below the screen.
///
/// This test drives two overlapping jumps where the first is superseded while
/// waiting for the book to load, and asserts the flags are released.
library;

import 'package:epitaka/features/reader/providers/reader_provider.dart';
import 'package:epitaka/features/reader/providers/reader_scroll_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Never loads: [waitUntilLoaded] completes immediately while the state stays
/// not-loaded with no paragraphs, so every jump takes the wait path and then
/// the superseded / not-found exits. (The super constructor's own [_loadBook]
/// fails without a database in tests and is caught internally.)
class _NeverLoadingReaderDataNotifier extends ReaderDataNotifier {
  _NeverLoadingReaderDataNotifier(super.ref, super.bookId);

  @override
  Future<void> waitUntilLoaded() async {}
}

void main() {
  testWidgets('superseded jump releases the app-bar suppress flags', (
    tester,
  ) async {
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readerDataProvider.overrideWith(
            (r, bookId) => _NeverLoadingReaderDataNotifier(r, bookId),
          ),
        ],
        child: Consumer(
          builder: (context, r, _) {
            ref = r;
            return const SizedBox();
          },
        ),
      ),
    );

    final appBarCollapsed = ValueNotifier<bool>(false);
    final scroll = ReaderScrollController(
      ref: ref,
      isMounted: () => true,
      isPhone: () => true,
      viewInsetsBottom: () => 0,
      appBarCollapsed: appBarCollapsed,
      onTtsManualScroll: (_, _, _) {},
    );

    // Two overlapping jumps for the same book: the first is superseded by
    // the second while both wait for the book to load.
    final first = scroll.jumpToParagraph('book-b', 111);
    final second = scroll.jumpToParagraph('book-b', 222);
    await Future.wait([first, second]);

    // Without the fix, the superseded jump returns without endControlledScroll
    // and both flags stay stuck — wedging the app bar collapsed and the
    // bottom toolbar below the screen.
    expect(scroll.suppressAppBarScroll, isFalse);
    expect(scroll.isInitialJumpPending, isFalse);

    appBarCollapsed.dispose();
    scroll.dispose();
  });
}
