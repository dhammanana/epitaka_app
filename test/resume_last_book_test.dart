/// Regression tests for `resumeLastBook` — on a phone the library reopens
/// the book the user read last, at the saved paragraph, once per process.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:epitaka/core/database/app_database.dart';
import 'package:epitaka/core/providers/app_db_provider.dart';
import 'package:epitaka/features/deep_links/deep_link_service.dart';
import 'package:epitaka/features/library/services/resume_last_book.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:epitaka/router/app_router.dart';

ReadingHistoryData _row({
  String bookId = 'mula_di_01',
  String bookName = 'Sīlakkhandhavaga',
  int paraId = 120,
  int? lineId = 4,
  DateTime? updatedAt,
}) =>
    ReadingHistoryData(
      id: 1,
      bookId: bookId,
      bookName: bookName,
      paraId: paraId,
      lineId: lineId,
      openedAt: DateTime(2026),
      updatedAt: updatedAt ?? DateTime(2026),
      readCount: 1,
    );

class Harness {
  final BuildContext context;
  final WidgetRef ref;
  final GoRouter router;
  Harness(this.context, this.ref, this.router);
}

/// Pumps a phone-sized app with a two-route router (`/` host, `/reader`).
/// The `/` route's `Consumer` captures its context and ref; tests call
/// `resumeLastBook` themselves. `history()` supplies `historyProvider`.
Future<Harness> pumpApp(WidgetTester tester,
    {required Future<List<ReadingHistoryData>> Function() history}) async {
  BuildContext? hostContext;
  WidgetRef? hostRef;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: AppRoutes.library,
        builder: (context, state) => Consumer(
          builder: (viewContext, viewRef, _) {
            hostContext = viewContext;
            hostRef = viewRef;
            return const SizedBox.shrink();
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.reader,
        builder: (context, state) => const Text('reader'),
      ),
    ],
  );
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        historyProvider.overrideWith((ref) async => history()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(size: const Size(400, 800)),
          child: child!,
        ),
      ),
    ),
  );
  // go_router builds the initial route on a scheduleMicrotask chain, so pump
  // until the host route's builder has assigned hostContext and hostRef.
  for (var i = 0; hostContext == null || hostRef == null; i++) {
    if (i > 100) {
      expect(true, isFalse, reason: 'the / host route never built');
      return Harness(
          hostContext as BuildContext, hostRef as WidgetRef, router);
    }
    await tester.pump(const Duration(milliseconds: 1));
  }
  return Harness(hostContext!, hostRef!, router);
}

/// `resumeLastBook` with the launch-link check stubbed: the real one asks the
/// app_links plugin, which never answers in a widget test.
Future<ResumeOutcome> _resume(
  BuildContext context,
  WidgetRef ref, {
  required bool isDesktop,
  Future<bool> Function()? launchedByLink,
}) =>
    resumeLastBook(
      context,
      ref,
      isDesktop: isDesktop,
      launchedByLink: launchedByLink ?? () async => false,
    );

void main() {
  test('a link kept for the screens counts as a launch link', () async {
    addTearDown(DeepLinkService.instance.dispose);
    // No navigator yet, so the service keeps the link.
    DeepLinkService.instance.handleUri(Uri.parse('epitaka://search?q=dhamma'));

    expect(await DeepLinkService.instance.hasLaunchLink(), isTrue);
  });

  testWidgets('does not reopen the last book when a link launched the app',
      (tester) async {
    final h = await pumpApp(tester, history: () async => [_row()]);
    final f = _resume(
      h.context,
      h.ref,
      isDesktop: false,
      launchedByLink: () async => true,
    );
    await tester.pump();
    final outcome = await f;
    await tester.pumpAndSettle();

    expect(outcome, ResumeOutcome.launchedByLink);
    expect(h.ref.read(readerTabsProvider).tabs, isEmpty);
    expect(h.router.state.matchedLocation, AppRoutes.library);
  });

  testWidgets('opens the newest history row at its paragraph and line',
      (tester) async {
    final h = await pumpApp(tester, history: () async => [_row()]);
    final f = _resume(h.context, h.ref, isDesktop: false);
    await tester.pump();
    final outcome = await f;
    await tester.pumpAndSettle();

    expect(outcome, ResumeOutcome.opened);
    final tabs = h.ref.read(readerTabsProvider);
    expect(tabs.tabs, hasLength(1));
    expect(tabs.tabs.first.bookId, 'mula_di_01');
    expect(tabs.tabs.first.initialParaId, 120);
    expect(tabs.tabs.first.initialLineId, 4);
    expect(h.router.state.matchedLocation, AppRoutes.reader);
    expect(
      h.router.routerDelegate.currentConfiguration.matches
        .map((m) => m.matchedLocation)
        .toList(),
      [AppRoutes.library, AppRoutes.reader],
    );
    h.router.pop();
    await tester.pump();
    expect(h.router.state.matchedLocation, AppRoutes.library);
  });

  testWidgets('with two rows, the newest (first) row is opened', (tester) async {
    final h = await pumpApp(tester, history: () async => [
      _row(bookId: 'mula_di_01', updatedAt: DateTime(2026, 11, 3)),
      _row(bookId: 'dn_1', bookName: 'Digha Nikaya', updatedAt: DateTime(2026, 1, 1)),
    ]);
    final f = _resume(h.context, h.ref, isDesktop: false);
    await tester.pump();
    final outcome = await f;
    await tester.pumpAndSettle();

    expect(outcome, ResumeOutcome.opened);
    expect(h.ref.read(readerTabsProvider).tabs.first.bookId, 'mula_di_01');
    expect(h.router.state.matchedLocation, AppRoutes.reader);
  });

  testWidgets('empty history stays on the library', (tester) async {
    final h = await pumpApp(tester, history: () async => <ReadingHistoryData>[]);
    final f = _resume(h.context, h.ref, isDesktop: false);
    await tester.pump();
    final outcome = await f;

    expect(outcome, ResumeOutcome.historyEmpty);
    expect(h.router.state.matchedLocation, AppRoutes.library);
    expect(h.ref.read(readerTabsProvider).isEmpty, isTrue);
  });

  testWidgets('a history future still loading is not empty', (tester) async {
    final completer = Completer<List<ReadingHistoryData>>();
    final h = await pumpApp(tester, history: () => completer.future);
    final f = _resume(h.context, h.ref, isDesktop: false);
    await tester.pump();
    completer.complete([_row()]);
    final outcome = await f;
    await tester.pumpAndSettle();

    expect(outcome, ResumeOutcome.opened);
    expect(h.ref.read(readerTabsProvider).tabs.first.bookId, 'mula_di_01');
  });

  testWidgets('a history future that throws is logged, not propagated',
      (tester) async {
    final h = await pumpApp(
        tester, history: () async => throw Exception('database unreadable'));
    final f = _resume(h.context, h.ref, isDesktop: false);
    await tester.pump();
    final outcome = await f;

    expect(outcome, ResumeOutcome.historyError);
    expect(h.router.state.matchedLocation, AppRoutes.library);
    expect(h.ref.read(readerTabsProvider).isEmpty, isTrue);
  });

  testWidgets('an open reader tab before the call blocks the open',
      (tester) async {
    final h = await pumpApp(tester, history: () async => [_row()]);
    h.ref.read(readerTabsProvider.notifier).openTab(const ReaderTabInfo(
      bookId: 'other',
      bookName: 'Other book',
    ));
    final f = _resume(h.context, h.ref, isDesktop: false);
    await tester.pump();
    final outcome = await f;

    expect(outcome, ResumeOutcome.readerBusy);
    expect(
      h.ref.read(readerTabsProvider).tabs.map((t) => t.bookId).toList(),
      ['other'],
    );
    expect(h.router.state.matchedLocation, AppRoutes.library);
  });

  testWidgets('a tab opened while the history is pending wins the race',
      (tester) async {
    final completer = Completer<List<ReadingHistoryData>>();
    final h = await pumpApp(tester, history: () => completer.future);
    final f = _resume(h.context, h.ref, isDesktop: false);
    await tester.pump();
    h.ref.read(readerTabsProvider.notifier).openTab(const ReaderTabInfo(
      bookId: 'other',
      bookName: 'Other book',
    ));
    completer.complete([_row()]);
    final outcome = await f;
    await tester.pump();

    expect(outcome, ResumeOutcome.readerBusy);
    expect(
      h.ref.read(readerTabsProvider).tabs.map((t) => t.bookId).toList(),
      ['other'],
    );
  });

  testWidgets('/reader already in the stack means no second push',
      (tester) async {
    final h = await pumpApp(tester, history: () async => [_row()]);
    h.router.push(AppRoutes.reader);
    await tester.pump();
    expect(
      h.router.routerDelegate.currentConfiguration.matches
        .map((m) => m.matchedLocation)
        .toList(),
      [AppRoutes.library, AppRoutes.reader],
    );
    final f = _resume(h.context, h.ref, isDesktop: false);
    await tester.pump();
    final outcome = await f;
    await tester.pump();

    expect(outcome, ResumeOutcome.readerBusy);
    expect(
      h.router.routerDelegate.currentConfiguration.matches
        .map((m) => m.matchedLocation)
        .toList(),
      [AppRoutes.library, AppRoutes.reader],
    );
  });

  testWidgets('the flag stops a second attempt in the same process',
      (tester) async {
    final h = await pumpApp(tester, history: () async => [_row()]);
    final f1 = _resume(h.context, h.ref, isDesktop: false);
    await tester.pump();
    final outcome1 = await f1;
    await tester.pumpAndSettle();

    expect(outcome1, ResumeOutcome.opened);
    expect(h.ref.read(resumeAttemptedProvider), isTrue);

    final f2 = _resume(h.context, h.ref, isDesktop: false);
    await tester.pump();
    final outcome2 = await f2;

    expect(outcome2, ResumeOutcome.alreadyAttempted);
    expect(h.ref.read(readerTabsProvider).tabs, hasLength(1));
  });

  testWidgets('desktop is skipped and still marks the flag', (tester) async {
    final h = await pumpApp(tester, history: () async => [_row()]);
    final f = _resume(h.context, h.ref, isDesktop: true);
    await tester.pump();
    final outcome = await f;

    expect(outcome, ResumeOutcome.desktop);
    expect(h.ref.read(resumeAttemptedProvider), isTrue);
    expect(h.router.state.matchedLocation, AppRoutes.library);
    expect(h.ref.read(readerTabsProvider).isEmpty, isTrue);
  });

  testWidgets('a disposed host while the future is pending is notMounted',
      (tester) async {
    final completer = Completer<List<ReadingHistoryData>>();
    final h = await pumpApp(tester, history: () => completer.future);
    final f = _resume(h.context, h.ref, isDesktop: false);
    await tester.pump();
    // Keep the same override list so Riverpod doesn't complain about changed
    // overrides; the host context itself is disposed by the swap.
    await tester.pumpWidget(ProviderScope(
      overrides: [
        historyProvider.overrideWith((ref) async => completer.future),
      ],
      child: const MaterialApp(home: SizedBox()),
    ));
    completer.complete([_row()]);
    await tester.pump();
    final outcome = await f;

    expect(outcome, ResumeOutcome.notMounted);
  });
}
