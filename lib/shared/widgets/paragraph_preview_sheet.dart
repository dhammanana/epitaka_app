import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/utils/app_localizations.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../features/dictionary/widgets/dictionary_open.dart';
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

  /// Called when the sheet's action button is tapped. Receives the paragraph
  /// (and optional line) the user is currently reading in the sheet, so the
  /// caller can jump the reader to that position instead of the original
  /// match. `lineId` is null when the sheet can't resolve a specific line.
  void Function(int paraId, int? lineId)? onAction,
  int? scrollToParaId,
  int? scrollToLineId,

  /// Optional Pāli heading rendered above the lines (e.g. the linked
  /// section title in a book-link sheet).
  String? heading,

  /// Optional footer text centered below the lines (e.g. a para/line ref).
  String? footer,

  /// Route the sheet through the root navigator's overlay. Used when the
  /// sheet is opened on top of the reader, to keep it out of the reader's
  /// focus/semantics subtree.
  bool useRootNavigator = false,
}) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: useRootNavigator,
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
      heading: heading,
      footer: footer,
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

  /// Called with the currently-read (para, line) when the action is tapped.
  final void Function(int paraId, int? lineId)? onAction;

  /// Paragraph + line to scroll into view when the sheet opens.
  final int? scrollToParaId;
  final int? scrollToLineId;

  /// Optional Pāli heading rendered above the lines (e.g. the linked
  /// section title in a book-link sheet).
  final String? heading;

  /// Optional footer text centered below the lines (e.g. a para/line ref).
  final String? footer;

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
    this.heading,
    this.footer,
  });

  @override
  ConsumerState<_ParagraphPreviewSheet> createState() =>
      _ParagraphPreviewSheetState();
}

class _ParagraphPreviewSheetState extends ConsumerState<_ParagraphPreviewSheet> {
  final ScrollController _scrollController = ScrollController();

  /// Key on the scroll viewport, used to resolve the currently-visible line
  /// when the action button is tapped.
  final GlobalKey _viewportKey = GlobalKey();

  /// One GlobalKey per rendered line (indexed by position in
  /// [widget.lines]): used to scroll the target line into view on open and
  /// to resolve which line the user is currently reading.
  final Map<int, GlobalKey> _lineKeys = {};

  bool _didScrollToTarget = false;
  int _scrollRetries = 0;

  /// Index into [widget.lines] the sheet lands on when it opens — the exact
  /// scrollTo line, or the first line of the target paragraph when the exact
  /// line isn't in the rendered range.
  int? _targetLineIndex;

  /// Max attempts to locate the target line before giving up (the cited
  /// line may be absent from the rendered lines, e.g. hallucinated IDs).
  static const int _maxScrollRetries = 8;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.lines.length; i++) {
      _lineKeys[i] = GlobalKey();
    }
    _targetLineIndex = _resolveTargetLineIndex();
    // Scroll the exact target line into view once the sheet is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTarget());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int? _resolveTargetLineIndex() {
    final lines = widget.lines;
    if (lines.isEmpty) return null;
    final para = widget.scrollToParaId;
    final line = widget.scrollToLineId;
    if (para != null && line != null) {
      final exact = lines.indexWhere(
        (l) => l.paraId == para && l.lineId == line,
      );
      if (exact >= 0) return exact;
    }
    if (para != null) {
      final first = lines.indexWhere((l) => l.paraId == para);
      if (first >= 0) return first;
    }
    return null;
  }

  void _scrollToTarget() {
    if (_didScrollToTarget) return;
    final targetIndex = _targetLineIndex;
    if (targetIndex == null) return;
    final key = _lineKeys[targetIndex];
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

  /// Resolve which line the user is currently reading: the first line whose
  /// top is at or below the top edge of the scroll viewport (i.e. not yet
  /// scrolled past). When the sheet has no layout yet, falls back to the
  /// target line so opening immediately still lands on the match.
  (int, int?) _currentAnchor() {
    final lines = widget.lines;
    if (lines.isEmpty) return (0, null);

    final viewportTop = _viewportTop();
    if (viewportTop == null) {
      final target = _targetLineIndex;
      if (target != null && target < lines.length) {
        final t = lines[target];
        return (t.paraId, t.lineId);
      }
      return (lines.first.paraId, lines.first.lineId);
    }

    for (var i = 0; i < lines.length; i++) {
      final ctx = _lineKeys[i]?.currentContext;
      if (ctx == null || !ctx.mounted) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      if (box.localToGlobal(Offset.zero).dy >= viewportTop - 1) {
        final l = lines[i];
        return (l.paraId, l.lineId);
      }
    }
    final last = lines.last;
    return (last.paraId, last.lineId);
  }

  /// Top edge of the sheet's scroll viewport in global coordinates, or null
  /// when not laid out yet.
  double? _viewportTop() {
    final ctx = _viewportKey.currentContext;
    if (ctx == null || !ctx.mounted) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

  void _handleAction() {
    final onAction = widget.onAction;
    if (onAction == null) return;
    final (paraId, lineId) = _currentAnchor();
    onAction(paraId, lineId);
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
                      onPressed: _handleAction,
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
                      key: _viewportKey,
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.marginMobile,
                        AppDimensions.sm,
                        AppDimensions.marginMobile,
                        32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Optional heading (e.g. book-link section title) ─
                          if (w.heading != null && w.heading!.isNotEmpty) ...[
                            Container(
                              width: 32,
                              height: 2,
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                            const SizedBox(height: 6),
                            PaliTextStatic(
                              w.heading!,
                              script,
                              style: AppTypography.bodyPali.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          PreviewContent(
                            lines: w.lines,
                            highlightParaId: w.highlightParaId,
                            highlightLineId: w.highlightLineId,
                            firstSnippetIndex: w.firstSnippetIndex,
                            paliSnippet: w.paliSnippet,
                            lineKeys: _lineKeys,
                            onPaliWordTap: (word) {
                              // Close the preview sheet and open the dictionary
                              // in the panel/dock instead (desktop sidebar or
                              // mobile bottom dock).
                              openDictionaryInPanel(
                                context,
                                ref,
                                word,
                                closeSheet: true,
                              );
                            },
                          ),

                          // ── Optional footer (e.g. para/line ref badge) ─
                          if (w.footer != null && w.footer!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    w.footer!,
                                    style: AppTypography.labelSmall.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
