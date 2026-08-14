import 'package:flutter/material.dart';

import '../../../core/utils/app_localizations.dart';
import '../../../shared/utils/app_shortcuts.dart';

/// In-book search bar shown as an overlay at the top of the reader.
///
/// The search state (query, matches, controllers) lives in the owning
/// [ReaderScreen] state; this widget is a pure presentation layer that
/// reports user intent back through callbacks.
class ReaderInBookSearchBar extends StatelessWidget {
  final ColorScheme colors;
  final TextEditingController controller;
  final FocusNode focusNode;
  final int matchCount;
  final int currentMatchIndex;
  final String query;
  final VoidCallback onClose;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSearchEntire;

  const ReaderInBookSearchBar({
    super.key,
    required this.colors,
    required this.controller,
    required this.focusNode,
    required this.matchCount,
    required this.currentMatchIndex,
    required this.query,
    required this.onClose,
    required this.onQueryChanged,
    required this.onSubmitted,
    required this.onPrevious,
    required this.onNext,
    required this.onSearchEntire,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final currentMatch = currentMatchIndex + 1; // 1-based display

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          // Close button
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: colors.onSurfaceVariant,
            onPressed: onClose,
            tooltip: loc.closeSearch,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          // Search field
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: loc.findInBook,
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  isDense: true,
                  suffixIcon: Visibility(
                    visible: controller.text.isNotEmpty,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        controller.clear();
                        onQueryChanged('');
                      },
                    ),
                  ),
                ),
                style: TextStyle(fontSize: 14, color: colors.onSurface),
                onChanged: (v) {
                  // Debounce is handled by the caller via onQueryChanged.
                  onQueryChanged(v);
                },
                onSubmitted: onSubmitted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Match counter
          if (matchCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '$currentMatch/$matchCount',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else if (query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                loc.noResults,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.error.withValues(alpha: 0.7),
                ),
              ),
            ),
          // Previous match
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 22),
            color: matchCount > 0
                ? colors.onSurfaceVariant
                : colors.onSurfaceVariant.withValues(alpha: 0.3),
            onPressed: matchCount > 0 ? onPrevious : null,
            tooltip: loc.previousMatch,
            visualDensity: VisualDensity.compact,
          ),
          // Next match
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 22),
            color: matchCount > 0
                ? colors.onSurfaceVariant
                : colors.onSurfaceVariant.withValues(alpha: 0.3),
            onPressed: matchCount > 0 ? onNext : null,
            tooltip: loc.nextMatch,
            visualDensity: VisualDensity.compact,
          ),
          // Separator
          Container(
            width: 1,
            height: 20,
            color: colors.outlineVariant.withValues(alpha: 0.3),
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          // Search entire Tipiṭaka
          IconButton(
            icon: const Icon(Icons.open_in_full, size: 18),
            color: colors.primary,
            onPressed: onSearchEntire,
            tooltip: AppShortcuts.tooltip(
              loc.searchTipitakaFull,
              'find-everywhere',
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
