import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/utils/app_localizations.dart';
import '../../features/reader/providers/reader_tabs_provider.dart';
import '../../features/reader/providers/tts_reading_provider.dart';
import '../../features/reader/widgets/reader_bottom_toolbar.dart';
import '../../features/settings/providers/tts_provider.dart';
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
    final activeTab = ref.watch(
      readerTabsProvider.select((s) => s.activeTab),
    );
    final isCurrentBookTts = ttsReading.bookId == activeTab?.bookId;
    final ttsPlayback =
        isCurrentBookTts ? globalTts : TtsPlaybackState.stopped;

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
                    // Left spacer balances the right-aligned shell actions
                    // so the remaining toolbar buttons stay centered.
                    const Spacer(),
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
                      onDisplayLayoutTap: controller.onDisplayLayout,
                      onListenTap: controller.onListen,
                      onStopTap: controller.onStop,
                      onBookmarkTap: controller.onBookmark,
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
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .decreaseFontSize(),
                          ),
                          _StatusIconButton(
                            icon: Icons.text_increase,
                            tooltip: AppShortcuts.tooltip(
                              loc.increaseFontSize,
                              'font-increase',
                            ),
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .increaseFontSize(),
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
                            tooltip: AppShortcuts.tooltip(loc.settings, 'settings'),
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

class _StatusIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

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
