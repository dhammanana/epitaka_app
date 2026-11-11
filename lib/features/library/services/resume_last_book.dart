import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/app_db_provider.dart';
import '../../../core/utils/startup_timing.dart';
import '../../../features/deep_links/deep_link_service.dart';
import '../../../features/reader/providers/reader_tabs_provider.dart';
import '../../../router/app_router.dart';
import '../widgets/history_tabs.dart';

/// A provider, not a static field, so each test `ProviderScope` starts clean.
final resumeAttemptedProvider = StateProvider<bool>((ref) => false);

enum ResumeOutcome {
  opened,
  alreadyAttempted,
  desktop,
  readerBusy,
  historyEmpty,
  historyError,
  notMounted,
  launchedByLink,
}

/// Once per process, on a phone, reopen the newest reading-history entry in
/// the reader. The library stays underneath, so Back returns to the book list.
///
/// Takes `isDesktop` as an argument because `PlatformInfo.isDesktop` is always
/// true in tests on Linux; desktop restores its own tabs in `lib/main.dart`.
///
/// Steps run in this exact order; step 1 happens before any `await`:
///
/// 1. If `resumeAttemptedProvider` is already true, return `alreadyAttempted`;
///    otherwise set it true. A later `LibraryScreen` in the same process
///    therefore does nothing — `ReaderScreen` draws a full `LibraryScreen`
///    when it has no tabs, and the reader's Back button can `go('/')` to a
///    fresh library.
/// 2. Skip rules before the await: `isDesktop`, or an open reader tab, or
///    `/reader` already in the router stack.
///    Also skip when a link launched the app (a shared word, say): the link
///    decides where the user lands, and a reopened book would cover it.
/// 3. `await ref.read(historyProvider.future)`. A loading state is not empty
///    — the future must be awaited. On throw or an empty list, stop.
/// 4. Re-check after the await — `!context.mounted`, or the reader is now
///    busy (a deep link that arrived meanwhile wins).
/// 5. Open `rows.first` through `openBookInReader`, which opens the tab and
///    pushes `/reader`. Errors are logged and leave the library showing.
///
/// Every return logs one line via [StartupTiming.mark].
Future<ResumeOutcome> resumeLastBook(
  BuildContext context,
  WidgetRef ref, {
  required bool isDesktop,
  Future<bool> Function()? launchedByLink,
}) async {
  // 1. Once per process — before any await.
  if (ref.read(resumeAttemptedProvider)) {
    StartupTiming.mark('resume last book: alreadyAttempted');
    return ResumeOutcome.alreadyAttempted;
  }
  ref.read(resumeAttemptedProvider.notifier).state = true;

  // 2. Skip rules before the await.
  if (isDesktop) {
    StartupTiming.mark('resume last book: desktop');
    return ResumeOutcome.desktop;
  }
  if (_readerBusy(context, ref)) {
    StartupTiming.mark('resume last book: readerBusy');
    return ResumeOutcome.readerBusy;
  }

  // A link that launched the app opens its own screen; the reader opened here
  // would land on top of it, because this runs after the link's screen.
  if (await (launchedByLink ?? DeepLinkService.instance.hasLaunchLink)()) {
    StartupTiming.mark('resume last book: launchedByLink');
    return ResumeOutcome.launchedByLink;
  }

  // 3. Read the history.
  List<ReadingHistoryData> rows;
  try {
    rows = await ref.read(historyProvider.future);
  } catch (e) {
    developer.log('reading history unavailable: $e', name: 'epitaka.resume');
    StartupTiming.mark('resume last book: historyError');
    return ResumeOutcome.historyError;
  }
  if (rows.isEmpty) {
    StartupTiming.mark('resume last book: historyEmpty');
    return ResumeOutcome.historyEmpty;
  }

  // 4. Re-check after the await — a deep link may have won meanwhile.
  if (!context.mounted) {
    StartupTiming.mark('resume last book: notMounted');
    return ResumeOutcome.notMounted;
  }
  if (_readerBusy(context, ref)) {
    StartupTiming.mark('resume last book: readerBusy');
    return ResumeOutcome.readerBusy;
  }

  // 5. Open the newest row's book at its saved paragraph and line.
  final row = rows.first;
  try {
    openBookInReader(
      context,
      ref,
      bookId: row.bookId,
      bookName: row.bookName,
      paraId: row.paraId,
      lineId: row.lineId,
    );
  } catch (e) {
    developer.log('failed to reopen last book: $e', name: 'epitaka.resume');
    StartupTiming.mark('resume last book: historyError');
    return ResumeOutcome.historyError;
  }

  StartupTiming.mark('resume last book: opened ${row.bookId} para ${row.paraId}');
  return ResumeOutcome.opened;
}

bool _readerBusy(BuildContext context, WidgetRef ref) =>
    ref.read(readerTabsProvider).isNotEmpty ||
    GoRouter.of(context)
        .routerDelegate.currentConfiguration.matches
        .any((m) => m.matchedLocation == AppRoutes.reader);
