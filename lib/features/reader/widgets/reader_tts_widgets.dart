import 'package:flutter/material.dart';

import '../../../core/utils/app_localizations.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// Fixed width of the TTS controls card. The dialog caps its content at this
/// width too, so the card can never be stretched wider by a long fallback
/// notice.
const double kTtsControlsCardWidth = 280;

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
    final needsFollow = !isAutoScroll || (!isTtsLineVisible && !isJumpPending);
    final loc = AppLocalizations.of(context);
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
            Icon(Icons.record_voice_over, size: 18, color: colors.onPrimary),
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
                      Icon(
                        Icons.my_location,
                        size: 14,
                        color: colors.onPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        loc.follow,
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
            Icon(Icons.expand_less, size: 16, color: colors.onPrimary),
          ],
        ),
      ),
    );
  }
}

class TtsControlsCard extends StatelessWidget {
  final ColorScheme colors;
  final AppSettings settings;
  final bool isTtsLineVisible;
  final VoidCallback onFollowTap;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<double> onPaliSpeedChanged;
  final ValueChanged<double> onPitchChanged;
  final ValueChanged<String> onVoiceChanged;
  final ValueChanged<TtsSpeakMode> onSpeakModeChanged;
  final VoidCallback onInstallVoiceTap;
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
    required this.onPaliSpeedChanged,
    required this.onPitchChanged,
    required this.onVoiceChanged,
    required this.onSpeakModeChanged,
    required this.onInstallVoiceTap,
    required this.onSystemConfigTap,
    required this.onClose,
    required this.voices,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      width: kTtsControlsCardWidth,
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
          Row(
            children: [
              Icon(Icons.record_voice_over, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                loc.ttsControls,
                style: AppTypography.labelMedium.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          if (!isTtsLineVisible) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onFollowTap,
                icon: Icon(Icons.my_location, size: 16, color: colors.primary),
                label: Text(
                  loc.followTtsPosition,
                  style: TextStyle(color: colors.primary),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.md),
          ],
          // Pāli comes first (the book shows Pāli above the translation).
          _ControlSlider(
            icon: Icons.menu_book,
            label: loc.ttsPaliSpeed,
            value: settings.ttsPaliSpeed,
            min: 0.1,
            max: 4.0,
            displayValue: '${settings.ttsPaliSpeed.toStringAsFixed(1)}×',
            colors: colors,
            onChanged: onPaliSpeedChanged,
          ),
          const SizedBox(height: AppDimensions.sm),
          _ControlSlider(
            icon: Icons.speed,
            label: loc.ttsTranslationSpeed,
            value: settings.ttsSpeed,
            min: 0.5,
            max: 4.0,
            displayValue: '${settings.ttsSpeed.toStringAsFixed(1)}×',
            colors: colors,
            onChanged: onSpeedChanged,
          ),
          const SizedBox(height: AppDimensions.sm),
          _ControlSlider(
            icon: Icons.tune,
            label: loc.ttPitch,
            value: settings.ttsPitch,
            min: 0.5,
            max: 2.0,
            displayValue: '${settings.ttsPitch.toStringAsFixed(1)}×',
            colors: colors,
            onChanged: onPitchChanged,
          ),
          const SizedBox(height: AppDimensions.md),
          Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 16, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                loc.ttsSpeakMode,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurface,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<TtsSpeakMode>(
              segments: [
                ButtonSegment(
                  value: TtsSpeakMode.translation,
                  label: Text(
                    loc.ttsSpeakTranslation,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                ButtonSegment(
                  value: TtsSpeakMode.pali,
                  label: Text(
                    loc.ttsSpeakPali,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                ButtonSegment(
                  value: TtsSpeakMode.both,
                  label: Text(
                    loc.ttsSpeakBothShort,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
              selected: {settings.ttsSpeakMode},
              onSelectionChanged: (sel) => onSpeakModeChanged(sel.first),
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: WidgetStatePropertyAll(
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                ),
                textStyle: WidgetStatePropertyAll(
                  AppTypography.labelSmall.copyWith(fontSize: 11),
                ),
                side: WidgetStatePropertyAll(
                  BorderSide(color: colors.outlineVariant),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          Row(
            children: [
              if (settings.ttsEngine == 'system') ...[
                Expanded(
                  child: PopupMenuButton<String>(
                    initialValue: settings.ttsVoice,
                    onSelected: onVoiceChanged,
                    itemBuilder: (context) => voices.isEmpty
                        ? [
                            PopupMenuItem<String>(
                              value: 'default',
                              child: Text(loc.systemDefault),
                            ),
                          ]
                        : voices
                              .map(
                                (v) => PopupMenuItem<String>(
                                  value: v['name'] ?? 'default',
                                  child: Text(v['name'] ?? loc.unknown),
                                ),
                              )
                              .toList(),
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
                          Icon(
                            Icons.record_voice_over,
                            size: 14,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              loc.ttsVoiceLabel,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSmall.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right,
                            size: 14,
                            color: colors.onSurfaceVariant,
                          ),
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
                  icon: Icon(
                    Icons.settings,
                    size: 14,
                    color: colors.onSurfaceVariant,
                  ),
                  label: Text(
                    loc.config,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
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

String stripHtmlForTts(String text) {
  return text
      .replaceAll(RegExp(r'<i>.*?</i>', caseSensitive: false, dotAll: true), '')
      // .replaceAll(RegExp(r'\([^()]*[' + r'āīūōṅñṭḍṇḷṃṁĀĪŪŌṄÑṬḌṆḶṀ' + r'][^()]*\)'), '')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\\s+'), ' ')
      .trim();
}

/// Keep only system voices whose locale matches [langCode] (e.g. 'en'
/// → 'en-US', 'en-GB'). Falls back to all voices when none match so the
/// picker is never empty, and always keeps the currently selected voice
/// selectable so the menu's initial value stays valid.
///
/// Voices come from flutter_tts `getVoices()` with `name` + `locale` keys.
List<Map<String, String>> filterVoicesForLanguage(
  List<Map<String, String>> voices,
  String langCode, {
  required String selectedVoice,
}) {
  if (voices.isEmpty) return voices;
  final lc = langCode.toLowerCase();
  final matched = voices.where((v) {
    final loc = (v['locale'] ?? '').toLowerCase();
    return loc == lc || loc.startsWith('$lc-') || loc.startsWith('${lc}_');
  }).toList();
  if (matched.isEmpty) return voices;
  if (selectedVoice.isNotEmpty &&
      selectedVoice != 'default' &&
      !matched.any((v) => v['name'] == selectedVoice)) {
    final sel = voices.where((v) => v['name'] == selectedVoice).toList();
    if (sel.isNotEmpty) matched.insert(0, sel.first);
  }
  return matched;
}
