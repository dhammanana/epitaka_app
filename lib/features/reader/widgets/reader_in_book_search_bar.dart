import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/velthuis.dart';
import '../../../shared/utils/app_shortcuts.dart';
import '../../../shared/widgets/regex_toggle_button.dart';
import '../../../shared/widgets/velthuis_help_icon.dart';
import '../../../shared/widgets/search_box_decoration.dart';

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

  /// The box takes a regular expression (the rx button is on).
  final bool regexOn;
  final VoidCallback onToggleRegex;

  /// Why the submitted pattern does not compile, shown in place of the count.
  final String? patternError;

  /// The pattern ran past its time limit; shown in place of the count.
  final bool patternTooSlow;

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
    this.regexOn = false,
    required this.onToggleRegex,
    this.patternError,
    this.patternTooSlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final currentMatch = currentMatchIndex + 1; // 1-based display

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: kSearchBoxGap,
      ),
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
            // Its own height, like the Search box (spec J); a fixed 36 px
            // would clip the shared look.
            // A single-line field would only move the caret on ↑/↓, so
            // take them here to step the matches, like the results list.
            child: Focus(
              canRequestFocus: false,
              onKeyEvent: (_, event) {
                // With nothing to step to, leave the arrows to the field.
                if (matchCount == 0) return KeyEventResult.ignored;
                if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                  return KeyEventResult.ignored;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  onNext();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  onPrevious();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                // `.m`, `.t`, `.n` are regex: rx keeps them as typed.
                inputFormatters: regexOn
                    ? const []
                    : const [VelthuisInputFormatter()],
                textInputAction: TextInputAction.search,
                decoration: searchBoxDecoration(
                  context,
                  hintText: loc.findInBook,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Visibility(
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
                      if (!regexOn) const VelthuisHelpIcon(),
                      RegexToggleButton(on: regexOn, onToggle: onToggleRegex),
                    ],
                  ),
                ),
                style: searchBoxTextStyle(context),
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
          if (patternError != null || patternTooSlow)
            Tooltip(
              message: patternTooSlow
                  ? loc.patternTooSlow
                  : loc.invalidPattern(patternError!),
              child: ConstrainedBox(
                // Room for "Pattern too slow" whole (it was cut at 140);
                // a long invalid-pattern reason ends in "…", in full in
                // the tooltip.
                constraints: const BoxConstraints(maxWidth: 240),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    patternTooSlow
                        ? loc.patternTooSlow
                        : loc.invalidPattern(patternError!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.error,
                    ),
                  ),
                ),
              ),
            )
          else if (matchCount > 0)
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
