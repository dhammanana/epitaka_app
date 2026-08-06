import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/utils/app_localizations.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../features/dictionary/widgets/dictionary_sheet.dart';
import 'pali_text.dart';
import 'preview_content.dart';

Future<void> showParagraphPreviewSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<PreviewLineData> lines,
  int? highlightParaId,
  int? highlightLineId,
  int? firstSnippetIndex,
  String? paliSnippet,
  String? actionLabel,
  VoidCallback? onAction,
  int? scrollToParaId,
  int? scrollToLineId,
  GlobalKey? targetLineKey,
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
      highlightLineId: highlightLineId,
      firstSnippetIndex: firstSnippetIndex,
      paliSnippet: paliSnippet ?? '',
      actionLabel: actionLabel,
      onAction: onAction,
      scrollToParaId: scrollToParaId,
      scrollToLineId: scrollToLineId,
      targetLineKey: targetLineKey,
    ),
  );
}

class _ParagraphPreviewSheet extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;
  final List<PreviewLineData> lines;
  final int? highlightParaId;
  final int? highlightLineId;
  final int? firstSnippetIndex;
  final String paliSnippet;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Paragraph + line to scroll into view when the sheet opens.
  final int? scrollToParaId;
  final int? scrollToLineId;

  /// Key attached to the target line so the sheet can bring it into view.
  final GlobalKey? targetLineKey;

  const _ParagraphPreviewSheet({
    required this.title,
    this.subtitle = '',
    required this.lines,
    this.highlightParaId,
    this.highlightLineId,
    this.firstSnippetIndex,
    this.paliSnippet = '',
    this.actionLabel,
    this.onAction,
    this.scrollToParaId,
    this.scrollToLineId,
    this.targetLineKey,
  });

  @override
  ConsumerState<_ParagraphPreviewSheet> createState() =>
      _ParagraphPreviewSheetState();
}

class _ParagraphPreviewSheetState extends ConsumerState<_ParagraphPreviewSheet> {
  bool _didScrollToTarget = false;
  int _scrollRetries = 0;

  /// Max attempts to locate the target line before giving up (the cited
  /// line may be absent from the rendered lines, e.g. hallucinated IDs).
  static const int _maxScrollRetries = 8;

  @override
  void initState() {
    super.initState();
    // Scroll the exact target line into view once the sheet is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTarget());
  }

  void _scrollToTarget() {
    if (_didScrollToTarget) return;
    final key = widget.targetLineKey;
    if (key == null) return;

    final ctx = key.currentContext;
    if (ctx == null) {
      // Not laid out yet (sheet is still animating in) — retry a few times.
      if (_scrollRetries >= _maxScrollRetries) return;
      _scrollRetries++;
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        _scrollToTarget();
      });
      return;
    }
    _didScrollToTarget = true;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.25,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final script = ref.watch(settingsProvider).paliScript;
    final w = widget;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.78,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusSheet),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.marginMobile,
                4,
                AppDimensions.marginMobile,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.bookmark_border, size: 16, color: colors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Heading titles and book names are Pāli — render
                        // them in the user's script, like the reader does.
                        PaliTextStatic(
                          w.title,
                          script,
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (w.subtitle.isNotEmpty)
                          PaliTextStatic(
                            w.subtitle,
                            script,
                            style: AppTypography.labelSmall.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (w.actionLabel != null && w.onAction != null)
                    TextButton.icon(
                      onPressed: w.onAction,
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: Text(w.actionLabel!, style: const TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Divider(height: 1),
            Expanded(
              child: w.lines.isEmpty
                  ? Center(
                      child: Text(
                        loc.noContentAvailable,
                        style: AppTypography.bodyTranslation.copyWith(
                          color: colors.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.marginMobile,
                        AppDimensions.sm,
                        AppDimensions.marginMobile,
                        32,
                      ),
                      child: PreviewContent(
                        lines: w.lines,
                        highlightParaId: w.highlightParaId,
                        highlightLineId: w.highlightLineId,
                        firstSnippetIndex: w.firstSnippetIndex,
                        paliSnippet: w.paliSnippet,
                        scrollToParaId: w.scrollToParaId,
                        scrollToLineId: w.scrollToLineId,
                        targetLineKey: w.targetLineKey,
                        onPaliWordTap: (word) =>
                            showDictionarySheet(context, word.trim()),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
