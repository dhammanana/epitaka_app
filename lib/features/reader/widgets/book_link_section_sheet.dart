import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/translation_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../shared/widgets/paragraph_preview_sheet.dart';
import '../../../shared/widgets/preview_content.dart';
import '../../dictionary/providers/dictionary_sheet_open_provider.dart';
import '../data/book_link_data.dart';
import '../providers/reader_tabs_provider.dart';
import '../services/book_link_service.dart';

/// Shows the bottom sheet with linked paragraph content.
///
/// Called when the user taps a book link chip. The linked section is loaded
/// BEFORE the sheet is shown — the same pattern as the search quickview,
/// which also fetches everything first and only then opens the sheet — so
/// the sheet itself renders instantly with ready data and never shows a
/// spinner. The sheet UI is the shared [showParagraphPreviewSheet]; this
/// function only loads the section and maps it onto that sheet.
Future<void> showBookLinkSectionSheet(
  BuildContext context, {
  required BookLinkData link,
}) async {
  final container = ProviderScope.containerOf(context);
  // Re-entry guard: ignore the tap while a sheet is already open (or being
  // fetched), so two chips tapped in quick succession don't stack sheets.
  if (container.read(dictionarySheetOpenProvider) > 0) return;

  // Mark the sheet as open so the reader behind it drops the expensive work
  // it would otherwise keep doing (position-writes, viewInsets re-layout,
  // semantics collection on its huge ScrollablePositionedList) — the same
  // guard the dictionary sheet uses. Without it, this sheet — which is
  // always opened on top of a reading book — makes scrolling janky.
  container.read(dictionarySheetOpenProvider.notifier).state++;

  try {
    LinkedParagraphContent? content;
    try {
      final db = await container.read(epitakaDbProvider.future);
      final settings = container.read(settingsProvider);

      // Load only ONE translation language (the primary one), matching the
      // search quickview. The old sheet opened a translation database for
      // every enabled language per tap, which is what made it slow.
      final activeLang = settings.enabledTranslations.isNotEmpty
          ? settings.enabledTranslations.first
          : (settings.showTranslation ? settings.primaryTranslationLang : null);

      final transDbs = <String, TranslationDatabase>{};
      if (activeLang != null) {
        try {
          final transDb = await container
              .read(translationDbProvider(activeLang).future);
          if (transDb != null) {
            transDbs[activeLang] = transDb;
          }
        } catch (_) {
          // Skip unavailable translation db
        }
      }

      content = await BookLinkService(db).getLinkedContent(
        link.linkedBookId,
        link.linkedParaId,
        // The line anchors the preview window: when the section is huge,
        // only the lines around this one are loaded/rendered.
        lineId: link.linkedLineId,
        translationDbs: transDbs.isNotEmpty ? transDbs : null,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context).failedToLoadPreview} $e',
            ),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final loc = AppLocalizations.of(context);

    // Convert the loaded lines to the shared preview format. When the linked
    // section is empty (content == null), the empty list makes the sheet show
    // its "no content available" state instead of a spinner.
    final previewLines = (content?.lines ?? const <LinkedLine>[]).map((line) {
      return PreviewLineData(
        paraId: line.paraId,
        lineId: line.lineId,
        pali: line.paliText,
        translations: line.translations,
      );
    }).toList();

    await showParagraphPreviewSheet(
      context,
      title: content?.bookName ?? link.linkedBookId,
      subtitle: '${loc.linkedFrom} “${link.word}”',
      lines: previewLines,
      highlightParaId: content?.paraId,
      heading: content?.headingTitle,
      scrollToParaId: link.linkedParaId,
      scrollToLineId: link.linkedLineId,
      targetLineKey: GlobalKey(),
      footer: content != null
          ? 'para ${content.paraId} · line ${link.linkedLineId}'
              '${content.isTrimmed && content.lines.length < content.totalLines ? ' · ${content.lines.length} of ${content.totalLines} lines' : ''}'
          : null,
      actionLabel: loc.open,
      onAction: () {
        final c = content;
        if (c == null) return;
        // Deliberately no context.push('/reader') here: this sheet is opened
        // from the reader, which is already the current route. openTab
        // updates the shared tabs state, so closing the sheet is enough —
        // pushing '/reader' stacked a duplicate reader screen and forced
        // extra Back presses.
        container.read(readerTabsProvider.notifier).openTab(
              ReaderTabInfo(
                bookId: link.linkedBookId,
                bookName: c.bookName,
                initialParaId: link.linkedParaId,
                initialLineId: link.linkedLineId,
              ),
            );
        Navigator.of(context, rootNavigator: true).pop();
      },
      // Route through the root navigator so the sheet lives in its own
      // overlay entry, away from the reader's focus/semantics subtree.
      useRootNavigator: true,
    );
  } finally {
    container.read(dictionarySheetOpenProvider.notifier).state--;
  }
}
