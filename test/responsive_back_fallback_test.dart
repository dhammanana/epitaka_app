// Regression: a desktop window narrowed below the desktop breakpoint falls
// back to the phone UI, and two things must keep working:
//
//   1. The router's `/` → `/reader` redirect must NOT fire while the window
//      is too small for the desktop layout — otherwise the library (the
//      phone-fallback home screen) is unreachable and the reader's back
//      button gets stuck.
//   2. The reader's back button must never pop the root route (which left
//      an empty/black screen); when there is nothing to pop it should open
//      the library instead.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../lib/features/reader/widgets/reader_app_bar.dart';
import '../lib/router/app_router.dart';

void main() {
  group('redirectLibraryToReader', () {
    test('desktop + wide window → reader shell', () {
      expect(
        redirectLibraryToReader(
          isDesktopPlatform: true,
          windowWidth: 1200,
        ),
        isTrue,
      );
      expect(
        redirectLibraryToReader(
          isDesktopPlatform: true,
          windowWidth: 900,
        ),
        isTrue,
      );
    });

    test('desktop + narrow window → library stays reachable', () {
      expect(
        redirectLibraryToReader(
          isDesktopPlatform: true,
          windowWidth: 800,
        ),
        isFalse,
      );
    });

    test('unknown window size keeps the old desktop behaviour', () {
      expect(redirectLibraryToReader(isDesktopPlatform: true), isTrue);
    });

    test('phone platform never redirects', () {
      expect(
        redirectLibraryToReader(isDesktopPlatform: false, windowWidth: 800),
        isFalse,
      );
      expect(
        redirectLibraryToReader(isDesktopPlatform: false, windowWidth: 1200),
        isFalse,
      );
    });
  });

  group('ReaderAppBar back button', () {
    GoRouter makeRouter({required bool readerIsRoot}) {
      return GoRouter(
        initialLocation: readerIsRoot ? '/reader' : '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: Center(child: Text('library-page')),
            ),
          ),
          GoRoute(
            path: '/reader',
            builder: (context, _) => Scaffold(
              body: ReaderAppBar(
                bookId: 'dn1',
                bookName: 'Dīgha Nikāya 1',
                colors: Theme.of(context).colorScheme,
                showCollapsed: false,
                onSettingsTap: () {},
              ),
            ),
          ),
        ],
      );
    }

    Future<GoRouter> pump(WidgetTester tester, {required bool readerIsRoot}) async {
      final router = makeRouter(readerIsRoot: readerIsRoot);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('reader as the ROOT route: back opens the library instead '
        'of popping past the end', (tester) async {
      // Phone-sized window on a desktop OS (the reported small-window
      // fallback) — the reader is the root route with nothing to pop.
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pump(tester, readerIsRoot: true);
      expect(find.byType(ReaderAppBar), findsOneWidget);
      expect(find.text('library-page'), findsNothing);

      // Tapping back must NOT throw or blank the screen — it opens the
      // library (the phone-fallback home).
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('library-page'), findsOneWidget,
          reason: 'the back button on the root reader route must open the '
              'library instead of popping past the end');
      expect(find.byType(ReaderAppBar), findsNothing);
    });

    testWidgets('reader pushed on the stack: back pops to the library '
        '(normal mobile behaviour preserved)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = await pump(tester, readerIsRoot: false);
      expect(find.text('library-page'), findsOneWidget);

      // Open a book from the library (mobile pushes /reader).
      router.push('/reader');
      await tester.pumpAndSettle();
      expect(find.byType(ReaderAppBar), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('library-page'), findsOneWidget);
      expect(find.byType(ReaderAppBar), findsNothing);
    });
  });
}
