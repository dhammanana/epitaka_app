import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_localizations.dart';

/// Height of one history card, margin included. Hosts scroll the highlighted
/// card into view by this number, so every card is drawn at exactly this height.
const double kHistoryRowHeight = 60;

/// The title of every history card, the size the History tab uses. A card is
/// a fixed height, so a title in a bigger font would overflow it.
TextStyle historyTitleStyle(ColorScheme colors) => AppTypography.bodyTranslation
    .copyWith(
      color: colors.onSurface,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );

class HistoryItem {
  const HistoryItem({
    required this.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.onDelete,
  });

  final String key;
  final Widget title;
  final VoidCallback onTap;

  /// A grey line under the title (Go to sutta shows the sutta code).
  final Widget? subtitle;

  /// The trash button shows only when this is given.
  final VoidCallback? onDelete;
}

/// A history as full-width rows. It has no tap meaning of its own: each box
/// passes what a tap does. [items] come newest first. Put it in a `Flexible`
/// or `Expanded`: the list scrolls inside whatever height it is given.
class HistoryList extends StatelessWidget {
  const HistoryList({
    super.key,
    required this.items,
    this.title,
    this.onClear,
    this.onClose,
    this.selectedIndex,
    this.controller,
  });

  final List<HistoryItem> items;

  /// Null draws no header at all (the dictionary has its own).
  final String? title;
  final VoidCallback? onClear;

  /// A close button in the header, for a list that opens over something.
  final VoidCallback? onClose;
  final int? selectedIndex;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 4, 2),
            child: Row(
              children: [
                Icon(Icons.history, size: 14, color: colors.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title!,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onClear != null)
                  TextButton(
                    onPressed: onClear,
                    child: Text(loc.clearHistory),
                  ),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    tooltip: loc.closePanel,
                    onPressed: onClose,
                  ),
              ],
            ),
          ),
        Flexible(
          child: ListView.builder(
            controller: controller,
            shrinkWrap: true,
            itemExtent: kHistoryRowHeight,
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              final selected = i == selectedIndex;
              // The same card the History tab draws for each entry.
              return Padding(
                key: ValueKey(item.key),
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: Material(
                  color: selected
                      ? colors.primaryContainer
                      : colors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    side: BorderSide(color: colors.outlineVariant, width: 0.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: item.onTap,
                    hoverColor: colors.onSurface.withValues(alpha: 0.08),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: colors.tertiaryContainer.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.history,
                            size: 14,
                            color: colors.tertiary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DefaultTextStyle.merge(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                child: item.title,
                              ),
                              if (item.subtitle != null)
                                DefaultTextStyle.merge(
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                  child: item.subtitle!,
                                ),
                            ],
                          ),
                        ),
                        if (item.onDelete != null)
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: colors.error.withValues(alpha: 0.6),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            onPressed: item.onDelete,
                          )
                        else
                          const SizedBox(width: 12),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
