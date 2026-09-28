import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/utils/app_localizations.dart';

/// Shared font-size adjuster used by the reader's display popup and the
/// search screen's font-size popup.
///
/// Shows the Pāli and translation sizes as two independent rows, each with
/// its own −/+ buttons so the user can tune them separately. Pāli calls
/// [SettingsNotifier.increasePaliFontSize]/decreasePaliFontSize; the
/// translation row calls increaseTranslationFontSize/decreaseTranslationFontSize,
/// which scale every visible translation in lockstep.
class FontSizeAdjuster extends ConsumerWidget {
  const FontSizeAdjuster({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final paliSize = settings.typography.pali.fontSize.round();

    // The translation language whose size is displayed — the first enabled
    // one, or the primary when none are enabled. Null when no translation is
    // shown.
    final visibleLangs = settings.visibleTranslationLangs;
    final transLang = visibleLangs.isEmpty ? null : visibleLangs.first;
    final transSize = transLang != null
        ? settings.typography.typographyFor(transLang).fontSize.round()
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FontSizeRow(
          label: loc.pali,
          size: paliSize,
          onDecrease: () =>
              ref.read(settingsProvider.notifier).decreasePaliFontSize(),
          onIncrease: () =>
              ref.read(settingsProvider.notifier).increasePaliFontSize(),
        ),
        const SizedBox(height: 8),
        if (transSize != null) ...[
          _FontSizeRow(
            label: loc.translationWord,
            size: transSize,
            onDecrease: () => ref
                .read(settingsProvider.notifier)
                .decreaseTranslationFontSize(),
            onIncrease: () => ref
                .read(settingsProvider.notifier)
                .increaseTranslationFontSize(),
          ),
        ],
      ],
    );
  }
}

/// One row of the font-size adjuster: `label  [−]  N  [+]`.
class _FontSizeRow extends StatelessWidget {
  final String label;
  final int size;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _FontSizeRow({
    required this.label,
    required this.size,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _SizeButton(
          icon: Icons.remove,
          colors: colors,
          onTap: onDecrease,
        ),
        Expanded(
          child: Text(
            '$size',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: colors.onSurface,
            ),
          ),
        ),
        _SizeButton(
          icon: Icons.add,
          colors: colors,
          onTap: onIncrease,
        ),
      ],
    );
  }
}

/// A small circular −/+ button used in the font-size adjuster.
class _SizeButton extends StatelessWidget {
  final IconData icon;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _SizeButton({
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9999),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
          ),
          child: Icon(icon, size: 20, color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}
