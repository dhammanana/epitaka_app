import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/context_menu_action.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/process_text_service.dart';
import '../widgets/settings_app_bar.dart';

/// Settings screen for the reader's text-selection context menu.
///
/// Lets the user:
///   • toggle which built-in actions appear (copy, excerpt, …),
///   • reorder them (drag the handle),
///   • add installed apps that can process selected text (discovered via
///     [ProcessTextService] — dictionaries, translators, …),
///   • add custom AI prompts that run the selected text through AI Q&A.
class ContextMenuSettingsScreen extends ConsumerStatefulWidget {
  const ContextMenuSettingsScreen({super.key});

  @override
  ConsumerState<ContextMenuSettingsScreen> createState() =>
      _ContextMenuSettingsScreenState();
}

class _ContextMenuSettingsScreenState
    extends ConsumerState<ContextMenuSettingsScreen> {
  bool _loadingApps = false;
  List<ProcessTextApp>? _installedApps;

  List<ContextMenuAction> get _actions =>
      ref.watch(settingsProvider).contextMenuActions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
            loc.contextMenu,
            style: AppTypography.headlineLarge.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            loc.contextMenuDesc,
            style: AppTypography.labelMedium.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _showAddPromptDialog(context),
                  icon: const Icon(Icons.smart_toy_outlined, size: 18),
                  label: Text(loc.addPrompt),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _loadInstalledApps,
                  icon: _loadingApps
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.apps, size: 18),
                  label: Text(loc.addApp),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          if (_actions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppDimensions.xl),
              child: Center(
                child: Text(
                  loc.noContextMenuActions,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _actions.length,
              onReorder: (oldIndex, newIndex) {
                final actions = List<ContextMenuAction>.from(_actions);
                if (newIndex > oldIndex) newIndex--;
                final item = actions.removeAt(oldIndex);
                actions.insert(newIndex, item);
                ref
                    .read(settingsProvider.notifier)
                    .setContextMenuActions(actions);
              },
              itemBuilder: (context, index) {
                final action = _actions[index];
                return _ActionRow(
                  key: ValueKey(action.id),
                  index: index,
                  action: action,
                  colors: colors,
                  loc: loc,
                  onToggle: (enabled) => ref
                      .read(settingsProvider.notifier)
                      .setContextMenuActionEnabled(action.id, enabled),
                  onEditPrompt: action.kind == ContextMenuActionKind.aiPrompt
                      ? () => _showAddPromptDialog(context, existing: action)
                      : null,
                  onRemove: action.kind == ContextMenuActionKind.builtin
                      ? null
                      : () => ref
                          .read(settingsProvider.notifier)
                          .removeContextMenuAction(action.id),
                );
              },
            ),
          const SizedBox(height: AppDimensions.md),
          if (_installedApps != null && _installedApps!.isNotEmpty) ...[
            Text(
              loc.installedApps,
              style: AppTypography.labelSmall.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimensions.sm),
            for (final app in _installedApps!) _buildInstalledAppRow(app),
          ],
        ],
      ),
    );
  }

  Widget _buildInstalledAppRow(ProcessTextApp app) {
    final colors = Theme.of(context).colorScheme;
    final added =
        _actions.any(
          (a) => a.kind == ContextMenuActionKind.externalApp &&
              a.appPackage == app.packageName,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.xs),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.extension_outlined, size: 20),
          title: Text(
            app.label,
            style: AppTypography.labelMedium.copyWith(color: colors.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            app.packageName,
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: added
              ? Icon(Icons.check_circle, color: colors.tertiary, size: 20)
              : IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  color: colors.primary,
                  onPressed: () {
                    ref
                        .read(settingsProvider.notifier)
                        .setContextMenuActions([
                          ..._actions,
                          ContextMenuAction(
                            id: 'app:${app.packageName}',
                            kind: ContextMenuActionKind.externalApp,
                            appPackage: app.packageName,
                            appLabel: app.label,
                          ),
                        ]);
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _loadInstalledApps() async {
    setState(() => _loadingApps = true);
    final apps = await ProcessTextService.queryApps();
    if (!mounted) return;
    setState(() {
      _loadingApps = false;
      _installedApps = apps;
    });
  }

  Future<void> _showAddPromptDialog(
    BuildContext context, {
    ContextMenuAction? existing,
  }) async {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final nameCtrl = TextEditingController(text: existing?.promptName ?? '');
    final promptCtrl = TextEditingController(text: existing?.prompt ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? loc.addPrompt : loc.editPrompt),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: loc.promptName,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              TextField(
                controller: promptCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: loc.prompt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  loc.promptPlaceholderHint,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(loc.save),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;
    final name = nameCtrl.text.trim();
    final prompt = promptCtrl.text.trim();
    if (name.isEmpty || prompt.isEmpty) return;

    final notifier = ref.read(settingsProvider.notifier);
    if (existing != null) {
      await notifier.updateContextMenuPrompt(
        existing.id,
        promptName: name,
        prompt: prompt,
      );
    } else {
      final actions = List<ContextMenuAction>.from(_actions);
      actions.add(
        ContextMenuAction(
          id: 'prompt:${DateTime.now().millisecondsSinceEpoch}',
          kind: ContextMenuActionKind.aiPrompt,
          promptName: name,
          prompt: prompt,
        ),
      );
      await notifier.setContextMenuActions(actions);
    }
  }
}

/// A single reorderable row in the context menu action list.
class _ActionRow extends StatelessWidget {
  final ContextMenuAction action;
  final int index;
  final ColorScheme colors;
  final AppLocalizations loc;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onEditPrompt;
  final VoidCallback? onRemove;

  const _ActionRow({
    super.key,
    required this.index,
    required this.action,
    required this.colors,
    required this.loc,
    required this.onToggle,
    this.onEditPrompt,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, label, subtitle) = switch (action.kind) {
      ContextMenuActionKind.builtin => _builtinInfo(action.builtinId, loc),
      ContextMenuActionKind.externalApp => (
        Icons.extension_outlined,
        action.appLabel ?? action.appPackage ?? '',
        loc.externalApp,
      ),
      ContextMenuActionKind.aiPrompt => (
        Icons.smart_toy_outlined,
        action.promptName ?? '',
        action.prompt ?? '',
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.xs),
      child: Material(
        color: action.enabled
            ? colors.surfaceContainerLow
            : colors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: action.enabled
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
                color: action.enabled
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.labelMedium.copyWith(
                        color: action.enabled
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (onEditPrompt != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: colors.onSurfaceVariant,
                  onPressed: onEditPrompt,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              if (onRemove != null)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: colors.error.withValues(alpha: 0.8),
                  ),
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              Switch(value: action.enabled, onChanged: onToggle),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, String, String) _builtinInfo(String? id, AppLocalizations loc) {
    switch (id) {
      case ContextMenuBuiltins.copy:
        return (Icons.copy, loc.copy, loc.copyDesc);
      case ContextMenuBuiltins.excerpt:
        return (Icons.format_quote, loc.excerpt, loc.excerptDesc);
      case ContextMenuBuiltins.copyLink:
        return (Icons.link, loc.copyLink, loc.copyLinkDesc);
      case ContextMenuBuiltins.dictionary:
        return (Icons.menu_book, loc.dictionary, loc.dictionaryDesc);
      case ContextMenuBuiltins.explain:
        return (Icons.auto_awesome, loc.explain, loc.explainDesc);
      case ContextMenuBuiltins.summarizeChapter:
        return (Icons.notes, loc.summarizeChapter, loc.summarizeChapterDesc);
      case ContextMenuBuiltins.share:
        return (Icons.share, loc.share, loc.shareDesc);
      default:
        return (Icons.touch_app, id ?? '', '');
    }
  }
}
