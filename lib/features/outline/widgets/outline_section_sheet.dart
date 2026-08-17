/// Quickview bottom sheet for one outline section.
///
/// Tap a section in the outline → this sheet lets the user "check to read"
/// before opening the reader:
///   * **Text** tab — the section's Pāli + translation excerpt, rendered
///     with the shared [PreviewContent] (same widget the search / citation
///     quickviews use), with dictionary double-tap.
///   * **Study guide** tab — the AI study guide (markdown with tappable
///     citations) read from the local English translation DB (offline, with
///     a network fallback) and rendered with the shared [AiMarkdownView]
///     (same widget the Vimaṃsa chat uses). The tab is only shown once a
///     guide actually resolves — sections without a summary just get the
///     Text tab, so no spinner ever hangs on a missing guide.
///   * **Open in Reader** — jumps the reader to the section (or, if the
///     user is reading the study guide, keeps the excerpt tab selected so
///     the reader opens on the passage itself).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../shared/services/paragraph_preview_loader.dart';
import '../../../shared/utils/app_navigation.dart';
import '../../../shared/widgets/ai_markdown_view.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../../shared/widgets/preview_content.dart';
import '../../ai_qa/services/citation_quickview.dart';
import '../../dictionary/widgets/dictionary_open.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../models/outline_models.dart';
import '../services/study_guide_fetcher.dart';

/// Opens the quickview sheet for [item] of [bookId]. Loads the section
/// excerpt first (offline-safe); the study guide is resolved in the sheet
/// and its tab only shown when a guide exists.
Future<void> showOutlineSectionSheet(
  BuildContext context,
  WidgetRef ref, {
  required String bookId,
  required String bookName,
  required OutlineItem item,
}) async {
  HapticFeedback.mediumImpact();

  final ParagraphPreviewData data;
  try {
    data = await loadParagraphPreview(
      ref,
      bookId: bookId,
      paraId: item.paraId,
      paraEnd: item.sectionEnd,
    );
  } catch (e) {
    if (context.mounted) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.errorMessage('$e'))),
      );
    }
    return;
  }

  if (!context.mounted) return;

  if (data.lines.isEmpty) {
    final loc = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.noContentAvailable)),
    );
    return;
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OutlineSectionSheet(
      bookId: bookId,
      bookName: bookName,
      item: item,
      preview: data,
    ),
  );
}

class _OutlineSectionSheet extends ConsumerStatefulWidget {
  final String bookId;
  final String bookName;
  final OutlineItem item;
  final ParagraphPreviewData preview;

  const _OutlineSectionSheet({
    required this.bookId,
    required this.bookName,
    required this.item,
    required this.preview,
  });

  @override
  ConsumerState<_OutlineSectionSheet> createState() =>
      _OutlineSectionSheetState();
}

class _OutlineSectionSheetState extends ConsumerState<_OutlineSectionSheet> {
  int _tab = 0; // 0 = text excerpt, 1 = study guide

  StudyGuideQuery get _studyGuideQuery => StudyGuideQuery(
        bookId: widget.bookId,
        sectionId: widget.item.paraId,
      );

  void _openStudyGuideTab() {
    if (_tab == 1) return;
    setState(() => _tab = 1);
  }

  void _openInReader() {
    ref.read(readerTabsProvider.notifier).openTab(
      ReaderTabInfo(
        bookId: widget.bookId,
        bookName: widget.bookName,
        initialParaId: widget.item.paraId,
      ),
    );
    Navigator.of(context).pop(); // close the quickview
    openReaderRoute(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final script = ref.watch(settingsProvider).paliScript;
    final item = widget.item;

    // Resolve the study guide up front (reads the local epitaka_en.db
    // first, network only as a fallback) and offer the Study guide tab
    // ONLY when a guide actually exists. This replaces the old lazy
    // FutureBuilder, which showed a spinner for every section and, when
    // there was no summary, hung on the network fallback before giving up.
    final studyGuideAsync = ref.watch(studyGuideProvider(_studyGuideQuery));
    final hasStudyGuide =
        studyGuideAsync.hasValue && studyGuideAsync.value != null;
    // Never leave the segmented control selected on a hidden segment (e.g.
    // after the provider is invalidated and reloads to loading/null).
    final tab = (_tab == 1 && hasStudyGuide) ? 1 : 0;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.8,
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
            // ── Drag handle ────────────────────────────────────────
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
            // ── Header ─────────────────────────────────────────────
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
                  Icon(Icons.account_tree_outlined,
                      size: 16, color: colors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PaliTextStatic(
                          item.title.isNotEmpty
                              ? item.title
                              : '${loc.section} ${item.paraId}',
                          script,
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.bookName.isNotEmpty)
                          PaliTextStatic(
                            widget.bookName,
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
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ── Tab selector ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 0,
                    label: Text(loc.textTab),
                    icon: const Icon(Icons.article_outlined, size: 16),
                  ),
                  if (hasStudyGuide)
                    ButtonSegment(
                      value: 1,
                      label: Text(loc.studyGuide),
                      icon: const Icon(Icons.menu_book_outlined, size: 16),
                    ),
                ],
                selected: {tab},
                onSelectionChanged: (selection) {
                  if (selection.first == 1) {
                    _openStudyGuideTab();
                  } else {
                    setState(() => _tab = 0);
                  }
                },
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                    AppTypography.labelSmall.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Divider(height: 1),
            // ── Body ───────────────────────────────────────────────
            Expanded(
              child: _buildBody(tab, colors, loc, studyGuideAsync.value),
            ),
            // ── Footer: Open in Reader ─────────────────────────────
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.md,
                  6,
                  AppDimensions.md,
                  10,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openInReader,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(loc.openInReader),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildBody(
    int tab,
    ColorScheme colors,
    AppLocalizations loc,
    StudyGuide? guide,
  ) {
    if (tab == 1) return _buildStudyGuide(colors, loc, guide!);
    return _buildText(colors);
  }

  Widget _buildText(ColorScheme colors) {
    final script = ref.watch(settingsProvider).paliScript;
    final preview = widget.preview;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.sm,
        AppDimensions.marginMobile,
        32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section heading line (Pāli), mirroring the preview sheet's
          // optional heading block.
          if (widget.item.title.isNotEmpty) ...[
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
              widget.item.title,
              script,
              style: AppTypography.bodyPali.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 16),
          ],
          PreviewContent(
            lines: preview.lines,
            highlightParaId: widget.item.paraId,
            onPaliWordTap: (word) {
              openDictionaryInPanel(context, ref, word, closeSheet: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStudyGuide(
    ColorScheme colors,
    AppLocalizations loc,
    StudyGuide guide,
  ) {
    // Called only when a guide has resolved (the segment is hidden
    // otherwise), so the content is already loaded — no spinner here.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.md,
        AppDimensions.marginMobile,
        32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (guide.title.isNotEmpty)
            Text(
              guide.title,
              style: AppTypography.headlineSmall.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (guide.title.isNotEmpty) const SizedBox(height: 12),
          AiMarkdownView(
            data: guide.contentMd,
            onCitationTap: (bookId, paraId, lineId) {
              // Citation chips reuse the vimaṃsa quickview so the user
              // can check the quoted passage right here.
              showCitationQuickview(
                context,
                ref,
                bookId: bookId,
                bookName: bookId,
                paraId: paraId,
                lineId: lineId,
              );
            },
          ),
        ],
      ),
    );
  }
}
