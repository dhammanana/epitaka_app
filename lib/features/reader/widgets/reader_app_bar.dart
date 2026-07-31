import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// Reader app bar that smoothly animates its height and opacity when
/// [showCollapsed] changes.
///
/// Safe area is handled by the parent [Padding] in [ReaderScreen] so
/// this widget only renders the toolbar content (back button, title,
/// actions) and a bottom divider.  When collapsed it shrinks to zero
/// height and the persistent top-safe-area padding keeps the [TabStrip]
/// below the status bar.
class ReaderAppBar extends ConsumerWidget {
  final String bookId;
  final String bookName;
  final ColorScheme colors;
  final bool showCollapsed;
  final VoidCallback onSettingsTap;
  final List<Widget>? actions;

  const ReaderAppBar({
    super.key,
    required this.bookId,
    required this.bookName,
    required this.colors,
    required this.showCollapsed,
    required this.onSettingsTap,
    this.actions,
  });

  static const _toolbarHeight = AppDimensions.appBarHeight;
  static const _animDuration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedSize(
      duration: _animDuration,
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: _animDuration,
        opacity: showCollapsed ? 0.0 : 1.0,
        child: showCollapsed
            ? const SizedBox.shrink()
            : Container(
                height: _toolbarHeight + 1, // +1 for the bottom divider
                color: colors.surface,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Toolbar row ──────────────────────────────
                    SizedBox(
                      height: _toolbarHeight,
                      child: Row(
                        children: [
                          // Back button
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            color: colors.onSurfaceVariant,
                            onPressed: () => context.mounted
                                ? Navigator.of(context).pop()
                                : null,
                          ),
                          const SizedBox(width: AppDimensions.sm),
                          // Title
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bookName,
                                  style: AppTypography.headlineSmall.copyWith(
                                    color: colors.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                Text(
                                  'Reading',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Font size control
                          const _FontSizeButton(),
                          // Actions
                          ...?actions,
                          // Settings button (default action)
                          if (actions == null)
                            IconButton(
                              icon: const Icon(Icons.settings),
                              color: colors.onSurfaceVariant,
                              onPressed: onSettingsTap,
                            ),
                        ],
                      ),
                    ),
                    // ── Bottom divider ───────────────────────────
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: colors.outlineVariant,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Small font-size popup button in the reader app bar.
///
/// Adjusts the Pāli + translation font sizes through the settings notifier
/// (the same path used by the typography settings screen and the keyboard
/// shortcuts), so the change is reflected everywhere.
class _FontSizeButton extends ConsumerWidget {
  const _FontSizeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final paliSize = settings.typography.pali.fontSize.round();

    return PopupMenuButton<String>(
      tooltip: 'Font size',
      icon: Text(
        'A',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: colors.onSurfaceVariant,
        ),
      ),
      offset: const Offset(0, 48),
      onSelected: (value) {
        final notifier = ref.read(settingsProvider.notifier);
        if (value == 'inc') {
          notifier.increaseFontSize();
        } else {
          notifier.decreaseFontSize();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(
                  'Pāli ${paliSize}px',
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  'Ctrl/Cmd + / −',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'inc',
          child: Row(
            children: [
              const Icon(Icons.add, size: 18),
              const SizedBox(width: 8),
              Text(
                'Increase font size',
                style: AppTypography.labelMedium.copyWith(
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'dec',
          child: Row(
            children: [
              const Icon(Icons.remove, size: 18),
              const SizedBox(width: 8),
              Text(
                'Decrease font size',
                style: AppTypography.labelMedium.copyWith(
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
