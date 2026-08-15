// Regression: opening a book must never stack a second /reader route.
//
// Previously every "open book" entry point did `context.push('/reader')`
// unconditionally, so once a book was opened from a screen that is itself
// pushed on top of the reader (/search, /annotations, /ai-qa, /dictionary),
// the back stack held TWO reader screens — reaching the library then took
// several Back presses, one of them just showing the same book again.
//
// [openReaderRoute] now pops back to an existing /reader instead of
// pushing a duplicate. These tests drive the real helper against a minimal
// router and assert the stack shape in every case.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../lib/shared/utils/app_navigation.dart';

class _LibraryPage extends StatelessWidget {
  const _LibraryPage();
  @override
  Widget build(BuildContext context) => const Text('library-page');
}

class _ReaderPage extends StatelessWidget {
  const _ReaderPage();
  @override
  Widget build(BuildContext context) => const Text('reader-page');
}

class _SearchPage extends StatelessWidget {
  const _SearchPage();
  @override
  Widget build(BuildContext context) => const Text('search-page');
}

void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const _LibraryPage()),
        GoRoute(path: '/reader', builder: (_, __) => const _ReaderPage()),
        GoRoute(path: '/search', builder: (_, __) => const _SearchPage()),
      ],
    );
  });

  List<String> stack() => router.routerDelegate.currentConfiguration.matches
      .map((m) => m.matchedLocation)
      .toList();

  Future<void> pump(WidgetTester tester) async {
    // Phone-sized so ResponsiveBreakpoint.isDesktop is false — the helper
    // only pushes/pops on mobile (desktop opens books in the sidebar).
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('pushes /reader when it is not in the stack yet', (tester) async {
    await pump(tester);

    // From the library, opening a book pushes /reader on top so a single
    // Back returns to the library.
    openReaderRoute(tester.element(find.byType(_LibraryPage)));
    await tester.pumpAndSettle();

    expect(stack(), ['/', '/reader']);
    expect(find.text('reader-page'), findsOneWidget);
  });

  testWidgets('pops back to an existing /reader instead of stacking a '
      'duplicate', (tester) async {
    await pump(tester);

    // Stack: [/reader, /search] — exactly like opening global search from
    // the reader and tapping a result.
    router.go('/reader');
    await tester.pumpAndSettle();
    router.push('/search');
    await tester.pumpAndSettle();
    expect(stack(), ['/reader', '/search']);

    openReaderRoute(tester.element(find.byType(_SearchPage)));
    await tester.pumpAndSettle();

    // THE regression: the search screen is popped back to the single
    // reader — no second /reader was pushed.
    expect(stack(), ['/reader']);
    expect(find.text('search-page'), findsNothing);
    expect(find.text('reader-page'), findsOneWidget);
  });

  testWidgets('does nothing when already on /reader', (tester) async {
    await pump(tester);

    router.go('/reader');
    await tester.pumpAndSettle();

    openReaderRoute(tester.element(find.byType(_ReaderPage)));
    await tester.pumpAndSettle();

    expect(stack(), ['/reader']);
  });
}
