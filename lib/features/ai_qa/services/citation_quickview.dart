import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../shared/widgets/paragraph_preview_sheet.dart';
import '../../../shared/widgets/preview_content.dart';
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
    final epitakaDb = await ref.read(epitakaDbProvider.future);
    final settings = ref.read(settingsProvider);
    final activeLang = settings.enabledTranslations.isNotEmpty
        ? settings.enabledTranslations.first
        : (settings.showTranslation ? settings.primaryTranslationLang : null);

    // 1. Resolve the nearest heading for a meaningful title.
    final headingTitle = (await epitakaDb.getHeadingTitleAtPara(
          bookId,
          paraId,
          includeLevel10: true,
        )) ??
        '';

    // 2. Load the cited paragraph's lines.
    final sentenceRows = await epitakaDb
        .customSelect(
          'SELECT para_id, line_id, pali FROM sentences '
          'WHERE book_id = ? AND para_id = ? '
          'ORDER BY line_id',
          variables: [
            Variable.withString(bookId),
            Variable.withInt(paraId),
          ],
        )
        .get();

    // 3. Load translations for the same paragraph.
    final translationMap = <String, Map<String, String>>{};
    if (activeLang != null) {
      try {
        final transDb = await ref.read(translationDbProvider(activeLang).future);
        if (transDb != null) {
          final transRows = await transDb
              .customSelect(
                'SELECT para_id, line_id, translation FROM sentences '
                'WHERE book_id = ? AND para_id = ? '
                'ORDER BY line_id',
                variables: [
                  Variable.withString(bookId),
                  Variable.withInt(paraId),
                ],
              )
              .get();
          for (final row in transRows) {
            final key = '${row.data['para_id']}:${row.data['line_id']}';
            final t = row.data['translation'] as String?;
            if (t != null && t.isNotEmpty) {
              translationMap.putIfAbsent(key, () => {})[activeLang] = t;
            }
          }
        }
      } catch (_) {}
    }

    // 4. Build preview lines.
    final previewLines = sentenceRows.map((r) {
      final key = '${r.data['para_id']}:${r.data['line_id']}';
      return PreviewLineData(
        paraId: r.data['para_id'] as int,
        lineId: r.data['line_id'] as int,
        pali: r.data['pali'] as String? ?? '',
        translations: translationMap[key] ?? {},
      );
    }).toList();

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
    // passage they tapped (mirrors the reader's line-jump behaviour).
    final targetLineKey = GlobalKey();
    await showParagraphPreviewSheet(
      context,
      title: headingTitle.isNotEmpty ? headingTitle : bookName,
      subtitle: headingTitle.isNotEmpty ? bookName : null,
      lines: previewLines,
      highlightParaId: paraId,
      firstSnippetIndex: previewLines.indexWhere((l) => l.paraId == paraId),
      scrollToParaId: paraId,
      scrollToLineId: lineId,
      targetLineKey: targetLineKey,
      actionLabel: AppLocalizations.of(context).openInReader,
      onAction: () {
        ref
            .read(readerTabsProvider.notifier)
            .openTab(
              ReaderTabInfo(
                bookId: bookId,
                bookName: bookName,
                initialParaId: paraId,
                initialLineId: lineId,
              ),
            );
        Navigator.of(context).pop(); // close the quickview
        context.push('/reader');
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
