import 'package:flutter/material.dart';

import '../../../core/models/toolbar_item.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../shared/utils/app_shortcuts.dart';
import '../../settings/providers/tts_provider.dart';

/// Reader toolbar with actions like contents, search, dictionary, display
/// mode toggle, TTS, and bookmark.
///
/// Which actions appear — and in what order — is driven by [items]
/// (Settings → Toolbar). Actions the current surface doesn't wire up (e.g.
/// the flat status bar omits contents/search/dictionary) are skipped even
/// when enabled.
///
/// Two visual modes:
/// * **Floating pill** (default) — used on mobile as the reader's floating
///   bottom toolbar.
/// * **Flat status-bar strip** ([flat] = true) — used on desktop in the
///   shell's bottom status bar: full-width, no pill chrome, smaller height.
///   With [compact] = true the labels are hidden (icons only, tooltips kept)
///   so the toolbar fits narrow windows.
class ReaderBottomToolbar extends StatelessWidget {
  final ColorScheme colors;
  final TranslationDisplayMode displayMode;
  final bool showTranslation;
  final TtsPlaybackState ttsPlayback;

  /// Flat (status-bar) rendering: no pill radius/border/shadow, fills the
  /// row, smaller height.
  final bool flat;

  /// When true, only icons are shown (labels become tooltips). Used with
  /// [flat] on narrow windows.
  final bool compact;

  /// When false, every button is disabled (no book is open).
  final bool enabled;

  final VoidCallback? onDisplayLayoutTap;
  final VoidCallback? onContentsTap;
  final VoidCallback? onOutlineTap;
  final VoidCallback? onDictionaryTap;
  final VoidCallback? onListenTap;
  final VoidCallback? onStopTap;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onJumpTap;
  final VoidCallback? onAnnotationsTap;
  final VoidCallback? onSummarizeTap;

  /// The ordered toolbar configuration (Settings → Toolbar). Disabled items
  /// are skipped, and items with no wired handler for this surface are
  /// skipped too. Defaults to every action, enabled, in its natural order.
  final List<ToolbarItem> items;

  const ReaderBottomToolbar({
    super.key,
    required this.colors,
    required this.displayMode,
    required this.showTranslation,
    required this.ttsPlayback,
    this.flat = false,
    this.compact = false,
    this.enabled = true,
    this.items = const [],
    this.onDisplayLayoutTap,
    this.onContentsTap,
    this.onOutlineTap,
    this.onDictionaryTap,
    this.onListenTap,
    this.onStopTap,
    this.onBookmarkTap,
    this.onSearchTap,
    this.onJumpTap,
    this.onAnnotationsTap,
    this.onSummarizeTap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    // Three-state display mode: hide translation → line-by-line → side-by-side
    IconData displayIcon;
    String displayLabel;
    if (!showTranslation) {
      displayIcon = Icons.visibility_off;
      displayLabel = loc.hideLabel;
    } else {
      switch (displayMode) {
        case TranslationDisplayMode.lineByLine:
          displayIcon = Icons.view_headline;
          displayLabel = loc.lineByLineShort;
        case TranslationDisplayMode.sideBySide:
          displayIcon = Icons.view_column;
          displayLabel = loc.sideBySideShort;
        case TranslationDisplayMode.hideJoinLines:
          displayIcon = Icons.visibility_off;
          displayLabel = loc.hideLabel;
      }
    }

    final isPlaying = ttsPlayback == TtsPlaybackState.playing;
    final isLoading = ttsPlayback == TtsPlaybackState.loading;

    // The display-layout popup offers three modes, each with its own
    // shortcut — hint at the trio so users can learn them from the button.
    final displayHint = AppShortcuts.isMacOS ? '⌥⌘1/2/3' : 'Ctrl+Alt+1/2/3';

    // The configured item list (Settings → Toolbar). An empty list means no
    // configuration was supplied, so fall back to every action enabled in
    // its natural order.
    final toolbarItems = items.isEmpty ? defaultToolbarItems() : items;

    final buttons = <Widget>[];

    void add(Widget? button) {
      if (button == null) return;
      if (buttons.isNotEmpty && !compact) {
        buttons.add(const SizedBox(width: 8));
      }
      buttons.add(button);
    }

    for (final item in toolbarItems) {
      if (!item.enabled) continue;
      switch (item.id) {
        case ToolbarBuiltins.contents:
          // Contents already lives in the desktop sidebar / activity bar,
          // so the flat status-bar strip doesn't repeat it.
          add(
            !flat && onContentsTap != null
                ? ToolbarButton(
                    icon: Icons.format_list_bulleted,
                    label: loc.contents,
                    tooltip: AppShortcuts.tooltip(loc.contents, 'contents'),
                    compact: compact,
                    enabled: enabled,
                    onTap: onContentsTap,
                  )
                : null,
          );
        case ToolbarBuiltins.outline:
          // Book outline — every section with its study guide. Pill only;
          // the desktop status bar omits it because the sidebar's contents
          // panel already hosts the outline button.
          add(
            !flat && onOutlineTap != null
                ? ToolbarButton(
                    icon: Icons.account_tree_outlined,
                    label: loc.outline,
                    tooltip: AppShortcuts.tooltip(loc.outline, 'outline'),
                    compact: compact,
                    enabled: enabled,
                    onTap: onOutlineTap,
                  )
                : null,
          );
        case ToolbarBuiltins.search:
          // Search within current book (pill only, see contents above).
          add(
            !flat && onSearchTap != null
                ? ToolbarButton(
                    icon: Icons.search,
                    label: loc.search,
                    tooltip: AppShortcuts.tooltip(loc.search, 'find-in-book'),
                    compact: compact,
                    enabled: enabled,
                    onTap: onSearchTap,
                  )
                : null,
          );
        case ToolbarBuiltins.dictionary:
          add(
            !flat && onDictionaryTap != null
                ? ToolbarButton(
                    icon: Icons.menu_book,
                    label: loc.dictionary,
                    tooltip: AppShortcuts.tooltip(loc.dictionary, 'dictionary'),
                    compact: compact,
                    enabled: enabled,
                    onTap: onDictionaryTap,
                  )
                : null,
          );
        case ToolbarBuiltins.jump:
          add(
            onJumpTap != null
                ? ToolbarButton(
                    icon: Icons.open_in_new,
                    label: loc.jumpLabel,
                    tooltip: AppShortcuts.tooltip(loc.jumpLabel, 'jump'),
                    compact: compact,
                    enabled: enabled,
                    onTap: onJumpTap,
                  )
                : null,
          );
        case ToolbarBuiltins.displayLayout:
          add(
            onDisplayLayoutTap != null
                ? ToolbarButton(
                    icon: displayIcon,
                    label: displayLabel,
                    tooltip: '$displayLabel $displayHint',
                    compact: compact,
                    enabled: enabled,
                    onTap: onDisplayLayoutTap,
                  )
                : null,
          );
        case ToolbarBuiltins.listen:
          add(
            (onListenTap != null || onStopTap != null)
                ? ToolbarButton(
                    icon: isPlaying
                        ? Icons.stop
                        : (isLoading ? Icons.hourglass_top : Icons.volume_up),
                    label: isPlaying
                        ? loc.stopLabel
                        : (isLoading ? loc.loadingDots : loc.toolbarListen),
                    compact: compact,
                    enabled: enabled,
                    onTap: isPlaying ? onStopTap : onListenTap,
                  )
                : null,
          );
        case ToolbarBuiltins.bookmark:
          add(
            onBookmarkTap != null
                ? ToolbarButton(
                    icon: Icons.bookmark,
                    label: loc.toolbarSave,
                    compact: compact,
                    enabled: enabled,
                    onTap: onBookmarkTap,
                  )
                : null,
          );
        case ToolbarBuiltins.annotations:
          // Highlights / notes / bookmarks manager. Only rendered when a
          // handler is provided (mobile pill); the desktop status bar omits
          // it because the activity bar already hosts the annotations panel.
          add(
            onAnnotationsTap != null
                ? ToolbarButton(
                    icon: Icons.edit_note,
                    label: loc.annotations,
                    compact: compact,
                    enabled: enabled,
                    onTap: onAnnotationsTap,
                  )
                : null,
          );
        case ToolbarBuiltins.summarize:
          // Summarize the current chapter with AI (Vimaṃsa). Rendered
          // wherever a handler is provided — the mobile pill and the
          // desktop status bar.
          add(
            onSummarizeTap != null
                ? ToolbarButton(
                    icon: Icons.summarize_outlined,
                    label: loc.summarizeChapter,
                    compact: compact,
                    enabled: enabled,
                    onTap: onSummarizeTap,
                  )
                : null,
          );
      }
    }

    // Every action was disabled (or none wired up) — render nothing rather
    // than an empty pill / spacer.
    if (buttons.isEmpty) return const SizedBox.shrink();

    if (flat) {
      // Full-width, attached status-bar strip (no pill chrome).
      return SizedBox(
        height: 40,
        child: Row(mainAxisSize: MainAxisSize.min, children: buttons),
      );
    }

    // Floating pill (mobile).
    return Container(
      height: 56,
      constraints: const BoxConstraints(maxWidth: 500),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Horizontally scrollable so narrow screens (or many actions)
      // never overflow the pill — content stays centered and reachable.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, children: buttons),
      ),
    );
  }
}

class ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;
  final bool enabled;
  final VoidCallback? onTap;

  /// Tooltip text; defaults to [label]. Passed when the tooltip should also
  /// show the action's keyboard shortcut (see [AppShortcuts.tooltip]).
  final String? tooltip;

  const ToolbarButton({
    super.key,
    required this.icon,
    required this.label,
    this.tooltip,
    this.compact = false,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip ?? label,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(9999),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: enabled
                ? colors.onSurfaceVariant
                : colors.onSurfaceVariant.withValues(alpha: 0.3),
            size: 22,
          ),
        ),
      ),
    );
  }
}
