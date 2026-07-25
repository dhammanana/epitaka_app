import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/models/app_models.dart';
import '../providers/reader_provider.dart';
import '../providers/reader_tabs_provider.dart';
import '../utils/reader_position_utils.dart' show getCurrentParaId;
import '../widgets/bookmark_dialog.dart';
import '../widgets/jump_sheet.dart';

/// Controller for reader actions that need access to [WidgetRef] and
/// [BuildContext] but don't own any UI state of their own.
///
/// Instantiated as a plain [Provider] so it can be shared across widgets
/// without creating a new instance on every build.
class ReaderActionController {
  /// Open the jump sheet for the given tab.
  Future<void> onJumpTap(
    BuildContext context,
    WidgetRef ref,
    Iterable<ItemPosition>? positions,
    ReaderTabInfo activeTab,
    ReaderDataState readerState,
  ) async {
    final currentParaId = getCurrentParaId(positions, readerState);
    if (currentParaId == null) return;
    if (!context.mounted) return;

    await showJumpSheet(
      context,
      bookId: activeTab.bookId,
      bookName: readerState.bookName ?? activeTab.bookId,
      currentParaId: currentParaId,
    );
  }

  /// Open the bookmark dialog for the given tab, with a nearby heading
  /// suggested as the bookmark name.
  void onBookmarkTap(
    BuildContext context,
    WidgetRef ref,
    ReaderTabInfo activeTab,
    ReaderDataState readerState,
  ) {
    final pageNumber =
        readerState.paragraphs.isNotEmpty &&
                readerState.paragraphs.first.pageNumber != null
            ? readerState.paragraphs.first.pageNumber
            : null;

    // Find nearby heading to suggest as bookmark name
    final currentParaId = activeTab.currentParaId;
    String? suggestedHeading;
    if (currentParaId != null) {
      final notifier =
          ref.read(readerDataProvider(activeTab.bookId).notifier);
      final nearby = notifier.findNearbyHeading(currentParaId);
      if (nearby != null) {
        suggestedHeading = nearby.title;
      }
    }

    showBookmarkDialog(
      context,
      bookId: activeTab.bookId,
      bookName: readerState.bookName ?? activeTab.bookId,
      pageNumber: pageNumber,
      suggestedHeading: suggestedHeading,
    );
  }
}

/// Plain [Provider] so the controller is a singleton — it holds no mutable
/// state, only provides methods that take [WidgetRef] and [BuildContext].
final readerActionControllerProvider =
    Provider<ReaderActionController>((ref) {
  return ReaderActionController();
});
