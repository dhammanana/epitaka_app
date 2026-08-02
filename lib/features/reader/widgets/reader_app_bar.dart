import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
