import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/app_models.dart';
import '../../../core/database/translation_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/utils/html_text_parser.dart';
import '../data/book_link_data.dart';
import '../providers/reader_tabs_provider.dart';
import '../services/book_link_service.dart';

/// Shows the bottom sheet with linked paragraph content.
///
/// Called when the user taps a book link chip. The sheet displays the
/// Pāli text of the linked paragraph (from the "other side" of the link),
/// scrolled to the linked line, with a heading near the top and a button
/// to open the full book in a new reader tab.  Pāli and translation text
/// support HTML tags (`<b>`, `<i>`, `<u>`, etc.).
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
          final lang = TranslationLanguage.fromCode(langCode);
          final transDb =
              await ref.read(translationDbProvider(lang).future);
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final link = widget.link;

    final settings = ref.watch(settingsProvider);
    final brightness = Theme.of(context).brightness;
    final paliColor = settings.paliColorPair.resolve(brightness);
    final transColor = settings.translationColorPair.resolve(brightness);

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
              margin: EdgeInsets.only(top: 8),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 8),

            // ── Header (linked book name) ──────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimensions.marginMobile,
                4,
                AppDimensions.marginMobile,
                0,
              ),
              child: _buildHeader(colors, link),
            ),

            SizedBox(height: 4),
            Divider(height: 1),

            // ── Content area ───────────────────────────────────────
            Expanded(
              child: _buildBody(
                colors,
                link,
                paliColor: paliColor,
                transColor: transColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colors, BookLinkData link) {
    final bookName = _content?.bookName ?? link.linkedBookId;

    return Row(
      children: [
        Icon(
          Icons.bookmark_border,
          size: 16,
          color: colors.primary,
        ),
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
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Linked from “${link.word}”',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        // ── Open book in tab button ──────────────────────────────
        TextButton.icon(
          onPressed: _content != null
              ? () {
                  ref.read(readerTabsProvider.notifier).openTab(
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
          label: const Text('Open', style: TextStyle(fontSize: 12)),
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

  Widget _buildBody(
    ColorScheme colors,
    BookLinkData link, {
    required Color paliColor,
    required Color transColor,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load linked content.\n$_error',
            style: AppTypography.bodyTranslation.copyWith(
              color: colors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final content = _content;
    if (content == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Linked paragraph not found.',
            style: AppTypography.bodyTranslation.copyWith(
              color: colors.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.sm,
        AppDimensions.marginMobile,
        32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Heading ──────────────────────────────────────────
          if (content.headingTitle != null) ...[
            Container(
              width: 32,
              height: 2,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            SizedBox(height: 6),
            Text(
              content.headingTitle!,
              style: TextStyle(
                fontSize: content.headingLevel != null && content.headingLevel! <= 2
                    ? 18
                    : 16,
                fontWeight: FontWeight.w600,
                fontFamily: AppTypography.paliFont,
                color: colors.primary,
                height: 1.3,
              ),
            ),
            SizedBox(height: 16),
          ],

          // ── Linked paragraph lines ──────────────────────────
          ...content.lines.map((line) {
            final isTargetLine = line.lineId == link.linkedLineId;

            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: 8,
                vertical: isTargetLine ? 10 : 6,
              ),
              margin: EdgeInsets.only(bottom: isTargetLine ? 6 : 4),
              decoration: BoxDecoration(
                color: isTargetLine
                    ? colors.primary.withValues(alpha: 0.07)
                    : null,
                borderRadius: BorderRadius.circular(6),
                border: isTargetLine
                    ? Border(
                        left: BorderSide(
                          color: colors.primary.withValues(alpha: 0.5),
                          width: 3,
                        ),
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Pali text (with HTML support) ──────────
                  HtmlTextParser.richText(
                    line.paliText,
                    AppTypography.bodyPali.copyWith(
                      color: paliColor,
                      fontSize: 15,
                      height: 1.7,
                      fontFamily: AppTypography.paliFont,
                    ),
                  ),

                  // ── Translation text (with HTML support) ──
                  if (line.translations.isNotEmpty) ...[
                    SizedBox(height: 4),
                    ...line.translations.entries.map((entry) {
                      return HtmlTextParser.richText(
                        entry.value,
                        AppTypography.bodyTranslation.copyWith(
                          color: transColor,
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                      );
                    }),
                  ],
                ],
              ),
          );
        }),

          SizedBox(height: 20),

          // ── Line ref badge ──────────────────────────────────
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'para ${content.paraId} · line ${link.linkedLineId}',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
