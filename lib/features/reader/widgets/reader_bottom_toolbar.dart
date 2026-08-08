import 'package:flutter/material.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/app_localizations.dart';
import '../../settings/providers/tts_provider.dart';

/// Reader toolbar with actions like contents, search, dictionary, display
/// mode toggle, TTS, and bookmark.
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
  final VoidCallback? onDictionaryTap;
  final VoidCallback? onListenTap;
  final VoidCallback? onStopTap;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onJumpTap;

  const ReaderBottomToolbar({
    super.key,
    required this.colors,
    required this.displayMode,
    required this.showTranslation,
    required this.ttsPlayback,
    this.flat = false,
    this.compact = false,
    this.enabled = true,
    this.onDisplayLayoutTap,
    this.onContentsTap,
    this.onDictionaryTap,
    this.onListenTap,
    this.onStopTap,
    this.onBookmarkTap,
    this.onSearchTap,
    this.onJumpTap,
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

    final buttons = <Widget>[
      // Contents, search and dictionary already live in the desktop sidebar
      // / activity bar, so the flat status-bar strip doesn't repeat them.
      if (!flat) ...[
        ToolbarButton(
          icon: Icons.format_list_bulleted,
          label: loc.contents,
          compact: compact,
          enabled: enabled,
          onTap: onContentsTap,
        ),
        if (!compact) const SizedBox(width: 8),
        // Search within current book
        ToolbarButton(
          icon: Icons.search,
          label: loc.search,
          compact: compact,
          enabled: enabled,
          onTap: onSearchTap,
        ),
        if (!compact) const SizedBox(width: 8),
        ToolbarButton(
          icon: Icons.menu_book,
          label: loc.dictionary,
          compact: compact,
          enabled: enabled,
          onTap: onDictionaryTap,
        ),
        if (!compact) const SizedBox(width: 8),
      ],
      ToolbarButton(
        icon: Icons.open_in_new,
        label: loc.jumpLabel,
        compact: compact,
        enabled: enabled,
        onTap: onJumpTap,
      ),
      if (!compact) const SizedBox(width: 8),
      ToolbarButton(
        icon: displayIcon,
        label: displayLabel,
        compact: compact,
        enabled: enabled,
        onTap: onDisplayLayoutTap,
      ),
      if (!compact) const SizedBox(width: 8),
      ToolbarButton(
        icon: isPlaying
            ? Icons.stop
            : (isLoading ? Icons.hourglass_top : Icons.volume_up),
        label: isPlaying
            ? loc.stopLabel
            : (isLoading ? loc.loadingDots : loc.toolbarListen),
        compact: compact,
        enabled: enabled,
        onTap: isPlaying ? onStopTap : onListenTap,
      ),
      if (!compact) const SizedBox(width: 2),
      ToolbarButton(
        icon: Icons.bookmark,
        label: loc.toolbarSave,
        compact: compact,
        enabled: enabled,
        onTap: onBookmarkTap,
      ),
    ];

    if (flat) {
      // Full-width, attached status-bar strip (no pill chrome).
      return SizedBox(
        height: 40,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: buttons,
        ),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: buttons,
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

  const ToolbarButton({
    super.key,
    required this.icon,
    required this.label,
    this.compact = false,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
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
