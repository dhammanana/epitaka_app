import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/pali_definition_provider.dart'
    show canonBookNamesProvider;
import '../../../core/utils/app_localizations.dart';
import '../providers/reader_columns_controller.dart';
import '../providers/reader_tabs_provider.dart';
import '../services/book_family_service.dart';

const _letters = {
  BookLevel.mula: 'm',
  BookLevel.attha: 'a',
  BookLevel.tika: 'ṭ',
};

const _levelNames = {
  BookLevel.mula: 'mūla',
  BookLevel.attha: 'aṭṭhakathā',
  BookLevel.tika: 'ṭīkā',
};

/// The m a ṭ buttons: show the active book's mūla, aṭṭhakathā or ṭīkā as a
/// column beside it, or as a tab where columns do not fit, from the
/// paragraph being read in the active tab.
///
/// The active book's own level is outlined, a level with no book is
/// greyed out, and a level already shown as a column is filled; pressing it
/// again closes that book. A level with several books opens a list.
class CommentaryLevelButtons extends ConsumerWidget {
  const CommentaryLevelButtons({super.key, this.enabled = true});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columnsFit = ref.watch(readerColumnsAvailableProvider);
    final tabs = ref.watch(readerTabsProvider);
    final active = tabs.activeTab;
    if (active == null) return const SizedBox.shrink();
    final family = ref.watch(activeBookFamilyProvider);
    final names = ref.watch(canonBookNamesProvider).valueOrNull ?? const {};
    final shown = columnsFit && tabs.columns.contains(active.bookId)
        ? tabs.columns
        : const <String>[];

    void open(String bookId) {
      ref
          .read(readerColumnsControllerProvider)
          .openFamilyColumn(bookId, sourceBookId: active.bookId);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final level in BookLevel.values)
          _LevelButton(
            level: level,
            books: family?.booksAt(level) ?? const [],
            isCurrent: family?.level == level,
            shownBookId: shown
                .where((id) => family?.booksAt(level).contains(id) ?? false)
                .firstOrNull,
            names: names,
            enabled: enabled,
            columnsFit: columnsFit,
            onOpen: open,
          ),
      ],
    );
  }
}

class _LevelButton extends StatelessWidget {
  const _LevelButton({
    required this.level,
    required this.books,
    required this.isCurrent,
    required this.shownBookId,
    required this.names,
    required this.enabled,
    required this.columnsFit,
    required this.onOpen,
  });

  final BookLevel level;
  final List<String> books;
  final bool isCurrent;
  final String? shownBookId;
  final Map<String, String> names;
  final bool enabled;
  final bool columnsFit;
  final void Function(String bookId) onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final available = enabled && !isCurrent && books.isNotEmpty;
    final shown = shownBookId != null && !isCurrent;

    final action = isCurrent
        ? loc.thisBook
        : books.isEmpty
        ? loc.noBookAtLevel
        : shown && books.length == 1
        ? loc.close
        : columnsFit
        ? loc.showBeside
        : loc.openInTab;
    final tooltip = '${_levelNames[level]} — $action';

    // Every state draws the same 30 px box, and a forced strut gives all
    // three letters one line height: the dot under Ṭ made its line taller,
    // and an underline for the current level sat lower than the boxes
    // (live test: "messy, different heights").
    final letter = Container(
      key: ValueKey('commentary-level-${level.name}'),
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: shown ? colors.primaryContainer : null,
        border: isCurrent
            ? Border.all(color: colors.primary, width: 1.2)
            : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _letters[level]!,
        textAlign: TextAlign.center,
        strutStyle: const StrutStyle(
          fontSize: 15,
          height: 1.2,
          forceStrutHeight: true,
        ),
        style: TextStyle(
          fontSize: 15,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: shown
              ? colors.onPrimaryContainer
              : isCurrent
              ? colors.primary
              : colors.onSurfaceVariant.withValues(alpha: available ? 1 : 0.3),
        ),
      ),
    );

    if (!available) return Tooltip(message: tooltip, child: letter);

    if (books.length == 1) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => onOpen(books.single),
          child: letter,
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: tooltip,
      onSelected: onOpen,
      itemBuilder: (context) => [
        for (final bookId in books)
          CheckedPopupMenuItem<String>(
            value: bookId,
            checked: bookId == shownBookId,
            child: Text(names[bookId] ?? bookId),
          ),
      ],
      child: letter,
    );
  }
}

/// The phone's m a ṭ: one toolbar slot that opens the family menu, because
/// the phone toolbar has no room for three letters (2026-10-31).
class CommentaryLevelsMenuButton extends ConsumerWidget {
  const CommentaryLevelsMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookId = ref.watch(
      readerTabsProvider.select((s) => s.activeTab?.bookId),
    );
    if (bookId == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: AppLocalizations.of(context).commentaryColumnsLabel,
      child: InkWell(
        key: const ValueKey('commentary-levels-menu'),
        borderRadius: BorderRadius.circular(9999),
        onTap: () {
          final box = context.findRenderObject()! as RenderBox;
          showFamilyBesideMenu(
            context: context,
            ref: ref,
            anchor: box.localToGlobal(Offset.zero),
            bookId: bookId,
          );
        },
        // Same 38 px footprint as the icon buttons beside it.
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            height: 22,
            child: Center(
              child: Text(
                'maṭ',
                strutStyle: const StrutStyle(
                  fontSize: 15,
                  height: 1.2,
                  forceStrutHeight: true,
                ),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lists the family books of [bookId] in a menu at the global [anchor] and
/// shows the chosen one beside it, matched to [sourceParaId].
///
/// The right-click route to the same action as the m a ṭ buttons, with the
/// same rules: the book's own level and empty levels cannot be chosen, and
/// a book already shown is checked (choosing it again closes it).
Future<void> showFamilyBesideMenu({
  required BuildContext context,
  required WidgetRef ref,
  required Offset anchor,
  required String bookId,
  int? sourceParaId,
}) async {
  // [context] is the selection toolbar's, which closes before the data
  // below has loaded; the menu belongs to the navigator under it.
  final navigator = Navigator.of(context);
  final loc = AppLocalizations.of(context);
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final family = await ref.read(bookFamilyProvider(bookId).future);
  final names = await ref.read(canonBookNamesProvider.future);
  if (!navigator.mounted) return;
  final tabs = ref.read(readerTabsProvider);
  final shown =
      ref.read(readerColumnsAvailableProvider) &&
          tabs.columns.contains(bookId)
      ? tabs.columns
      : const <String>[];

  final chosen = await showMenu<String>(
    context: navigator.context,
    position: RelativeRect.fromRect(
      anchor & Size.zero,
      Offset.zero & overlay.size,
    ),
    items: [
      for (final level in BookLevel.values)
        if (family == null || family.booksAt(level).isEmpty)
          PopupMenuItem<String>(
            enabled: false,
            child: Text('${_levelNames[level]} — ${loc.noBookAtLevel}'),
          )
        else if (family.level == level)
          PopupMenuItem<String>(
            enabled: false,
            child: Text('${_levelNames[level]} — ${loc.thisBook}'),
          )
        else
          for (final id in family.booksAt(level))
            CheckedPopupMenuItem<String>(
              value: id,
              checked: shown.contains(id),
              child: Text('${_levelNames[level]} — ${names[id] ?? id}'),
            ),
    ],
  );
  if (chosen == null) return;
  await ref
      .read(readerColumnsControllerProvider)
      .openFamilyColumn(
        chosen,
        sourceBookId: bookId,
        sourceParaId: sourceParaId,
      );
}
