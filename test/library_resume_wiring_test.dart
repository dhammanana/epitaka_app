/// Wiring test: the real [LibraryScreen] calls `resumeLastBook` on its first
/// frame. On Linux `PlatformInfo.isDesktop` is true, so the call takes the
/// desktop skip — the only thing this test can prove here is that the call
/// site runs (`resumeAttemptedProvider` becomes true) and nothing opens
/// (location stays `/`, no reader tab). The phone path is proven by the
/// tests in `resume_last_book_test.dart` and by the live test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:epitaka/core/database/app_database.dart';
import 'package:epitaka/core/providers/app_db_provider.dart';
import 'package:epitaka/core/providers/books_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/library/screens/library_screen.dart';
import 'package:epitaka/features/library/services/resume_last_book.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:epitaka/router/app_router.dart';

ReadingHistoryData _historyRow() => ReadingHistoryData(
      id: 1,
      bookId: 'mula_di_01',
      bookName: 'Sīlakkhandhavagga',
      paraId: 120,
      lineId: 4,
      openedAt: DateTime(2026),
      updatedAt: DateTime(2026),
      readCount: 1,
    );

void main() {
  testWidgets('LibraryScreen runs resumeLastBook on its first frame',
      (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: AppRoutes.library,
          builder: (context, state) => const LibraryScreen(),
        ),
        GoRoute(
          path: AppRoutes.reader,
          builder: (context, state) => const Text('reader'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyProvider.overrideWith((ref) async => [_historyRow()]),
          booksTreeProvider.overrideWith((ref) async => const [
            BookCategory(name: 'Mūla', nikayas: []),
            BookCategory(name: 'Aṭṭhakathā', nikayas: []),
            BookCategory(name: 'Ṭīkā', nikayas: []),
            BookCategory(name: 'Añña', nikayas: []),
          ]),
          settingsProvider.overrideWith((ref) => SettingsNotifier(null)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(size: const Size(400, 800)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Drain the feature-guide welcome timer started by the first frame
    // (_maybeShowFeatureGuideWelcome is not awaited by initState).
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(router.state.matchedLocation, AppRoutes.library);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LibraryScreen).first),
      listen: false,
    );
    expect(container.read(resumeAttemptedProvider), isTrue);
    expect(container.read(readerTabsProvider).isEmpty, isTrue);
  });
}
