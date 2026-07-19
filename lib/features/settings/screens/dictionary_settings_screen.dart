import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_localizations.dart';
import '../../../core/providers/dictionary_books_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_section.dart';

class DictionarySettingsScreen extends ConsumerWidget {
  const DictionarySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final booksAsync = ref.watch(dictionaryBooksNotifierProvider);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: SettingsAppBar(colors: colors),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.marginMobile,
          AppDimensions.md,
          AppDimensions.marginMobile,
          120,
        ),
        children: [
          Text(
            loc.dictionarySettings,
            style: AppTypography.headlineLarge.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            loc.dictionarySettingDesc,
            style: AppTypography.bodyTranslation.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          booksAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${loc.errorLoadingDict} $e',
                  style: AppTypography.labelSmall.copyWith(color: colors.error),
                ),
              ),
            ),
            data: (books) {
              final enabledBooks = books.where((b) => b.userChoice).toList();
              final disabledBooks = books.where((b) => !b.userChoice).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsSection(
                    title: loc.enabledDictionaries,
                    colors: colors,
                    children: [
                      if (enabledBooks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(AppDimensions.md),
                          child: Text(
                            loc.noDictEnabled,
                            style: AppTypography.labelSmall.copyWith(
                              color: colors.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        children: enabledBooks
                            .asMap()
                            .entries
                            .map(
                              (entry) => _DictionaryBookTile(
                                key: ValueKey('enabled-${entry.value.id}'),
                                book: entry.value,
                                index: entry.key,
                                colors: colors,
                                isEnabled: true,
                                showDragHandle: true,
                                onToggle: () => ref
                                    .read(
                                      dictionaryBooksNotifierProvider.notifier,
                                    )
                                    .toggleEnabled(entry.value.id, false),
                              ),
                            )
                            .toList(),
                        onReorderItem: (int oldIndex, int newIndex) {
                          // NOTE: onReorderItem already returns the FINAL index
                          // (Flutter adjusts newIndex for the removed item). Do NOT
                          // decrement newIndex here — doing so double-adjusts and
                          // breaks single-step moves (e.g. drag item 1 to slot 2
                          // would snap back). See ReorderableListView docs.
                          final ids = enabledBooks.map((b) => b.id).toList();
                          final item = ids.removeAt(oldIndex);
                          ids.insert(newIndex, item);
                          ids.addAll(disabledBooks.map((b) => b.id));
                          ref
                              .read(dictionaryBooksNotifierProvider.notifier)
                              .reorder(ids);
                        },
                      ),
                    ],
                  ),
                  if (disabledBooks.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.md),
                    SettingsSection(
                      title: loc.disabledDictionaries,
                      colors: colors,
                      children: disabledBooks
                          .map(
                            (book) => _DictionaryBookTile(
                              key: ValueKey('disabled-${book.id}'),
                              book: book,
                              index: book.userOrder,
                              colors: colors,
                              isEnabled: false,
                              showDragHandle: false,
                              onToggle: () => ref
                                  .read(
                                    dictionaryBooksNotifierProvider.notifier,
                                  )
                                  .toggleEnabled(book.id, true),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DictionaryBookTile extends StatelessWidget {
  final DictionaryBook book;
  final int index;
  final ColorScheme colors;
  final bool isEnabled;
  final bool showDragHandle;
  final VoidCallback onToggle;
  const _DictionaryBookTile({
    super.key,
    required this.book,
    required this.index,
    required this.colors,
    required this.isEnabled,
    required this.showDragHandle,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          if (showDragHandle)
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.drag_handle,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
              ),
            )
          else
            const SizedBox(width: 28),
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isEnabled ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isEnabled ? colors.primary : colors.outlineVariant,
                  width: 1.5,
                ),
              ),
              child: isEnabled
                  ? Icon(Icons.check, size: 14, color: colors.onPrimary)
                  : null,
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.name,
                  style: AppTypography.labelMedium.copyWith(
                    color: isEnabled
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                    fontWeight: isEnabled ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '#${index + 1}',
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
