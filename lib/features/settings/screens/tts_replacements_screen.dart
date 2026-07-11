import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/tts_replacements_provider.dart';
import '../widgets/settings_app_bar.dart';

/// Screen for managing TTS regex replacement rules.
///
/// Users can add patterns to replace in Pali text before TTS reads it,
/// with support for plain text or regex replacements.
class TtsReplacementsScreen extends ConsumerStatefulWidget {
  const TtsReplacementsScreen({super.key});

  @override
  ConsumerState<TtsReplacementsScreen> createState() =>
      _TtsReplacementsScreenState();
}

class _TtsReplacementsScreenState
    extends ConsumerState<TtsReplacementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ttsReplacementsNotifierProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final replacementsAsync = ref.watch(ttsReplacementsNotifierProvider);

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
            'TTS Replacements',
            style: AppTypography.headlineLarge.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'Replace text patterns before TTS reads them aloud.',
            style: AppTypography.labelMedium.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),

          // Add new replacement button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showEditDialog(context, null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Replacement'),
            ),
          ),
          const SizedBox(height: AppDimensions.md),

          // List of replacements
          replacementsAsync.when(
            data: (rules) {
              if (rules.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppDimensions.xl),
                  child: Center(
                    child: Text(
                      'No replacement rules yet.\nTap "Add Replacement" to create one.',
                      textAlign: TextAlign.center,
                      style: AppTypography.labelMedium.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final rule in rules) ...[
                    _ReplacementCard(
                      rule: rule,
                      colors: colors,
                      onEdit: () => _showEditDialog(context, rule),
                      onToggle: (enabled) {
                        ref
                            .read(ttsReplacementsNotifierProvider.notifier)
                            .toggle(rule.id, enabled);
                      },
                      onDelete: () => _confirmDelete(context, rule),
                    ),
                    const SizedBox(height: AppDimensions.sm),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'Error loading replacements: $e',
                style: AppTypography.labelMedium.copyWith(
                  color: colors.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(
      BuildContext context, TtsReplacement? existing) async {
    final result = await showDialog<_EditResult>(
      context: context,
      builder: (ctx) => _ReplacementEditDialog(
        existing: existing,
        colors: Theme.of(context).colorScheme,
      ),
    );

    if (result == null || !mounted) return;

    final notifier = ref.read(ttsReplacementsNotifierProvider.notifier);
    if (existing != null) {
      await notifier.update(
        existing.id,
        pattern: result.pattern,
        replacement: result.replacement,
        isRegex: result.isRegex,
        enabled: existing.enabled,
      );
    } else {
      await notifier.add(
        pattern: result.pattern,
        replacement: result.replacement,
        isRegex: result.isRegex,
      );
    }
  }

  void _confirmDelete(BuildContext context, TtsReplacement rule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Replacement Rule?'),
        content: Text(
          'Are you sure you want to delete this rule?\n\n'
          '"${rule.pattern}" → "${rule.replacement}"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref
                  .read(ttsReplacementsNotifierProvider.notifier)
                  .delete(rule.id);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Replacement Card ─────────────────────────────────────────────────────

class _ReplacementCard extends StatelessWidget {
  final TtsReplacement rule;
  final ColorScheme colors;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _ReplacementCard({
    required this.rule,
    required this.colors,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: rule.enabled ? colors.outlineVariant : colors.outline.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    rule.isRegex ? Icons.code : Icons.text_fields,
                    size: 18,
                    color: rule.enabled ? colors.primary : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Text(
                      rule.isRegex ? 'Regex' : 'Text',
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Switch(
                    value: rule.enabled,
                    activeTrackColor: colors.primary,
                    onChanged: onToggle,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: colors.error, size: 20),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.sm),
              // Input pattern
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.sm,
                  vertical: AppDimensions.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Text(
                  rule.pattern,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(
                    color: rule.enabled
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Arrow down
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.arrow_downward,
                  size: 14,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              // Output replacement
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.sm,
                  vertical: AppDimensions.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Text(
                  rule.replacement,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(
                    color: rule.enabled
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Edit Dialog ─────────────────────────────────────────────────────────

class _EditResult {
  final String pattern;
  final String replacement;
  final bool isRegex;

  const _EditResult({
    required this.pattern,
    required this.replacement,
    required this.isRegex,
  });
}

class _ReplacementEditDialog extends StatefulWidget {
  final TtsReplacement? existing;
  final ColorScheme colors;

  const _ReplacementEditDialog({
    this.existing,
    required this.colors,
  });

  @override
  State<_ReplacementEditDialog> createState() =>
      _ReplacementEditDialogState();
}

class _ReplacementEditDialogState extends State<_ReplacementEditDialog> {
  late final TextEditingController _patternCtrl;
  late final TextEditingController _replacementCtrl;
  late bool _isRegex;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _patternCtrl = TextEditingController(text: widget.existing?.pattern ?? '');
    _replacementCtrl =
        TextEditingController(text: widget.existing?.replacement ?? '');
    _isRegex = widget.existing?.isRegex ?? false;
    _validate();
    _patternCtrl.addListener(_validate);
    _replacementCtrl.addListener(_validate);
  }

  void _validate() {
    setState(() {
      _isValid = _patternCtrl.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _patternCtrl.dispose();
    _replacementCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Replacement' : 'Add Replacement'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Regex toggle
            Row(
              children: [
                Icon(Icons.code, size: 18, color: widget.colors.primary),
                const SizedBox(width: 8),
                const Text('Use Regex'),
                const Spacer(),
                Switch(
                  value: _isRegex,
                  activeTrackColor: widget.colors.primary,
                  onChanged: (v) => setState(() => _isRegex = v),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),

            // Pattern input
            Text(
              'Find:',
              style: AppTypography.labelSmall.copyWith(
                color: widget.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _patternCtrl,
              autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: _isRegex
                    ? r'e.g., (\w+)ti$'
                    : 'e.g., evaṃ me sutaṃ',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppDimensions.md),

            // Replacement input
            Text(
              'Replace with:',
              style: AppTypography.labelSmall.copyWith(
                color: widget.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _replacementCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: _isRegex
                    ? r'e.g., $1'
                    : 'e.g., thus have i heard',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),

            if (_isRegex) ...[
              const SizedBox(height: AppDimensions.sm),
              Text(
                'Regex uses Dart RegExp syntax.',
                style: AppTypography.labelSmall.copyWith(
                  color: widget.colors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isValid
              ? () {
                  Navigator.of(context).pop(_EditResult(
                    pattern: _patternCtrl.text.trim(),
                    replacement: _replacementCtrl.text.trim(),
                    isRegex: _isRegex,
                  ));
                }
              : null,
          child: Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
