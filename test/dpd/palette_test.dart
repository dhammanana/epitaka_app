import 'package:epitaka/core/providers/settings_provider.dart'
    show ThemePreference;
import 'package:epitaka/core/theme/app_theme.dart';
import 'package:epitaka/features/dpd/theme/dpd_palette.dart';
import 'package:epitaka/features/dpd/theme/dpd_palette_from_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // No accent, then a pale and a dark accent: the two ways a user's accent
  // can fail to read as text.
  const accents = <Color?>[null, Color(0xFFFFEB3B), Color(0xFF1A237E)];

  for (final pref in ThemePreference.values) {
    for (final brightness in Brightness.values) {
      if (pref != ThemePreference.system && brightness == Brightness.dark) {
        continue;
      }
      for (final accent in accents) {
        final name = '${pref.name}'
            '${pref == ThemePreference.system ? '/${brightness.name}' : ''}'
            ' accent=${accent?.toARGB32().toRadixString(16) ?? 'none'}';

        test('$name: DPD text reads on its backgrounds', () {
          final theme = AppTheme.forPreference(
            pref,
            platformBrightness: brightness,
            accentColor: accent,
          );
          final palette = theme.extension<DpdPalette>()!;
          final isDark = theme.brightness == Brightness.dark;
          final backgrounds = {
            'surface': theme.colorScheme.surface,
            'shade': isDark ? palette.darkShade : palette.lightShade,
            'header': isDark ? palette.dark : palette.light,
          };
          final texts = {
            'primaryText': palette.primaryText,
            'primaryTextDark': palette.primaryTextDark,
            'gray': palette.gray,
            'grayLight': palette.grayLight,
            'secondary': palette.secondary,
            'accentRed': isDark ? palette.accentRedDark : palette.accentRed,
            'accentGreen': isDark
                ? palette.accentGreenDark
                : palette.accentGreen,
            'accentOrange': isDark
                ? palette.accentOrangeDark
                : palette.accentOrange,
            'accentPurple': isDark
                ? palette.accentPurpleDark
                : palette.accentPurple,
            'accentBrown': isDark
                ? palette.accentBrownDark
                : palette.accentBrown,
          };
          for (final t in texts.entries) {
            for (final b in backgrounds.entries) {
              expect(
                contrastRatio(t.value, b.value),
                greaterThanOrEqualTo(kDpdMinContrast),
                reason: '${t.key} on ${b.key}',
              );
            }
          }

          // The frequency table writes `light` or `dark`, whichever reads
          // better, on each heat-map step.
          for (var i = 0; i < palette.freq.length; i++) {
            final step = palette.freq[i];
            final best = [
              contrastRatio(palette.light, step),
              contrastRatio(palette.dark, step),
            ].reduce((a, b) => a > b ? a : b);
            expect(
              best,
              greaterThanOrEqualTo(kDpdMinContrast),
              reason: 'freq[$i]',
            );
          }
        });
      }
    }
  }
}
