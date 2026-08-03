import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_localizations.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/tts_replacements_provider.dart';
import '../widgets/settings_app_bar.dart';

class TtsReplacementsScreen extends ConsumerStatefulWidget {
  const TtsReplacementsScreen({super.key});
  @override ConsumerState<TtsReplacementsScreen> createState() => _TtsReplacementsScreenState();
}

class _TtsReplacementsScreenState extends ConsumerState<TtsReplacementsScreen> {
  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(ttsReplacementsNotifierProvider.notifier).load()); }

  @override Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme; final loc = AppLocalizations.of(context); final replacementsAsync = ref.watch(ttsReplacementsNotifierProvider);
    return Scaffold(
      appBar: SettingsAppBar(colors: colors),
      body: ListView(padding: const EdgeInsets.fromLTRB(AppDimensions.marginMobile, AppDimensions.md, AppDimensions.marginMobile, 120), children: [
        Text(loc.ttsReplacements, style: AppTypography.headlineLarge.copyWith(color: colors.onSurface)),
        const SizedBox(height: AppDimensions.sm),
        Text(loc.ttsReplacementsDesc, style: AppTypography.labelMedium.copyWith(color: colors.onSurfaceVariant)),
        const SizedBox(height: AppDimensions.lg),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _showEditDialog(context, null), icon: const Icon(Icons.add, size: 18), label: Text(loc.addReplacement))),
        const SizedBox(height: AppDimensions.md),
        replacementsAsync.when(
          data: (rules) => rules.isEmpty
            ? Padding(padding: const EdgeInsets.all(AppDimensions.xl), child: Center(child: Text(loc.noReplacementRules, textAlign: TextAlign.center, style: AppTypography.labelMedium.copyWith(color: colors.onSurfaceVariant))))
            : Column(children: [for (final rule in rules) ...[_ReplacementCard(rule: rule, colors: colors, onEdit: () => _showEditDialog(context, rule),
                onToggle: (enabled) => ref.read(ttsReplacementsNotifierProvider.notifier).toggle(rule.id, enabled),
                onDelete: () => _confirmDelete(context, rule)), const SizedBox(height: AppDimensions.sm)]]),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('${loc.error} $e', style: AppTypography.labelMedium.copyWith(color: colors.error))),
        ),
      ]),
    );
  }

  Future<void> _showEditDialog(BuildContext context, TtsReplacement? existing) async { final loc = AppLocalizations.of(context);
    final result = await showDialog<_EditResult>(context: context, builder: (ctx) => _ReplacementEditDialog(existing: existing, colors: Theme.of(context).colorScheme, loc: loc));
    if (result == null || !mounted) return;
    final n = ref.read(ttsReplacementsNotifierProvider.notifier);
    if (existing != null) await n.update(existing.id, pattern: result.pattern, replacement: result.replacement, isRegex: result.isRegex, enabled: existing.enabled);
    else await n.add(pattern: result.pattern, replacement: result.replacement, isRegex: result.isRegex);
  }

  void _confirmDelete(BuildContext context, TtsReplacement rule) { final loc = AppLocalizations.of(context);
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(loc.deleteReplacementRule), content: Text('${loc.deleteReplacementConfirm}\n\n"${rule.pattern}" → "${rule.replacement}"'),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(loc.cancel)), FilledButton(onPressed: () { Navigator.of(ctx).pop(); ref.read(ttsReplacementsNotifierProvider.notifier).delete(rule.id); },
        style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), child: Text(loc.delete))]));
  }
}

class _ReplacementCard extends StatelessWidget {
  final TtsReplacement rule; final ColorScheme colors; final VoidCallback onEdit; final ValueChanged<bool> onToggle; final VoidCallback onDelete;
  const _ReplacementCard({required this.rule, required this.colors, required this.onEdit, required this.onToggle, required this.onDelete});

  @override Widget build(BuildContext context) {
    return Container(decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(AppDimensions.radiusMd), border: Border.all(color: rule.enabled ? colors.outlineVariant : colors.outline.withValues(alpha: 0.3))),
      child: InkWell(onTap: onEdit, borderRadius: BorderRadius.circular(AppDimensions.radiusMd), child: Padding(padding: const EdgeInsets.all(AppDimensions.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(rule.isRegex ? Icons.code : Icons.text_fields, size: 18, color: rule.enabled ? colors.primary : colors.onSurfaceVariant), const SizedBox(width: AppDimensions.sm),
          Expanded(child: Text(rule.isRegex ? 'Regex' : 'Text', style: AppTypography.labelSmall.copyWith(color: colors.primary, fontWeight: FontWeight.w600))),
          Switch(value: rule.enabled, onChanged: onToggle),
          IconButton(icon: Icon(Icons.delete_outline, color: colors.error, size: 20), onPressed: onDelete, padding: EdgeInsets.zero, constraints: const BoxConstraints(), visualDensity: VisualDensity.compact)]),
        const SizedBox(height: AppDimensions.sm),
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm, vertical: AppDimensions.xs), decoration: BoxDecoration(color: colors.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
          child: Text(rule.pattern, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.labelMedium.copyWith(color: rule.enabled ? colors.onSurface : colors.onSurfaceVariant, fontFamily: 'monospace', fontSize: 13))),
        const SizedBox(height: 4), Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.arrow_downward, size: 14, color: colors.onSurfaceVariant)), const SizedBox(height: 4),
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm, vertical: AppDimensions.xs), decoration: BoxDecoration(color: colors.primaryContainer.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
          child: Text(rule.replacement, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.labelMedium.copyWith(color: rule.enabled ? colors.onSurface : colors.onSurfaceVariant, fontFamily: 'monospace', fontSize: 13))),
      ]))));
  }
}

class _EditResult { final String pattern; final String replacement; final bool isRegex; const _EditResult({required this.pattern, required this.replacement, required this.isRegex}); }

class _ReplacementEditDialog extends StatefulWidget {
  final TtsReplacement? existing; final ColorScheme colors; final AppLocalizations loc;
  const _ReplacementEditDialog({this.existing, required this.colors, required this.loc});
  @override State<_ReplacementEditDialog> createState() => _ReplacementEditDialogState();
}

class _ReplacementEditDialogState extends State<_ReplacementEditDialog> {
  late final TextEditingController _patternCtrl; late final TextEditingController _replacementCtrl; late bool _isRegex; bool _isValid = false;

  @override void initState() { super.initState(); _patternCtrl = TextEditingController(text: widget.existing?.pattern ?? ''); _replacementCtrl = TextEditingController(text: widget.existing?.replacement ?? ''); _isRegex = widget.existing?.isRegex ?? false; _validate(); _patternCtrl.addListener(_validate); _replacementCtrl.addListener(_validate); }
  void _validate() { setState(() => _isValid = _patternCtrl.text.trim().isNotEmpty); }
  @override void dispose() { _patternCtrl.dispose(); _replacementCtrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) { final loc = widget.loc; final isEditing = widget.existing != null;
    return AlertDialog(
      title: Text(isEditing ? loc.editReplacement : loc.addReplacementTitle),
      content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.code, size: 18, color: widget.colors.primary), const SizedBox(width: 8), Text(loc.useRegex), const Spacer(), Switch(value: _isRegex, onChanged: (v) => setState(() => _isRegex = v))]),
        const SizedBox(height: AppDimensions.md),
        Text(loc.find, style: AppTypography.labelSmall.copyWith(color: widget.colors.onSurfaceVariant)), const SizedBox(height: 4),
        TextField(controller: _patternCtrl, autofocus: true, maxLines: 2,
          decoration: InputDecoration(hintText: _isRegex ? r'e.g., (\w+)ti$' : 'e.g., evaṃ me sutaṃ', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), isDense: true)),
        const SizedBox(height: AppDimensions.md),
        Text(loc.replaceWith, style: AppTypography.labelSmall.copyWith(color: widget.colors.onSurfaceVariant)), const SizedBox(height: 4),
        TextField(controller: _replacementCtrl, maxLines: 2, decoration: InputDecoration(hintText: _isRegex ? r'e.g., $1' : 'e.g., thus have i heard', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), isDense: true)),
        if (_isRegex) ...[const SizedBox(height: AppDimensions.sm), Text(loc.regexUsesDart, style: AppTypography.labelSmall.copyWith(color: widget.colors.onSurfaceVariant, fontSize: 11))],
      ])),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(loc.cancel)),
        FilledButton(onPressed: _isValid ? () => Navigator.of(context).pop(_EditResult(pattern: _patternCtrl.text.trim(), replacement: _replacementCtrl.text.trim(), isRegex: _isRegex)) : null, child: Text(isEditing ? loc.update : loc.add))]);
  }
}
