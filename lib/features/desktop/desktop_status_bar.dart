import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/utils/app_localizations.dart';
import '../../features/ai_qa/providers/ai_qa_settings_provider.dart';
import '../../features/reader/providers/reader_tabs_provider.dart';
import '../../features/reader/providers/tts_reading_provider.dart';
import '../../features/reader/widgets/display_layout_popup.dart';
import '../../features/reader/widgets/reader_bottom_toolbar.dart';
import '../../features/settings/providers/tts_provider.dart';
import '../../shared/providers/vimamsa_panel_provider.dart';
import '../../shared/utils/app_shortcuts.dart';
import '../../shared/widgets/reader_toolbar_controller.dart';

/// The attached status bar at the very bottom of the desktop shell.
///
/// It hosts the reader's toolbar in a **flat** (non-floating) mode, driven by
/// the [ReaderToolbarController] the reader registers its actions into, plus
/// a few shell-level actions on the right (font zoom, reset layout,
/// settings). On narrow windows the toolbar collapses to icons only.
class DesktopStatusBar extends ConsumerWidget {
  final ReaderToolbarController controller;
  final VoidCallback onResetLayout;
  final VoidCallback onOpenSettings;

  const DesktopStatusBar({
    super.key,
    required this.controller,
    required this.onResetLayout,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    final settings = ref.watch(settingsProvider);
    final ttsReading = ref.watch(ttsReadingProvider);
    final globalTts = ref.watch(ttsProvider);
    final vimamsaActive = ref.watch(vimamsaOpenProvider);
    final activeTab = ref.watch(readerTabsProvider.select((s) => s.activeTab));
    final isCurrentBookTts = ttsReading.bookId == activeTab?.bookId;
    final ttsPlayback = isCurrentBookTts ? globalTts : TtsPlaybackState.stopped;

    // Whether a TTS session is active for the tab open in the reader —
    // while it is, the status bar hosts the transport controls (the
    // floating chip is hidden inside the desktop shell).
    final showTtsTransport =
        isCurrentBookTts && (ttsReading.isActive || ttsReading.isPaused);

    return Material(
      color: colors.surfaceContainerLowest,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colors.outlineVariant, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 860;
                return Row(
                  children: [
                    // Left side: display-layout segmented trigger, opening
                    // the display popup anchored above the status bar.
                    Expanded(
                      child: Row(
                        children: [
                          _DisplayModeStatusButton(
                            displayMode: settings.translationDisplayMode,
                            showTranslation: settings.showTranslation,
                          ),
                          if (showTtsTransport) ...[
                            const SizedBox(width: 8),
                            // Transport controls for the active TTS session:
                            // Prev · Pause/Play · Next · Follow · More.
                            _StatusIconButton(
                              icon: Icons.skip_previous,
                              tooltip: loc.ttsSkipPrevious,
                              onTap: controller.onTtsPrev,
                            ),
                            _StatusIconButton(
                              icon: globalTts == TtsPlaybackState.playing
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              tooltip: globalTts == TtsPlaybackState.playing
                                  ? loc.pause
                                  : loc.play,
                              onTap: controller.onTtsPlayPause,
                            ),
                            _StatusIconButton(
                              icon: Icons.skip_next,
                              tooltip: loc.ttsSkipNext,
                              onTap: controller.onTtsNext,
                            ),
                            _StatusIconButton(
                              icon: Icons.my_location,
                              tooltip: loc.followTtsPosition,
                              onTap: controller.onTtsFollow,
                            ),
                            _StatusIconButton(
                              icon: Icons.tune,
                              tooltip: loc.ttsControls,
                              onTap: controller.onTtsMore,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Flat reader toolbar (drives the active reader tab),
                    // centered between the two balanced sides. Contents /
                    // search / dictionary are handled by the sidebar, so
                    // they're not wired up here.
                    ReaderBottomToolbar(
                      colors: colors,
                      displayMode: settings.translationDisplayMode,
                      showTranslation: settings.showTranslation,
                      ttsPlayback: ttsPlayback,
                      flat: true,
                      compact: compact,
                      enabled: controller.enabled,
                      items: settings.toolbarItems,
                      onJumpTap: controller.onJump,
                      // Display layout has its own dedicated button on the
                      // left of the status bar, so the flat strip skips it
                      // here (null handler = item not rendered).
                      onDisplayLayoutTap: null,
                      onListenTap: controller.onListen,
                      onStopTap: controller.onStop,
                      onBookmarkTap: controller.onBookmark,
                      onAiAskTap: controller.onAiAsk,
                    ),
                    // Right side: shell actions, end-aligned.
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const SizedBox(width: 8),
                          // ── Shell actions ──────────────────────────────
                          _StatusIconButton(
                            icon: Icons.text_decrease,
                            tooltip: AppShortcuts.tooltip(
                              loc.decreaseFontSize,
                              'font-decrease',
                            ),
                            onTap: () {
                              ref
                                  .read(settingsProvider.notifier)
                                  .decreaseFontSize();
                              if (vimamsaActive) {
                                final fs = ref
                                    .read(aiQaSettingsProvider)
                                    .chatFontSize;
                                ref
                                    .read(aiQaSettingsProvider.notifier)
                                    .setChatFontSize(
                                      (fs - 0.1).clamp(0.7, 2.0),
                                    );
                              }
                            },
                          ),
                          _StatusIconButton(
                            icon: Icons.text_increase,
                            tooltip: AppShortcuts.tooltip(
                              loc.increaseFontSize,
                              'font-increase',
                            ),
                            onTap: () {
                              ref
                                  .read(settingsProvider.notifier)
                                  .increaseFontSize();
                              if (vimamsaActive) {
                                final fs = ref
                                    .read(aiQaSettingsProvider)
                                    .chatFontSize;
                                ref
                                    .read(aiQaSettingsProvider.notifier)
                                    .setChatFontSize(
                                      (fs + 0.1).clamp(0.7, 2.0),
                                    );
                              }
                            },
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 1,
                            height: 20,
                            color: colors.outlineVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          _StatusIconButton(
                            icon: Icons.restart_alt,
                            tooltip: loc.resetLayout,
                            onTap: onResetLayout,
                          ),
                          _StatusIconButton(
                            icon: Icons.settings_outlined,
                            tooltip: AppShortcuts.tooltip(
                              loc.settings,
                              'settings',
                            ),
                            onTap: onOpenSettings,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Status-bar button showing the current display-layout mode as an icon
/// with the mode name beside it. Tapping it opens the shared
/// [DisplayLayoutPopup] anchored just above the status bar (same popup the
/// reader toolbar's display button opens, without its font controls being
/// cut off — the popup scrolls).
class _DisplayModeStatusButton extends ConsumerWidget {
  final TranslationDisplayMode displayMode;
  final bool showTranslation;

  const _DisplayModeStatusButton({
    required this.displayMode,
    required this.showTranslation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    IconData icon;
    String label;
    if (!showTranslation) {
      icon = Icons.visibility_off;
      label = loc.displayNoTranslation;
    } else {
      switch (displayMode) {
        case TranslationDisplayMode.lineByLine:
          icon = Icons.view_headline;
          label = loc.displayLineByLine;
        case TranslationDisplayMode.sideBySide:
          icon = Icons.view_column;
          label = loc.displaySideBySide;
        case TranslationDisplayMode.hideJoinLines:
          icon = Icons.visibility_off;
          label = loc.hideLabel;
      }
    }

    return Tooltip(
      message: loc.display,
      child: InkWell(
        onTap: () => showDialog(
          context: context,
          barrierColor: Colors.transparent,
          barrierDismissible: true,
          builder: (_) => const Align(
            alignment: Alignment(0, 0.88),
            child: DisplayLayoutPopup(),
          ),
        ),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: colors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_up,
                size: 14,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _StatusIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          child: Icon(icon, size: 17, color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}
