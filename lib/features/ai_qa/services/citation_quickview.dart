import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_localizations.dart';
import '../../../shared/services/paragraph_preview_loader.dart';
import '../../../shared/utils/app_navigation.dart';
import '../../../shared/widgets/paragraph_preview_sheet.dart';
import '../../reader/providers/reader_tabs_provider.dart';

/// Opens a "quickview" bottom sheet for an AI citation.
///
/// Instead of jumping straight to the reader, the cited passage is previewed
/// (Pāli + translation lines with the cited paragraph highlighted) so the
/// user can read it in context. An "Open in Reader" action then jumps to the
/// exact line in the reader.
Future<void> showCitationQuickview(
  BuildContext context,
  WidgetRef ref, {
  required String bookId,
  required String bookName,
  required int paraId,
  int? lineId,
}) async {
  HapticFeedback.mediumImpact();

  try {
    // 1–4. Load the cited paragraph's excerpt (heading title + Pāli +
    // translation lines) via the shared loader used by every quickview.
    final data = await loadParagraphPreview(
      ref,
      bookId: bookId,
      paraId: paraId,
    );
    final headingTitle = data.headingTitle;
    final previewLines = data.lines;

    if (previewLines.isEmpty) {
      if (context.mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.passageNotFound)),
        );
      }
      return;
    }

    if (!context.mounted) return;

    // Position the quickview at the exact cited line so the user sees the
    // passage they tapped (mirrors the reader's line-jump behaviour), and
    // highlight only that line. When the cited line isn't in the loaded
    // range (e.g. a hallucinated number), fall back to the paragraph-wide
    // highlight instead of highlighting nothing.
    final hasExactCitedLine = lineId != null &&
        previewLines.any((l) => l.paraId == paraId && l.lineId == lineId);
    await showParagraphPreviewSheet(
      context,
      title: headingTitle.isNotEmpty ? headingTitle : bookName,
      subtitle: headingTitle.isNotEmpty ? bookName : null,
      lines: previewLines,
      highlightParaId: paraId,
      highlightLineId: hasExactCitedLine ? lineId : null,
      firstSnippetIndex: previewLines.indexWhere((l) => l.paraId == paraId),
      scrollToParaId: paraId,
      scrollToLineId: lineId,
      actionLabel: AppLocalizations.of(context).openInReader,
      // Open at the position the user stopped reading in the sheet, not the
      // original citation line.
      onAction: (currentParaId, currentLineId) {
        ref
            .read(readerTabsProvider.notifier)
            .openTab(
              ReaderTabInfo(
                bookId: bookId,
                bookName: bookName,
                initialParaId: currentParaId,
                initialLineId: currentLineId,
              ),
            );
        Navigator.of(context).pop(); // close the quickview
        openReaderRoute(context);
      },
    );
  } catch (e) {
    if (context.mounted) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.couldNotLoadPreviewMsg + '$e')));
    }
  }
}
