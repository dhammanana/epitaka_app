import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/translation_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../dictionary/widgets/dictionary_sheet.dart';
import '../../../shared/widgets/preview_content.dart';
import '../../../shared/widgets/pali_text.dart';
import '../data/book_link_data.dart';
import '../providers/reader_tabs_provider.dart';
import '../services/book_link_service.dart';

/// Shows the bottom sheet with linked paragraph content.
///
/// Called when the user taps a book link chip. Uses the shared
/// [PreviewContent] widget to render Pāli + translation lines with
/// the same typography settings as the reader.
Future<void> showBookLinkSectionSheet(
  BuildContext context, {
  required BookLinkData link,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BookLinkSectionSheet(link: link),
  );
}

class _BookLinkSectionSheet extends ConsumerStatefulWidget {
  final BookLinkData link;

  const _BookLinkSectionSheet({required this.link});

  @override
  ConsumerState<_BookLinkSectionSheet> createState() =>
      _BookLinkSectionSheetState();
}

class _BookLinkSectionSheetState extends ConsumerState<_BookLinkSectionSheet> {
  LinkedParagraphContent? _content;
  bool _isLoading = true;
  String? _error;
  final GlobalKey _targetLineKey = GlobalKey();
  bool _didScrollToTarget = false;

  // ── _buildBody memoization ────────────────────────────────────────
  // Avoid rebuilding PreviewContent on every DraggableScrollableSheet
  // builder call triggered by keyboard viewInsets animation frames.
  Widget? _cachedBody;
  LinkedParagraphContent? _cachedBodyContent;
  bool _cachedBodyIsLoading = true;
  String? _cachedBodyError;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final db = await ref.read(epitakaDbProvider.future);
      final settings = ref.read(settingsProvider);

      // Gather the translation databases for the enabled languages
      final enabledLangs = settings.enabledTranslations.isNotEmpty
          ? settings.enabledTranslations.toList()
          : (settings.showTranslation
                ? [settings.primaryTranslationLang]
                : <String>[]);

      final transDbs = <String, TranslationDatabase>{};
      for (final langCode in enabledLangs) {
        try {
          final transDb = await ref.read(translationDbProvider(langCode).future);
          if (transDb != null) {
            transDbs[langCode] = transDb;
          }
        } catch (_) {
          // Skip unavailable translation dbs
        }
      }

      final service = BookLinkService(db);
      final content = await service.getLinkedContent(
        widget.link.linkedBookId,
        widget.link.linkedParaId,
        translationDbs: transDbs.isNotEmpty ? transDbs : null,
      );
      if (mounted) {
        setState(() {
          _content = content;
          _isLoading = false;
        });
        _scrollToTarget();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToTarget() {
    if (_didScrollToTarget) return;
    final content = _content;
    if (content == null) return;
    // Only scroll if the target paragraph is actually part of the rendered
    // section (it always is, since the section is built around linkedParaId).
    final hasTarget = content.lines.any(
      (l) => l.paraId == widget.link.linkedParaId,
    );
    if (!hasTarget) return;
    _didScrollToTarget = true;
    // Wait for the frame so the target widget is laid out before scrolling.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _targetLineKey;
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.25,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final link = widget.link;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.78,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(
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

            // ── Header (linked book name) ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.marginMobile,
                4,
                AppDimensions.marginMobile,
                0,
              ),
              child: _buildHeader(colors, link),
            ),

            const SizedBox(height: 4),
            const Divider(height: 1),

            // ── Content area ───────────────────────────────────────
            Expanded(child: _buildBody(colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colors, BookLinkData link) {
    final loc = AppLocalizations.of(context);
    final bookName = _content?.bookName ?? link.linkedBookId;

    return Row(
      children: [
        Icon(Icons.bookmark_border, size: 16, color: colors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bookName,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${loc.linkedFrom} “${link.word}”',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // ── Open book in tab button ──────────────────────────────
        TextButton.icon(
          onPressed: _content != null
              ? () {
                  ref
                      .read(readerTabsProvider.notifier)
                      .openTab(
                        ReaderTabInfo(
                          bookId: link.linkedBookId,
                          bookName: _content!.bookName,
                          initialParaId: link.linkedParaId,
                          initialLineId: link.linkedLineId,
                        ),
                      );
                  Navigator.of(context).pop();
                  context.push('/reader');
                }
              : null,
          icon: const Icon(Icons.open_in_new, size: 14),
          label: Text(loc.open, style: const TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: colors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _buildBody(ColorScheme colors) {
    final loc = AppLocalizations.of(context);
    // Memoization: return cached widget if data hasn't changed.
    // This prevents PreviewContent from being rebuilt on every
    // keyboard viewInsets animation frame while the sheet is open.
    // Must check _cachedBody != null — on the very first call all
    // state fields match the initial (null/true) values but the
    // body hasn't been built yet.
    if (_cachedBody != null &&
        identical(_cachedBodyContent, _content) &&
        _cachedBodyIsLoading == _isLoading &&
        _cachedBodyError == _error) {
      return _cachedBody!;
    }

    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '${loc.couldNotLoadLinked}\n$_error',
            style: AppTypography.bodyTranslation.copyWith(color: colors.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (_content == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            loc.linkedParaNotFound,
            style: AppTypography.bodyTranslation.copyWith(
              color: colors.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    } else {
      final content = _content!;
      // Convert linked content lines to PreviewLineData.
      final previewLines = content.lines.map((line) {
        return PreviewLineData(
          paraId: line.paraId,
          lineId: line.lineId,
          pali: line.paliText,
          translations: line.translations,
        );
      }).toList();

      body = SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppDimensions.marginMobile,
          AppDimensions.sm,
          AppDimensions.marginMobile,
          32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Heading ──────────────────────────────────────
            if (content.headingTitle != null) ...[
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
                content.headingTitle!,
                null,
                style: content.headingLevel != null && content.headingLevel! <= 2
                    ? AppTypography.headlineSmall.copyWith(color: colors.primary)
                    : AppTypography.bodyPali.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Preview lines with reader typography ────────
            PreviewContent(
              lines: previewLines,
              highlightParaId: content.paraId,
              firstSnippetIndex: 0,
              scrollToParaId: widget.link.linkedParaId,
              scrollToLineId: widget.link.linkedLineId,
              targetLineKey: _targetLineKey,
              onPaliWordTap: (word) {
                _showDictionary(context, word);
              },
            ),

            const SizedBox(height: 20),

            // ── Line ref badge ──────────────────────────────
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'para ${content.paraId} · line ${widget.link.linkedLineId}',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Cache for next time.
    _cachedBody = body;
    _cachedBodyContent = _content;
    _cachedBodyIsLoading = _isLoading;
    _cachedBodyError = _error;
    return body;
  }

  void _showDictionary(BuildContext context, String word) {
    showDictionarySheet(context, word.trim());
  }
}
