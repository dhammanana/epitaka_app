// lib/features/annotations/widgets/annotations_panel.dart
//
// Self-contained list of the current book's annotations (highlights, notes,
// bookmarks) for the desktop sidebar and the mobile reader sheet.
//
// Each row shows the annotation's preview text with its highlight color;
// actions let the user change the color, edit the note (markdown), or delete
// it. Tapping a row jumps the reader to its paragraph.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../models/annotation.dart';
import '../providers/annotations_provider.dart';
import '../services/annotation_actions.dart';
import 'highlight_palette.dart';

/// Desktop sidebar panel (and mobile bottom sheet): all annotations for the
/// currently open book.
class AnnotationsPanel extends ConsumerWidget {
  /// Optional controller for the internal list. The mobile bottom sheet
  /// passes its [DraggableScrollableSheet] controller so drag-to-resize
  /// drives the list; null (desktop sidebar) uses the default. The panel
  /// must never be placed inside an unbounded-height parent (e.g. a bare
  /// ListView) — its internal [Expanded] needs bounded height.
  final ScrollController? scrollController;

  const AnnotationsPanel({super.key, this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final activeTab = ref.watch(readerTabsProvider).activeTab;

    if (activeTab == null) {
      return const _EmptyPanel();
    }

    final annotationsAsync = ref.watch(annotationsProvider(activeTab.bookId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(children: [
            Icon(Icons.edit_note, size: 14, color: colors.primary),
            const SizedBox(width: 6),
            Text(
              loc.annotations,
              style: AppTypography.labelMedium.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
        ),
        Expanded(
          child: annotationsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${loc.errorLoadingAnnotations} $e',
                style: AppTypography.bodyTranslation.copyWith(
                  color: colors.error,
                  fontSize: 13,
                ),
              ),
            ),
            data: (annotations) {
              if (annotations.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.edit_note,
                        size: 32,
                        color: colors.outlineVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc.noAnnotations,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyTranslation.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: annotations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final a = annotations[index];
                  return _AnnotationCard(
                    annotation: a,
                    onTap: () => _jumpToAnnotation(context, ref, a),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _jumpToAnnotation(BuildContext context, WidgetRef ref, Annotation a) {
    final paraId = a.paraId;
    if (paraId == null) return;
    final tabsNotifier = ref.read(readerTabsProvider.notifier);
    // openTab reuses an existing tab for the same book (setting its
    // initialParaId so the reader jumps) and creates one otherwise — exactly
    // the bookmark panel's jump behaviour.
    tabsNotifier.openTab(
      ReaderTabInfo(
        bookId: a.bookId,
        bookName: a.bookName ?? a.bookId,
        initialParaId: paraId,
        initialLineId: a.lineId,
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          loc.noBookOpenForAnnotations,
          textAlign: TextAlign.center,
          style: AppTypography.bodyTranslation.copyWith(
            color: colors.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _AnnotationCard extends ConsumerWidget {
  final Annotation annotation;
  final VoidCallback onTap;

  const _AnnotationCard({required this.annotation, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final a = annotation;

    final color = a.color?.color(context) ?? Colors.transparent;
    final isBookmark = a.isBookmark;
    final hasNote = a.hasNote;

    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Color / type indicator
              Container(
                width: 4,
                height: 38,
                decoration: BoxDecoration(
                  color: isBookmark ? colors.primary : color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isBookmark)
                      Text(
                        a.name ?? a.bookId,
                        style: AppTypography.bodyTranslation.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    else ...[
                      Text(
                        a.displayLabel(),
                        style: AppTypography.bodyTranslation.copyWith(
                          fontSize: 13.5,
                          color: colors.onSurface,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasNote)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            children: [
                              Icon(
                                Icons.sticky_note_2_outlined,
                                size: 12,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                a.note!.trim().split('\n').first,
                                style: AppTypography.labelSmall.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                    ],
                    // Location line
                    const SizedBox(height: 3),
                    Text(
                      '${a.bookName ?? a.bookId} · ${a.paraId ?? '—'}',
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                        fontSize: 10.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Actions
              if (!isBookmark) ...[
                _IconAction(
                  icon: Icons.palette_outlined,
                  tooltip: loc.changeColor,
                  onTap: () => _changeColor(context, ref),
                ),
                const SizedBox(width: 2),
              ],
              _IconAction(
                icon: hasNote ? Icons.edit_note : Icons.sticky_note_2_outlined,
                tooltip: hasNote ? loc.editNote : loc.addNote,
                onTap: () => _editNote(context, ref),
              ),
              const SizedBox(width: 2),
              _IconAction(
                icon: Icons.delete_outline,
                tooltip: loc.delete,
                onTap: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeColor(BuildContext context, WidgetRef ref) async {
    final newColor = await showHighlightColorPalette(
      context,
      anchor: const Offset(0, 0),
      initialColor: annotation.color,
    );
    if (newColor == null || !context.mounted) return;
    final repo = await ref.read(annotationRepositoryProvider.future);
    await repo.update(annotation.copyWith(color: newColor));
  }

  Future<void> _editNote(BuildContext context, WidgetRef ref) async {
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;
    await AnnotationActions.showNoteEditor(
      context: context,
      ref: ref,
      bookId: activeTab.bookId,
      bookName: annotation.bookName ?? activeTab.bookName,
      selection: null,
      visibleStartIndex: 0,
      visibleEndIndex: 0,
      existingNote: annotation.note ?? '',
      annotationId: annotation.id,
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.deleteAnnotation),
        content: Text(
          annotation.isBookmark
              ? loc.deleteAnnotationBookmarkMsg
              : loc.deleteAnnotationMsg,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(loc.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final repo = await ref.read(annotationRepositoryProvider.future);
    await repo.delete(annotation.id);
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            icon,
            size: 16,
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
