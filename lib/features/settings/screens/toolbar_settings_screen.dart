import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/toolbar_item.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../widgets/settings_app_bar.dart';

/// Settings screen for the reader's bottom toolbar.
///
/// Lets the user toggle which actions appear (contents, search, dictionary,
/// jump, display layout, listen, bookmark, …) and drag them into their
/// preferred order.
class ToolbarSettingsScreen extends StatelessWidget {
  const ToolbarSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: SettingsAppBar(colors: colors),
      body: const ToolbarSettingsBody(),
    );
  }
}

/// Scrollable body of the toolbar settings — shared between the mobile
/// screen and the desktop settings window.
class ToolbarSettingsBody extends ConsumerWidget {
  const ToolbarSettingsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final items = ref.watch(settingsProvider).toolbarItems;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.md,
        AppDimensions.marginMobile,
        120,
      ),
      children: [
        Text(
          loc.toolbar,
          style: AppTypography.headlineLarge.copyWith(color: colors.onSurface),
        ),
        const SizedBox(height: AppDimensions.sm),
        Text(
          loc.toolbarDesc,
          style: AppTypography.labelMedium.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppDimensions.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                loc.toolbarHint,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            IconButton.outlined(
              tooltip: loc.resetToDefault,
              icon: const Icon(Icons.restart_alt, size: 20),
              onPressed: () => _confirmReset(context, ref),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        ReorderableListView.builder(
          buildDefaultDragHandles: false,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          onReorderItem: (oldIndex, newIndex) {
            final list = List<ToolbarItem>.from(items);
            final item = list.removeAt(oldIndex);
            list.insert(newIndex, item);
            ref.read(settingsProvider.notifier).setToolbarItems(list);
          },
          itemBuilder: (context, index) {
            final item = items[index];
            return _ToolbarItemRow(
              key: ValueKey(item.id),
              index: index,
              item: item,
              colors: colors,
              loc: loc,
              onToggle: (enabled) => ref
                  .read(settingsProvider.notifier)
                  .setToolbarItemEnabled(item.id, enabled),
            );
          },
        ),
      ],
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.resetToDefault),
        content: Text(loc.resetToolbarConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(loc.resetToDefault),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(settingsProvider.notifier).resetToolbarItems();
    }
  }
}

/// A single reorderable row in the toolbar item list.
class _ToolbarItemRow extends StatelessWidget {
  final ToolbarItem item;
  final int index;
  final ColorScheme colors;
  final AppLocalizations loc;
  final ValueChanged<bool> onToggle;

  const _ToolbarItemRow({
    super.key,
    required this.index,
    required this.item,
    required this.colors,
    required this.loc,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, label) = _itemInfo(item.id, loc);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.xs),
      child: Material(
        color: item.enabled
            ? colors.surfaceContainerLow
            : colors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: item.enabled
                  ? colors.outlineVariant
                  : colors.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              // Drag handle
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.sm),
                  child: Icon(
                    Icons.drag_indicator,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                icon,
                size: 20,
                color: item.enabled ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(
                    color: item.enabled
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Switch(value: item.enabled, onChanged: onToggle),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, String) _itemInfo(String id, AppLocalizations loc) {
    switch (id) {
      case ToolbarBuiltins.contents:
        return (Icons.format_list_bulleted, loc.contents);
      case ToolbarBuiltins.outline:
        return (Icons.account_tree_outlined, loc.outline);
      case ToolbarBuiltins.search:
        return (Icons.search, loc.search);
      case ToolbarBuiltins.dictionary:
        return (Icons.menu_book, loc.dictionary);
      case ToolbarBuiltins.jump:
        return (Icons.open_in_new, loc.jumpLabel);
      case ToolbarBuiltins.displayLayout:
        return (Icons.view_headline, loc.displayLayout);
      case ToolbarBuiltins.listen:
        return (Icons.volume_up, loc.toolbarListen);
      case ToolbarBuiltins.bookmark:
        return (Icons.bookmark, loc.bookmark);
      case ToolbarBuiltins.annotations:
        return (Icons.edit_note, loc.annotations);
      default:
        return (Icons.touch_app, id);
    }
  }
}
