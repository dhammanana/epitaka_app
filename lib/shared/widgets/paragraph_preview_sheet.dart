import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent, SelectedContent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/utils/app_localizations.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/native_lookup_service.dart';
import '../../features/dictionary/widgets/dictionary_open.dart';
import 'pali_text.dart';
import 'preview_content.dart';
import 'wide_bottom_sheet.dart';

/// True when [s] carries no real title text — only digits and number
/// punctuation (e.g. a bare paragraph number like "150."). Such headings
/// are hidden instead of shown as a meaningless numeric title.
bool isNumericOnlyTitle(String s) {
  final t = s.trim();
  return t.isNotEmpty &&
      RegExp(r'^[\d\s.,:;\-–—]+$').hasMatch(t) &&
      RegExp(r'\d').hasMatch(t);
}

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
    // Wide screens: span 80% of the app instead of the 640 px default cap.
    constraints: wideBottomSheetConstraints(context),
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

class _ParagraphPreviewSheetState
    extends ConsumerState<_ParagraphPreviewSheet> {
  final ScrollController _scrollController = ScrollController();

  /// Key on the scroll viewport, used to resolve the currently-visible line
  /// when the action button is tapped.
  final GlobalKey _viewportKey = GlobalKey();

  /// The single [GlobalKey] in the sheet, attached to the target line (see
  /// [_targetLineIndex]). Used to scroll that line into view on open. Every
  /// other line gets a lightweight [ValueKey].
  final GlobalKey _targetKey = GlobalKey();

  bool _didScrollToTarget = false;
  int _scrollRetries = 0;

  /// Track the last text selection for the context menu's dictionary lookup.
  SelectedContent? _lastSelectedContent;

  /// Index into [widget.lines] the sheet lands on when it opens — the exact
  /// scrollTo line, or the closest line of the target paragraph when the
  /// exact line isn't in the rendered range (e.g. a cited line number
  /// beyond the paragraph's last line).
  int? _targetLineIndex;

  /// Max forward-page attempts before giving up on reaching the target row.
  static const int _maxScrollRetries = 20;

  /// Rows cached around the viewport (each side). Short previews (book-link
  /// / citation sheets, capped at ~61 lines) build every row on the first
  /// frame so the target row exists immediately; very long ones (search
  /// previews) page forward in [_scrollToTarget] instead.
  static const int _eagerCacheLineLimit = 80;

  /// Per-side pixel cache for very long lists (see [_eagerCacheLineLimit]).
  static const double _largeListCacheExtent = 8000.0;

  /// Cache extent for the lines list: eager for short previews, bounded
  /// for very long ones. Used both by the [ListView] and by the paging
  /// step in [_scrollToTarget] (step = viewport + cache, so pages always
  /// overlap and the target row can never be skipped over).
  double get _cacheExtent {
    final n = widget.lines.length;
    if (n <= _eagerCacheLineLimit) return n * 250.0;
    return _largeListCacheExtent;
  }

  @override
  void initState() {
    super.initState();
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
      // Exact line absent (e.g. a cited line number beyond the paragraph):
      // land on the closest line of the paragraph instead of its first.
      var best = -1;
      var bestDist = 1 << 30;
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].paraId != para) continue;
        final d = line == null ? 0 : (lines[i].lineId - line).abs();
        if (d < bestDist) {
          bestDist = d;
          best = i;
        }
      }
      if (best >= 0) return best;
    }
    return null;
  }

  void _scrollToTarget() {
    if (_didScrollToTarget || !mounted) return;
    if (_targetLineIndex == null) return;

    final ctx = _targetKey.currentContext;
    if (ctx != null) {
      _didScrollToTarget = true;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.25,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      return;
    }
    // No context for the target row yet: the sheet is still animating in,
    // or the target sits deep in a lazily-built list whose rows outside
    // the viewport were never built. Page monotonically forward — never
    // backwards — so every page gets built and the target row must appear;
    // a fixed offset estimate would undershoot on tall rows and retry the
    // same offset forever, then give up at the wrong position.
    if (_scrollRetries >= _maxScrollRetries) return;
    _scrollRetries++;
    if (_scrollController.hasClients) {
      final pos = _scrollController.position;
      final max = pos.maxScrollExtent;
      if (max > 0) {
        // Step (viewport + cache) always overlaps the previously built
        // range, so the target row can never be skipped over.
        final step = pos.viewportDimension + _cacheExtent;
        _scrollController.jumpTo(min(pos.pixels + step, max));
      }
    }
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      _scrollToTarget();
    });
  }

  /// Resolve which line the user is currently reading. Without per-line keys
  /// this is approximate: while the sheet sits at the top the target (or
  /// first) line is reported; once the user scrolls past the target line the
  /// end of the preview range is reported. When the sheet has no layout yet,
  /// falls back to the target line so opening immediately still lands on
  /// the match.
  (int, int?) _currentAnchor() {
    final lines = widget.lines;
    if (lines.isEmpty) return (0, null);

    (int, int?) targetOrFirst() {
      final target = _targetLineIndex;
      if (target != null && target < lines.length) {
        final t = lines[target];
        return (t.paraId, t.lineId);
      }
      return (lines.first.paraId, lines.first.lineId);
    }

    if (!_scrollController.hasClients || _scrollController.offset <= 1.0) {
      return targetOrFirst();
    }

    // Single-key check: if the target line is still at/below the viewport
    // top the user hasn't scrolled past it.
    final targetCtx = _targetKey.currentContext;
    final viewportTop = _viewportTop();
    if (targetCtx != null && targetCtx.mounted && viewportTop != null) {
      final box = targetCtx.findRenderObject() as RenderBox?;
      if (box != null && box.attached) {
        if (box.localToGlobal(Offset.zero).dy >= viewportTop - 1) {
          return targetOrFirst();
        }
      }
    } else {
      return targetOrFirst();
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

  /// Context menu shown when the user selects text inside the preview.
  /// Includes a "Search" action to look up the selection in the dictionary.
  Widget _selectionContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final loc = AppLocalizations.of(context);
    TextSelectionToolbarAnchors anchors;
    try {
      anchors = selectableRegionState.contextMenuAnchors;
    } catch (_) {
      anchors = const TextSelectionToolbarAnchors(primaryAnchor: Offset.zero);
    }

    final raw = _lastSelectedContent?.plainText;
    final searchable = raw == null || raw.trim().isEmpty
        ? null
        : raw.replaceAll('\uFFFC', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: anchors,
      buttonItems: [
        if (searchable != null)
          ContextMenuButtonItem(
            label: '${loc.search} "${_truncateLabel(searchable)}"',
            onPressed: () {
              selectableRegionState.clearSelection();
              // Stack the dictionary on top of this sheet (forceSheet) so
              // closing it returns to the preview/book-link content instead
              // of dumping the user back on the reader.
              openDictionaryInPanel(context, ref, searchable, forceSheet: true);
            },
          ),
        if (searchable != null && NativeLookupService.isSupported)
          ContextMenuButtonItem(
            label: '${loc.lookUp} "${_truncateLabel(searchable)}"',
            onPressed: () {
              selectableRegionState.clearSelection();
              NativeLookupService.lookUp(searchable);
            },
          ),
        ContextMenuButtonItem(
          label: loc.copy,
          onPressed: () {
            final text = _lastSelectedContent?.plainText;
            if (text != null && text.isNotEmpty) {
              Clipboard.setData(ClipboardData(text: text));
            }
            selectableRegionState.clearSelection();
          },
        ),
        ContextMenuButtonItem(
          label: loc.selectAll,
          onPressed: () =>
              selectableRegionState.selectAll(SelectionChangedCause.toolbar),
        ),
      ],
    );
  }

  static String _truncateLabel(String s) =>
      s.length <= 28 ? s : '${s.substring(0, 28)}\u2026';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final loc = AppLocalizations.of(context);
    final script = ref.watch(settingsProvider.select((s) => s.paliScript));
    final paliTypo = ref.watch(
      settingsProvider.select((s) => s.typography.pali),
    );
    final paliColor = ref
        .watch(settingsProvider.select((s) => s.paliColorPair))
        .resolve(brightness);
    final transColor = ref
        .watch(settingsProvider.select((s) => s.translationColorPair))
        .resolve(brightness);
    final typography = ref.watch(settingsProvider.select((s) => s.typography));
    final w = widget;
    final hasHeading =
        w.heading != null &&
        w.heading!.isNotEmpty &&
        !isNumericOnlyTitle(w.heading!);
    final hasFooter = w.footer != null && w.footer!.isNotEmpty;

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
                      label: Text(
                        w.actionLabel!,
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Divider(height: 1),
            // ── Optional heading (e.g. book-link section title), pinned
            // above the scrollable lines so target indices map 1:1. ──
            if (hasHeading)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                    const SizedBox(height: 8),
                  ],
                ),
              ),
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
                  : SelectionArea(
                      onSelectionChanged: (content) {
                        _lastSelectedContent = content;
                      },
                      contextMenuBuilder: (context, selectableRegionState) =>
                          _selectionContextMenu(context, selectableRegionState),
                      child: ListView.builder(
                        key: _viewportKey,
                        controller: _scrollController,
                        scrollCacheExtent: ScrollCacheExtent.pixels(
                          _cacheExtent,
                        ),
                        padding: const EdgeInsets.all(10),
                        itemCount: w.lines.length,
                        itemBuilder: (context, index) {
                          final line = w.lines[index];
                          final isTargetPara = line.paraId == w.highlightParaId;
                          final isMatch =
                              isTargetPara &&
                              (w.highlightLineId == null ||
                                  line.lineId == w.highlightLineId);
                          final isFirstSnippetLine =
                              isTargetPara &&
                              w.firstSnippetIndex != null &&
                              index == w.firstSnippetIndex;
                          final isFirstInPara =
                              index == 0 ||
                              line.paraId != w.lines[index - 1].paraId;
                          final isLastInPara =
                              index == w.lines.length - 1 ||
                              line.paraId != w.lines[index + 1].paraId;
                          final isTargetParaGroup =
                              (w.scrollToParaId ?? w.highlightParaId) ==
                              line.paraId;
                          return RepaintBoundary(
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: isFirstInPara && index > 0 ? 12 : 0,
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      width: 3,
                                      margin: const EdgeInsets.only(left: 4),
                                      decoration: BoxDecoration(
                                        color: isTargetParaGroup
                                            ? colors.primary
                                            : colors.outlineVariant.withValues(
                                                alpha: 0.6,
                                              ),
                                        borderRadius: BorderRadius.vertical(
                                          top: isFirstInPara
                                              ? const Radius.circular(2)
                                              : Radius.zero,
                                          bottom: isLastInPara
                                              ? const Radius.circular(2)
                                              : Radius.zero,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: PreviewLine(
                                        key: index == _targetLineIndex
                                            ? _targetKey
                                            : ValueKey(
                                                '${line.paraId}_${line.lineId}_$index',
                                              ),
                                        line: line,
                                        isMatch: isMatch,
                                        isNewPara: false,
                                        paliSnippet: isFirstSnippetLine
                                            ? w.paliSnippet
                                            : null,
                                        script: script,
                                        colors: colors,
                                        paliColor: paliColor,
                                        transColor: transColor,
                                        paliTypo: paliTypo,
                                        typography: typography,
                                        onPaliWordTap: (word) {
                                          // Open the dictionary as a NEW sheet on top of
                                          // this one (forceSheet) instead of closing the
                                          // preview — closing the dictionary returns to
                                          // the commentary being read here.
                                          openDictionaryInPanel(
                                            context,
                                            ref,
                                            word,
                                            forceSheet: true,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
            // ── Optional footer (e.g. para/line ref badge), pinned below ──
            if (hasFooter)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.marginMobile,
                  8,
                  AppDimensions.marginMobile,
                  12,
                ),
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
    );
  }
}
