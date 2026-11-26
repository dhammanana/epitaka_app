import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../shared/utils/app_navigation.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../providers/sutta_history_provider.dart';
import 'sutta_code_service.dart';

/// Opens [target] the way the "Go to sutta" box does: a history entry, a
/// reader tab at the paragraph, and the reader screen. [context] must still
/// be mounted when the book name has loaded.
Future<void> openSuttaTarget(BuildContext context, SuttaTarget target) async {
  final container = ProviderScope.containerOf(context, listen: false);
  container.read(suttaHistoryProvider.notifier).add(encodeSutta(target));
  final bookName = await suttaBookName(container, target.bookId);
  if (!context.mounted) return;
  container
      .read(readerTabsProvider.notifier)
      .openTab(
        ReaderTabInfo(
          bookId: target.bookId,
          bookName: bookName,
          initialParaId: target.paraId,
        ),
      );
  openReaderRoute(context);
}

/// The display name of [bookId], so a new reader tab has a title at once.
/// Falls back to the raw book id.
Future<String> suttaBookName(ProviderContainer container, String bookId) async {
  try {
    final db = await container.read(epitakaDbProvider.future);
    final rows = await (db.select(db.books)
          ..where((b) => b.bookId.equals(bookId))
          ..limit(1))
        .get();
    final name = rows.isNotEmpty ? rows.first.bookName : null;
    if (name != null && name.isNotEmpty) return name;
  } catch (e) {
    developer.log(
      '[GO TO SUTTA] Book name lookup failed for $bookId: $e',
      name: 'epitaka.sutta_jump',
    );
  }
  return bookId;
}
