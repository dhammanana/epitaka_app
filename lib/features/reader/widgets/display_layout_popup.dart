import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../shared/widgets/font_size_adjuster.dart';

/// A compact popup card shown when tapping the layout toggle button in the
/// reader bottom toolbar. Displays three layout options (No translation,
/// Line by line, Side by side) and a font-size adjuster below.
class DisplayLayoutPopup extends ConsumerWidget {
  const DisplayLayoutPopup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final currentMode = settings.translationDisplayMode;
    final showTrans = settings.showTranslation;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                loc.display,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 4),

            // ── Layout options ───────────────────────────────────────────
            _LayoutOptionTile(
              icon: Icons.visibility_off,
              title: loc.displayNoTranslation,
              subtitle: loc.displayNoTranslationSubtitle,
              isSelected: !showTrans,
              onTap: () {
                ref.read(settingsProvider.notifier).setShowTranslation(false);
                Navigator.of(context).pop();
              },
            ),
            _LayoutOptionTile(
              icon: Icons.view_headline,
              title: loc.displayLineByLine,
              subtitle: loc.displayLineByLineSubtitle,
              isSelected: showTrans && currentMode == TranslationDisplayMode.lineByLine,
              onTap: () {
                ref.read(settingsProvider.notifier).setShowTranslation(true);
                ref
                    .read(settingsProvider.notifier)
                    .setTranslationDisplayMode(TranslationDisplayMode.lineByLine);
                Navigator.of(context).pop();
              },
            ),
            _LayoutOptionTile(
              icon: Icons.view_column,
              title: loc.displaySideBySide,
              subtitle: loc.displaySideBySideSubtitle,
              isSelected: showTrans && currentMode == TranslationDisplayMode.sideBySide,
              onTap: () {
                ref.read(settingsProvider.notifier).setShowTranslation(true);
                ref
                    .read(settingsProvider.notifier)
                    .setTranslationDisplayMode(TranslationDisplayMode.sideBySide);
                Navigator.of(context).pop();
              },
            ),

            // ── Divider ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: colors.outlineVariant.withValues(alpha: 0.2),
              ),
            ),

            // ── Show book links (temporary toggle) ───────────────────────
            _CheckboxTile(
              icon: Icons.link,
              title: loc.showBookLinks,
              value: settings.showBookLinks,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setShowBookLinksTemporary(v),
            ),

            // ── Divider ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: colors.outlineVariant.withValues(alpha: 0.2),
              ),
            ),

            // ── Font size ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Text(
                loc.fontSize,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FontSizeAdjuster(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// A checkbox-style toggle row (e.g. "Show book links") in the layout popup.
/// Toggling it applies immediately but does NOT persist — the reader toolbar
/// is meant for quick, temporary adjustments.
class _CheckboxTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CheckboxTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: colors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Icon(icon, size: 20, color: colors.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single layout option row with radio-style indicator.
class _LayoutOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _LayoutOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? colors.primary : colors.outline,
                  width: isSelected ? 2 : 1.5,
                ),
                color: isSelected
                    ? colors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Icon
            Icon(icon, size: 20, color: colors.onSurfaceVariant),
            const SizedBox(width: 10),
            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


