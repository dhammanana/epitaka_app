import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_db_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/reader_tabs_provider.dart';

/// Dialog to bookmark the current reading position.
///
/// Pre-fills the name field with a suggested name based on book name, page,
/// and nearby heading (Issue 1).
class BookmarkDialog extends ConsumerStatefulWidget {
  final String bookId;
  final String bookName;
  final String? pageNumber;

  /// Optional nearby heading title to suggest as bookmark name.
  final String? suggestedHeading;

  const BookmarkDialog({
    super.key,
    required this.bookId,
    required this.bookName,
    this.pageNumber,
    this.suggestedHeading,
  });

  @override
  ConsumerState<BookmarkDialog> createState() => _BookmarkDialogState();
}

class _BookmarkDialogState extends ConsumerState<BookmarkDialog> {
  late final TextEditingController _nameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final suggestedName = _buildSuggestedName();
    _nameController = TextEditingController(text: suggestedName);
    _nameController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _nameController.text.length,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);

    try {
      final db = await ref.read(appDbProvider.future);
      final tabsState = ref.read(readerTabsProvider);
      final activeTab = tabsState.activeTab;

      await db.addBookmark(
        name: name,
        bookId: widget.bookId,
        bookName: widget.bookName,
        pageNumber: widget.pageNumber,
        paraId: activeTab?.currentParaId,
        lineId: activeTab?.currentLineId,
      );

      // Invalidate the bookmarks provider so the library screen refreshes
      if (context.mounted) {
        ref.invalidate(bookmarksProvider);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bookmark saved: $name'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save bookmark: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Build a suggested bookmark name from available context.
  String _buildSuggestedName() {
    if (widget.suggestedHeading != null && widget.suggestedHeading!.isNotEmpty) {
      if (widget.pageNumber != null && widget.pageNumber!.isNotEmpty) {
        return '${widget.suggestedHeading} — p. ${widget.pageNumber}';
      }
      return '${widget.bookName} — ${widget.suggestedHeading}';
    }
    if (widget.pageNumber != null && widget.pageNumber!.isNotEmpty) {
      return '${widget.bookName} — p. ${widget.pageNumber}';
    }
    return widget.bookName;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      title: Row(
        children: [
          Icon(Icons.bookmark, color: colors.primary, size: 22),
          const SizedBox(width: 10),
          Text(
            'Add Bookmark',
            style: AppTypography.headlineSmall.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.bookName,
              style: AppTypography.bodyTranslation.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Bookmark name',
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: BorderSide(color: colors.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: AppTypography.bodyTranslation.copyWith(
                color: colors.onSurface,
              ),
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save, size: 18),
          label: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

/// Helper to show the bookmark dialog.
Future<bool?> showBookmarkDialog(
  BuildContext context, {
  required String bookId,
  required String bookName,
  String? pageNumber,
  String? suggestedHeading,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => BookmarkDialog(
      bookId: bookId,
      bookName: bookName,
      pageNumber: pageNumber,
      suggestedHeading: suggestedHeading,
    ),
  );
}
