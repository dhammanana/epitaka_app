import 'package:flutter/material.dart';

import '../../../core/providers/settings_provider.dart';
import '../../settings/providers/tts_provider.dart';

/// Floating bottom toolbar for the reader with actions like contents, search,
/// dictionary, display mode toggle, TTS, and bookmark.
class ReaderBottomToolbar extends StatelessWidget {
  final ColorScheme colors;
  final TranslationDisplayMode displayMode;
  final bool showTranslation;
  final TtsPlaybackState ttsPlayback;
  final VoidCallback onToggleTranslation;
  final VoidCallback onCycleDisplayMode;
  final VoidCallback onContentsTap;
  final VoidCallback onDictionaryTap;
  final VoidCallback onListenTap;
  final VoidCallback onStopTap;
  final VoidCallback onBookmarkTap;
  final VoidCallback onSearchTap;
  final VoidCallback onJumpTap;

  const ReaderBottomToolbar({
    super.key,
    required this.colors,
    required this.displayMode,
    required this.showTranslation,
    required this.ttsPlayback,
    required this.onToggleTranslation,
    required this.onCycleDisplayMode,
    required this.onContentsTap,
    required this.onDictionaryTap,
    required this.onListenTap,
    required this.onStopTap,
    required this.onBookmarkTap,
    required this.onSearchTap,
    required this.onJumpTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData displayIcon;
    String displayLabel;
    if (!showTranslation) {
      displayIcon = Icons.translate;
      displayLabel = 'No Trans';
    } else {
      switch (displayMode) {
        case TranslationDisplayMode.lineByLine:
          displayIcon = Icons.view_headline;
          displayLabel = 'Line/L';
        case TranslationDisplayMode.sideBySide:
          displayIcon = Icons.view_column;
          displayLabel = 'Side/S';
        case TranslationDisplayMode.hideJoinLines:
          displayIcon = Icons.translate;
          displayLabel = 'No Trans';
      }
    }

    final isPlaying = ttsPlayback == TtsPlaybackState.playing;
    final isLoading = ttsPlayback == TtsPlaybackState.loading;

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
        children: [
          ToolbarButton(
            icon: Icons.format_list_bulleted,
            label: 'Contents',
            onTap: onContentsTap,
          ),
          const SizedBox(width: 8),
          // Search within current book
          ToolbarButton(
            icon: Icons.search,
            label: 'Search',
            onTap: onSearchTap,
          ),
          const SizedBox(width: 8),
          ToolbarButton(
            icon: Icons.menu_book,
            label: 'Dictionary',
            onTap: onDictionaryTap,
          ),
          const SizedBox(width: 8),
          ToolbarButton(
            icon: Icons.open_in_new,
            label: 'Jump',
            onTap: onJumpTap,
          ),
          const SizedBox(width: 8),
          ToolbarButton(
            icon: displayIcon,
            label: displayLabel,
            onTap: showTranslation ? onCycleDisplayMode : onToggleTranslation,
          ),
          const SizedBox(width: 8),
          ToolbarButton(
            icon: isPlaying
                ? Icons.stop
                : (isLoading ? Icons.hourglass_top : Icons.volume_up),
            label: isPlaying ? 'Stop' : (isLoading ? 'Loading…' : 'Listen'),
            onTap: isPlaying ? onStopTap : onListenTap,
          ),
          const SizedBox(width: 2),
          ToolbarButton(
            icon: Icons.bookmark,
            label: 'Save',
            onTap: onBookmarkTap,
          ),
        ],
      ),
    );
  }
}

class ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ToolbarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9999),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: colors.onSurfaceVariant, size: 22),
        ),
      ),
    );
  }
}
