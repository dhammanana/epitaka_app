import 'package:flutter/material.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// A small floating chip that appears when TTS is playing, providing
/// quick access to follow TTS (when scrolled away) and a popup menu
/// with additional controls (voice, speed, pitch, system config).
class TtsFloatingChip extends StatelessWidget {
  final ColorScheme colors;
  final bool isAutoScroll;
  final bool isJumpPending;
  final bool isTtsLineVisible;
  final VoidCallback onTap;
  final VoidCallback onFollowTap;

  const TtsFloatingChip({
    super.key,
    required this.colors,
    required this.isAutoScroll,
    this.isJumpPending = false,
    required this.isTtsLineVisible,
    required this.onTap,
    required this.onFollowTap,
  });

  @override
  Widget build(BuildContext context) {
    // Show Follow only when the user is genuinely away from TTS.
    // If auto-scroll is off (user manually scrolled), always show.
    // If the line isn't visible BUT a jump is pending (TTS just
    // moved to a new paragraph and we're about to scroll there),
    // hide Follow to avoid flashing it during the gap.
    final needsFollow = !isAutoScroll || (!isTtsLineVisible && !isJumpPending);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: needsFollow ? 14 : 10,
          vertical: needsFollow ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.record_voice_over,
              size: 18,
              color: colors.onPrimary,
            ),
            if (needsFollow) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onFollowTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.onPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.my_location, size: 14, color: colors.onPrimary),
                      const SizedBox(width: 4),
                      Text(
                        'Follow',
                        style: TextStyle(
                          color: colors.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.expand_less,
              size: 16,
              color: colors.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact control card displayed in a popup dialog, showing speed,
/// pitch, voice selection, and system config for TTS playback.
class TtsControlsCard extends StatelessWidget {
  final ColorScheme colors;
  final AppSettings settings;
  final bool isTtsLineVisible;
  final VoidCallback onFollowTap;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<double> onPitchChanged;
  final ValueChanged<String> onVoiceChanged;
  final VoidCallback onSystemConfigTap;
  final VoidCallback onClose;
  final List<Map<String, String>> voices;

  const TtsControlsCard({
    super.key,
    required this.colors,
    required this.settings,
    required this.isTtsLineVisible,
    required this.onFollowTap,
    required this.onSpeedChanged,
    required this.onPitchChanged,
    required this.onVoiceChanged,
    required this.onSystemConfigTap,
    required this.onClose,
    required this.voices,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(bottom: 80),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.record_voice_over, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'TTS Controls',
                style: AppTypography.labelMedium.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: colors.onSurfaceVariant),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          // Follow TTS button (only when scrolled away)
          if (!isTtsLineVisible) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onFollowTap,
                icon: Icon(Icons.my_location, size: 16, color: colors.primary),
                label: Text(
                  'Follow TTS Position',
                  style: TextStyle(color: colors.primary),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.md),
          ],

          // Speed slider
          _ControlSlider(
            icon: Icons.speed,
            label: 'Speed',
            value: settings.ttsSpeed,
            min: 0.5,
            max: 4.0,
            displayValue: '${settings.ttsSpeed.toStringAsFixed(1)}×',
            colors: colors,
            onChanged: onSpeedChanged,
          ),
          const SizedBox(height: AppDimensions.sm),

          // Pitch slider
          _ControlSlider(
            icon: Icons.tune,
            label: 'Pitch',
            value: settings.ttsPitch,
            min: 0.5,
            max: 2.0,
            displayValue: '${settings.ttsPitch.toStringAsFixed(1)}×',
            colors: colors,
            onChanged: onPitchChanged,
          ),
          const SizedBox(height: AppDimensions.md),

          // Voice selector (system TTS) + System Config
          Row(
            children: [
              if (settings.ttsEngine == 'system') ...[
                Expanded(
                  child: PopupMenuButton<String>(
                    initialValue: settings.ttsVoice,
                    onSelected: onVoiceChanged,
                    itemBuilder: (context) => [
                      if (voices.isEmpty)
                        const PopupMenuItem(
                          value: 'default',
                          child: Text('System Default'),
                        )
                      else
                        for (final v in voices)
                          PopupMenuItem(
                            value: v['name'] ?? 'default',
                            child: Text(v['name'] ?? 'Unknown'),
                          ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.outlineVariant),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.record_voice_over,
                              size: 14, color: colors.primary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Voice',
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSmall.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right,
                              size: 14, color: colors.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSystemConfigTap,
                  icon: Icon(Icons.settings, size: 14, color: colors.onSurfaceVariant),
                  label: Text(
                    'Config',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A slider control used in the TTS controls card.
class _ControlSlider extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final String displayValue;
  final ColorScheme colors;
  final ValueChanged<double> onChanged;

  const _ControlSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: colors.onSurface,
            fontSize: 12,
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min) * 4 ~/ 0.5,
            label: displayValue,
            activeColor: colors.primary,
            inactiveColor: colors.outlineVariant,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            displayValue,
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

/// Private helper — only used by [TtsControlsCard].
const _kPaliDiacritics = r'āīūōṅñṭḍṇḷṃṁĀĪŪŌṄÑṬḌṆḶṀ';

/// Strip HTML for TTS:
/// - <i>...</i> is removed ENTIRELY (tag + inner text), since it wraps
///   retained Pali terms that shouldn't be spoken by the translation voice.
/// - Any (...) whose contents include a Pali diacritic is removed
///   ENTIRELY (parens + inner text) for the same reason.
/// - Any other HTML tags are stripped, keeping their inner text.
/// - Leftover whitespace is collapsed.
String stripHtmlForTts(String text) {
  return text
      .replaceAll(RegExp(r'<i>.*?</i>', caseSensitive: false, dotAll: true), '')
      .replaceAll(
          RegExp(r'\([^()]*[' + _kPaliDiacritics + r'][^()]*\)'), '')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\\s+'), ' ')
      .trim();
}
