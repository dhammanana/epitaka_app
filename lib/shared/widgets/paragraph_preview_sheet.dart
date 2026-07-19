import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_localizations.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../features/dictionary/widgets/dictionary_sheet.dart';
import 'preview_content.dart';

Future<void> showParagraphPreviewSheet(
  BuildContext context, {
  required String title, String? subtitle, required List<PreviewLineData> lines, int? highlightParaId, int? firstSnippetIndex, String? paliSnippet, String? actionLabel, VoidCallback? onAction,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ParagraphPreviewSheet(
      title: title,
      subtitle: subtitle ?? '',
      lines: lines,
      highlightParaId: highlightParaId,
      firstSnippetIndex: firstSnippetIndex,
      paliSnippet: paliSnippet ?? '',
      actionLabel: actionLabel,
      onAction: onAction,
    ),
  );
}

class _ParagraphPreviewSheet extends ConsumerWidget {
  final String title; final String subtitle; final List<PreviewLineData> lines; final int? highlightParaId; final int? firstSnippetIndex; final String paliSnippet; final String? actionLabel; final VoidCallback? onAction;
  const _ParagraphPreviewSheet({required this.title, this.subtitle = '', required this.lines, this.highlightParaId, this.firstSnippetIndex, this.paliSnippet = '', this.actionLabel, this.onAction});

  @override Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme; final loc = AppLocalizations.of(context);
    return Container(height: MediaQuery.sizeOf(context).height * 0.78,
      decoration: BoxDecoration(color: colors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusSheet))),
      child: Scaffold(backgroundColor: Colors.transparent, body: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.only(top: 8), width: 32, height: 4, decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.fromLTRB(AppDimensions.marginMobile, 4, AppDimensions.marginMobile, 0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.bookmark_border, size: 16, color: colors.primary), const SizedBox(width: 6),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTypography.labelSmall.copyWith(color: colors.primary, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (subtitle.isNotEmpty) Text(subtitle, style: AppTypography.labelSmall.copyWith(color: colors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          if (actionLabel != null && onAction != null)
            TextButton.icon(onPressed: onAction, icon: const Icon(Icons.open_in_new, size: 14), label: Text(actionLabel!, style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: colors.primary, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap)),
        ])),
        const SizedBox(height: 4), const Divider(height: 1),
        Expanded(child: lines.isEmpty
          ? Center(child: Text(loc.noContentAvailable, style: AppTypography.bodyTranslation.copyWith(color: colors.onSurfaceVariant, fontStyle: FontStyle.italic)))
          : SingleChildScrollView(padding: const EdgeInsets.fromLTRB(AppDimensions.marginMobile, AppDimensions.sm, AppDimensions.marginMobile, 32),
              child: PreviewContent(lines: lines, highlightParaId: highlightParaId, firstSnippetIndex: firstSnippetIndex, paliSnippet: paliSnippet, onPaliWordTap: (word) => showDictionarySheet(context, word.trim())))),
      ])),
    );
  }
}
