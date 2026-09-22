import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_localizations.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/tts_speed_control.dart';
import '../../settings/providers/tts_provider.dart';
import '../../settings/services/system_tts_availability.dart';
import '../providers/tts_reading_provider.dart';

/// Fixed width of the TTS controls card. The dialog caps its content at this
/// width too, so the card can never be stretched wider by a long fallback
/// notice.
const double kTtsControlsCardWidth = 280;/// Floating TTS control pill shown while a reading session is active.
///
/// Collapsed: a single tappable chip (with a "Follow" badge when the
/// spoken line is off-screen). Tapping it expands into a transport bar:
/// Prev · Stop · Pause/Play · Next · More. "More" opens the full TTS
/// controls dialog (voice/speed/config — the previous behavior).
class TtsFloatingChip extends ConsumerStatefulWidget {
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
  ConsumerState<TtsFloatingChip> createState() => _TtsFloatingChipState();
}

class _TtsFloatingChipState extends ConsumerState<TtsFloatingChip> {
  bool _expanded = false;

  BoxDecoration get _pillDecoration => BoxDecoration(
    color: widget.colors.primary,
    borderRadius: BorderRadius.circular(9999),
    boxShadow: [
      BoxShadow(
        color: widget.colors.primary.withValues(alpha: 0.3),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final needsFollow =
        !widget.isAutoScroll ||
        (!widget.isTtsLineVisible && !widget.isJumpPending);
    final loc = AppLocalizations.of(context);

    return _expanded
        ? _buildExpanded(loc)
        : _buildCollapsed(needsFollow, loc);
  }

  /// Collapsed chip: tap to expand into the transport bar.
  Widget _buildCollapsed(bool needsFollow, AppLocalizations loc) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = true),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: needsFollow ? 14 : 10,
          vertical: needsFollow ? 8 : 10,
        ),
        decoration: _pillDecoration,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.record_voice_over,
              size: 18,
              color: widget.colors.onPrimary,
            ),
            if (needsFollow) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: widget.onFollowTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: widget.colors.onPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.my_location,
                        size: 14,
                        color: widget.colors.onPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        loc.follow,
                        style: TextStyle(
                          color: widget.colors.onPrimary,
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
            Icon(Icons.expand_less, size: 16, color: widget.colors.onPrimary),
          ],
        ),
      ),
    );
  }

  /// Expanded transport bar: Prev · Stop · Play/Pause · Next · More.
  Widget _buildExpanded(AppLocalizations loc) {
    final ttsPlayback = ref.watch(ttsProvider);
    final ttsReading = ref.watch(ttsReadingProvider);
    final isPlaying = ttsPlayback == TtsPlaybackState.playing;
    final isActive =
        ttsReading.isActive || ttsReading.isPaused || isPlaying;
    final iconColor = widget.colors.onPrimary;

    Widget action({
      required IconData icon,
      required String tooltip,
      required VoidCallback? onPressed,
      double size = 20,
    }) {
      return IconButton(
        icon: Icon(icon, size: size, color: iconColor),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        visualDensity: VisualDensity.compact,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: _pillDecoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          action(
            icon: Icons.skip_previous,
            tooltip: loc.ttsSkipPrevious,
            onPressed: isActive
                ? () => ref.read(ttsReadingProvider.notifier).skipBackward()
                : null,
          ),
          action(
            icon: Icons.stop,
            tooltip: loc.stopLabel,
            onPressed: isActive
                ? () {
                    setState(() => _expanded = false);
                    ref.read(ttsReadingProvider.notifier).stopReading();
                  }
                : null,
          ),
          action(
            icon: isPlaying ? Icons.pause : Icons.play_arrow,
            tooltip: isPlaying ? loc.pause : loc.play,
            onPressed: isActive
                ? () => isPlaying
                      ? ref.read(ttsReadingProvider.notifier).pauseReading()
                      : ref.read(ttsReadingProvider.notifier).resumeReading()
                : null,
          ),
          action(
            icon: Icons.skip_next,
            tooltip: loc.ttsSkipNext,
            onPressed: isActive
                ? () => ref.read(ttsReadingProvider.notifier).skipForward()
                : null,
          ),
          action(
            icon: Icons.tune,
            tooltip: loc.ttsControls,
            // "More settings" — opens the full controls dialog that the
            // collapsed chip used to open directly.
            onPressed: widget.onTap,
            size: 18,
          ),
        ],
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
  final ValueChanged<String> onPaliVoiceChanged;
  final ValueChanged<TtsSpeakMode> onSpeakModeChanged;
  final ValueChanged<String> onScriptChanged;
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
    required this.onPaliVoiceChanged,
    required this.onSpeakModeChanged,
    required this.onScriptChanged,
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
          // ── Pāli section (the book shows Pāli above the translation) ──
          _SectionHeader(label: loc.pali),
          const SizedBox(height: AppDimensions.sm),
          _TtsScriptDropdown(
            selectedScript: settings.ttsScript,
            onScriptChanged: onScriptChanged,
            colors: colors,
          ),
          const SizedBox(height: AppDimensions.sm),
          // Pāli voice picker for the chosen Pāli TTS script.
          _CompactVoicePicker(
            label: loc.ttsPaliVoice,
            selectedVoice: settings.ttsPaliVoice,
            voices: filterVoicesForLanguage(
              voices,
              settings.ttsScript,
              selectedVoice: settings.ttsPaliVoice,
              showAllIfEmpty: false,
            ),
            colors: colors,
            onChanged: onPaliVoiceChanged,
            showInstallHint: true,
            langCode: settings.ttsScript,
          ),
          const SizedBox(height: AppDimensions.sm),
          TtsSpeedControl(
            icon: Icons.menu_book,
            label: loc.ttsPaliSpeed,
            value: settings.ttsPaliSpeed,
            min: 0.1,
            colors: colors,
            compact: true,
            onChanged: onPaliSpeedChanged,
          ),
          const SizedBox(height: AppDimensions.sm),
          // Visual split between the Pāli and translation configuration.
          const Divider(height: 1, color: null),
          const SizedBox(height: AppDimensions.sm),
          // ── Translation section ──────────────────────────────────
          _SectionHeader(label: loc.translationWord),
          const SizedBox(height: AppDimensions.sm),
          // Translation voice before speed.
          _CompactVoicePicker(
            label: loc.ttsTranslationVoice,
            selectedVoice: settings.ttsVoice,
            voices: filterVoicesForLanguage(
              voices,
              settings.visibleTranslationLangs.isNotEmpty
                  ? settings.visibleTranslationLangs.first
                  : 'en',
              selectedVoice: settings.ttsVoice,
            ),
            colors: colors,
            onChanged: onVoiceChanged,
          ),
          const SizedBox(height: AppDimensions.sm),
          TtsSpeedControl(
            icon: Icons.speed,
            label: loc.ttsTranslationSpeed,
            value: settings.ttsSpeed,
            min: 0.5,
            colors: colors,
            compact: true,
            onChanged: onSpeedChanged,
          ),
          const SizedBox(height: AppDimensions.sm),
          TtsSpeedControl(
            icon: Icons.tune,
            label: loc.ttPitch,
            value: settings.ttsPitch,
            min: 0.5,
            step: 0.1,
            colors: colors,
            compact: true,
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
          // Config entry point: quiet full-width row with a gear + chevron,
          // reads as navigation rather than a button that looks equal in
          // weight to the controls above.
          InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            onTap: onSystemConfigTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.settings_outlined,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.config,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small uppercase section label used to group the Pāli and translation
/// controls in the TTS card.
class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTypography.labelSmall.copyWith(
        fontSize: 10,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// ── Compact Voice Picker ────────────────────────────────────────────────

/// A compact voice picker for the TTS controls dialog. Shows a label
/// and a popup menu of filtered voices.
class _CompactVoicePicker extends StatelessWidget {
  final String label;
  final String selectedVoice;
  final List<Map<String, String>> voices;
  final ColorScheme colors;
  final ValueChanged<String> onChanged;
  final bool showInstallHint;

  /// Script/language code the voices were filtered for (e.g. the Pāli
  /// TTS script). Used for the "voice not installed" hint.
  final String langCode;

  const _CompactVoicePicker({
    required this.label,
    required this.selectedVoice,
    required this.voices,
    required this.colors,
    required this.onChanged,
    this.showInstallHint = false,
    this.langCode = 'hi',
  });

  /// Short display name of a Pāli TTS script code for the
  /// "voice not installed" hint (matches the script dropdown labels).
  static String _scriptShortLabel(String code) => switch (code) {
    'kn' => 'Kannada',
    'te' => 'Telugu',
    'si' => 'Sinhala',
    'hi' => 'Hindi',
    _ => code,
  };

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final displayName = selectedVoice.isEmpty || selectedVoice == 'default'
        ? loc.systemDefault
        : (() {
            final matches = voices
                .where((v) => v['name'] == selectedVoice)
                .toList();
            if (matches.isEmpty) return loc.systemDefault;
            return SystemTtsAvailability.voiceDisplayName(matches.first);
          })();

    // Show install hint when no voices match this language.
    if (voices.isEmpty && showInstallHint) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: colors.errorContainer),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber, size: 14, color: colors.error),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                loc.ttsVoiceNotInstalledFor(_scriptShortLabel(langCode)),
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.error,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return PopupMenuButton<String>(
      initialValue: selectedVoice,
      onSelected: onChanged,
      itemBuilder: (context) => [
        PopupMenuItem<String>(value: 'default', child: Text(loc.systemDefault)),
        for (final v in voices)
          PopupMenuItem<String>(
            value: v['name'] ?? 'default',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              // Friendly label ("Iob (network)") plus the raw engine ID
              // ("en-us-x-iob-network") as the subtitle, so users can
              // still tell identical-looking names apart.
              title: Text(
                SystemTtsAvailability.voiceDisplayName(v),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                v['name'] ?? loc.unknown,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.record_voice_over, size: 14, color: colors.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '$label: $displayName',
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 14, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ── TTS Script Dropdown ─────────────────────────────────────────────────

/// Dropdown for selecting the TTS script/language for Pāli.
/// Options: Kannada, Telugu, Sinhala, Hindi (Sanskrit).
/// Only Hindi enables Devanagari conversion + replacement text.
class _TtsScriptDropdown extends StatelessWidget {
  final String selectedScript;
  final ValueChanged<String> onScriptChanged;
  final ColorScheme colors;

  const _TtsScriptDropdown({
    required this.selectedScript,
    required this.onScriptChanged,
    required this.colors,
  });

  static const _scriptOptions = [
    ('kn', 'Kannada'),
    ('te', 'Telugu'),
    ('si', 'Sinhala'),
    ('hi', 'Hindi (Sanskrit)'),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final selectedLabel = _scriptOptions
        .firstWhere(
          (opt) => opt.$1 == selectedScript,
          orElse: () => _scriptOptions.last,
        )
        .$2;

    return Row(
      children: [
        Icon(Icons.language, size: 16, color: colors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            loc.ttsScriptLabel,
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurface,
              fontSize: 12,
            ),
          ),
        ),
        // Flexible (loose): the pill keeps its natural width when there is
        // room, but must be able to shrink when the card is narrow — a long
        // selected label ("Hindi (Sanskrit)") used to overflow the row by
        // ~2px because a plain flex child gets unbounded width.
        Flexible(
          child: PopupMenuButton<String>(
            initialValue: selectedScript,
            onSelected: onScriptChanged,
            itemBuilder: (context) => [
              for (final opt in _scriptOptions)
                PopupMenuItem<String>(
                  value: opt.$1,
                  child: Row(
                    children: [
                      if (opt.$1 == selectedScript)
                        Icon(Icons.check, size: 16, color: colors.primary),
                      if (opt.$1 == selectedScript) const SizedBox(width: 8),
                      Expanded(
                        child: Text(opt.$2, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flexible: the pill must never force its natural width
                  // past the space left in the card row — a long selected
                  // label ("Hindi (Sanskrit)") used to overflow by ~2px.
                  Flexible(
                    child: Text(
                      selectedLabel,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
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
/// → 'en-US', 'en-GB'). When [showAllIfEmpty] is true (the default),
/// falls back to all voices when none match so the picker is never
/// empty. When false, returns an empty list so the caller can show
/// an install-hint instead. Always keeps the currently selected voice
/// selectable so the menu's initial value stays valid.
///
/// Voices come from flutter_tts `getVoices()` with `name` + `locale` keys.
List<Map<String, String>> filterVoicesForLanguage(
  List<Map<String, String>> voices,
  String langCode, {
  required String selectedVoice,
  bool showAllIfEmpty = true,
}) {
  if (voices.isEmpty) return voices;
  final lc = langCode.toLowerCase();
  final matched = voices.where((v) {
    final loc = (v['locale'] ?? '').toLowerCase();
    return loc == lc || loc.startsWith('$lc-') || loc.startsWith('${lc}_');
  }).toList();
  if (matched.isEmpty) {
    if (!showAllIfEmpty) return <Map<String, String>>[];
    final all = List<Map<String, String>>.from(voices);
    SystemTtsAvailability.sortVoices(all);
    return all;
  }
  SystemTtsAvailability.sortVoices(matched);
  if (selectedVoice.isNotEmpty &&
      selectedVoice != 'default' &&
      !matched.any((v) => v['name'] == selectedVoice)) {
    final sel = voices.where((v) => v['name'] == selectedVoice).toList();
    if (sel.isNotEmpty) matched.insert(0, sel.first);
  }
  return matched;
}
