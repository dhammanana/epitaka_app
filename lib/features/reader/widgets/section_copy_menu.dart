import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/copy_types.dart';
import '../providers/reader_provider.dart';
import '../services/section_copy_service.dart';

/// Vertical `⋮` button shown on headings with `level < 10`.
///
/// Opens a dropdown to copy the whole section (from the heading's
/// `para_id` for `chapter_len` paragraphs) as Pāli only, translation
/// only, or both — optionally with commentaries resolved from the
/// `level = 10` headings under it via the linked (mula/attha/tika) books.
class SectionCopyMenuButton extends ConsumerWidget {
  final String bookId;
  final ParagraphHeading heading;

  const SectionCopyMenuButton({
    super.key,
    required this.bookId,
    required this.heading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return SelectionContainer.disabled(
      child: PopupMenuButton<int>(
        icon: Icon(
          Icons.more_vert,
          size: 18,
          color: colors.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        tooltip: 'Copy section',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onSelected: (value) => _onSelected(context, ref, value),
        itemBuilder: (context) => const [
          PopupMenuItem(value: 0, child: Text('Copy Pāli')),
          PopupMenuItem(value: 1, child: Text('Copy translation')),
          PopupMenuItem(value: 2, child: Text('Copy Pāli + translation')),
          PopupMenuDivider(),
          PopupMenuItem(value: 3, child: Text('Copy Pāli + commentaries')),
          PopupMenuItem(
            value: 4,
            child: Text('Copy translation + commentaries'),
          ),
          PopupMenuItem(
            value: 5,
            child: Text('Copy Pāli + translation + commentaries'),
          ),
        ],
      ),
    );
  }

  Future<void> _onSelected(
    BuildContext context,
    WidgetRef ref,
    int value,
  ) async {
    final scope = switch (value) {
      0 || 3 => CopyScope.pali,
      1 || 4 => CopyScope.translation,
      _ => CopyScope.both,
    };
    final withCommentaries = value >= 3;
    await SectionCopyService.copySection(
      ref: ref,
      context: context,
      bookId: bookId,
      heading: heading,
      scope: scope,
      withCommentaries: withCommentaries,
    );
  }
}

/// Dropdown shown next to the book title to copy the whole sutta/book
/// as Pāli only, translation only, or both.
class BookCopyMenuButton extends ConsumerWidget {
  final String bookId;

  const BookCopyMenuButton({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return SelectionContainer.disabled(
      child: PopupMenuButton<int>(
        icon: Icon(
          Icons.arrow_drop_down_circle_outlined,
          size: 20,
          color: colors.onSurfaceVariant.withValues(alpha: 0.8),
        ),
        tooltip: 'Copy book',
        onSelected: (value) => _onSelected(context, ref, value),
        itemBuilder: (context) => const [
          PopupMenuItem(value: 0, child: Text('Copy Pāli')),
          PopupMenuItem(value: 1, child: Text('Copy translation')),
          PopupMenuItem(value: 2, child: Text('Copy Pāli + translation')),
        ],
      ),
    );
  }

  Future<void> _onSelected(
    BuildContext context,
    WidgetRef ref,
    int value,
  ) async {
    final scope = switch (value) {
      0 => CopyScope.pali,
      1 => CopyScope.translation,
      _ => CopyScope.both,
    };
    await SectionCopyService.copyWholeBook(
      ref: ref,
      context: context,
      bookId: bookId,
      scope: scope,
    );
  }
}
