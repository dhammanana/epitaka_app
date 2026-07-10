library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/reader/providers/reader_tabs_provider.dart';
import '../models/ai_assistant_models.dart';
import '../services/tipitaka_search_service.dart';

Future<void> showSourceExcerptPopup(BuildContext context, SourceReference source) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SourceExcerptPopup(source: source),
  );
}

class _SourceExcerptPopup extends ConsumerStatefulWidget {
  final SourceReference source;
  const _SourceExcerptPopup({required this.source});

  @override
  ConsumerState<_SourceExcerptPopup> createState() => _SourceExcerptPopupState();
}

class _SourceExcerptPopupState extends ConsumerState<_SourceExcerptPopup> {
  Map<String, dynamic>? _paragraphData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadParagraph();
  }

  Future<void> _loadParagraph() async {
    try {
      final searchService = ref.read(tipitakaSearchServiceProvider);
      final data = await searchService.getParagraph(widget.source.bookId, widget.source.paraId);
      if (mounted) {
        setState(() { _paragraphData = data; _loading = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  void _openInReader() {
    Navigator.of(context).pop();
    ref.read(readerTabsProvider.notifier).openTab(
      ReaderTabInfo(
        bookId: widget.source.bookId,
        bookName: widget.source.bookName ?? widget.source.bookId,
        initialParaId: widget.source.paraId,
      ),
    );
    context.push('/reader');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final source = widget.source;

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusSheet)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.sm),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.format_quote, size: 16, color: colors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source.bookName ?? source.bookId,
                            style: AppTypography.bodyTranslation.copyWith(
                              color: colors.onSurface, fontWeight: FontWeight.w600, fontSize: 14,
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '\u00A7${source.paraId}:${source.lineId}',
                            style: AppTypography.labelSmall.copyWith(
                              color: colors.primary, fontSize: 11,
                              fontFamily: 'monospace', fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _openInReader,
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: Text('Open', style: AppTypography.labelSmall.copyWith(
                        fontSize: 11, fontWeight: FontWeight.w600,
                      )),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : _error != null ? _buildError(colors) : _buildContent(colors, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildError(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: colors.error),
            const SizedBox(height: 12),
            Text('Failed to load text', style: AppTypography.bodyTranslation.copyWith(
              color: colors.onSurface, fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 4),
            Text(_error!, style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant, fontSize: 12,
            ), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colors, ScrollController scrollController) {
    final paliText = _paragraphData?['pali'] as String? ?? '';
    final sentences = (_paragraphData?['sentences'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final source = widget.source;

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.menu_book, size: 16, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  source.bookName ?? source.bookId,
                  style: AppTypography.labelMedium.copyWith(color: colors.primary, fontWeight: FontWeight.w600),
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('\u00A7${source.paraId}:${source.lineId}',
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.primary, fontSize: 11,
                      fontFamily: 'monospace', fontWeight: FontWeight.w600,
                    )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (paliText.isNotEmpty) ...[
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('P\u0101li', style: AppTypography.labelSmall.copyWith(
                  color: colors.tertiary, fontSize: 10, fontWeight: FontWeight.w600,
                )),
              ),
            ]),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border(left: BorderSide(color: colors.tertiary.withValues(alpha: 0.4), width: 3)),
              ),
              child: SelectableText(
                paliText,
                style: AppTypography.bodyPali.copyWith(
                  color: colors.onSurface, fontFamily: 'NotoSerif', fontSize: 15, height: 1.7,
                ),
              ),
            ),
          ],
          if (sentences.length > 1) ...[
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.view_list, size: 14, color: colors.outline),
              const SizedBox(width: 6),
              Text('Line-by-line (${sentences.length} lines)',
                style: AppTypography.labelSmall.copyWith(color: colors.outline, fontSize: 11)),
            ]),
            const SizedBox(height: 8),
            ...sentences.map((s) => _LineRow(
              lineId: s['line_id'] as int? ?? 0,
              text: s['pali'] as String? ?? '',
              isHighlighted: s['line_id'] == source.lineId,
              colors: colors,
            )),
          ],
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  final int lineId;
  final String text;
  final bool isHighlighted;
  final ColorScheme colors;

  const _LineRow({
    required this.lineId, required this.text,
    required this.isHighlighted, required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isHighlighted ? colors.primaryContainer.withValues(alpha: 0.15) : colors.surface,
        borderRadius: BorderRadius.circular(4),
        border: isHighlighted ? Border.all(color: colors.primary.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text('$lineId', style: AppTypography.labelSmall.copyWith(
              color: isHighlighted ? colors.primary : colors.outline,
              fontSize: 11, fontFamily: 'monospace',
              fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w400,
            )),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppTypography.bodyPali.copyWith(
              color: colors.onSurface, fontFamily: 'NotoSerif', fontSize: 14, height: 1.5,
            )),
          ),
          if (isHighlighted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('cited', style: AppTypography.labelSmall.copyWith(
                color: colors.primary, fontSize: 9, fontWeight: FontWeight.w600,
              )),
            ),
        ],
      ),
    );
  }
}
