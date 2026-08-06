import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/utils/app_localizations.dart';

/// Shared font-size adjuster used by the reader's display popup and the
/// search screen's font-size popup.
///
/// Shows the current Pāli and (active) translation font sizes with −/+
/// buttons that call [SettingsNotifier.increaseFontSize]/decreaseFontSize,
/// so both sizes change together and the readout updates live.
class FontSizeAdjuster extends ConsumerWidget {
  const FontSizeAdjuster({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
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

    return Row(
      children: [
        _SizeButton(
          icon: Icons.remove,
          colors: colors,
          onTap: () => ref.read(settingsProvider.notifier).decreaseFontSize(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${loc.pali} $paliSize',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                if (transSize != null)
                  Text(
                    '${loc.translationWord} $transSize',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _SizeButton(
          icon: Icons.add,
          colors: colors,
          onTap: () => ref.read(settingsProvider.notifier).increaseFontSize(),
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
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
          ),
          child: Icon(icon, size: 22, color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}
