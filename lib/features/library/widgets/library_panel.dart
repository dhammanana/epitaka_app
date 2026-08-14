import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/responsive_breakpoint.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import 'bookmarks_panel.dart';
import 'history_tabs.dart';
import 'library_browser.dart';

/// A compact library panel for the left sidebar on desktop.
///
/// Contains three tabs: Browse (Tipitaka book tree), Reading (open tabs +
/// reading/listening history), and Bookmarks (saved positions).
class LibraryPanel extends ConsumerStatefulWidget {
  /// When true, the type-to-filter field in the Browse tab is focused once
  /// the panel is built (used by the Cmd/Ctrl+L shortcut).
  final bool autoFocus;

  const LibraryPanel({super.key, this.autoFocus = false});

  @override
  ConsumerState<LibraryPanel> createState() => _LibraryPanelState();
}

class _LibraryPanelState extends ConsumerState<LibraryPanel> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final tabs = [loc.browse, loc.reading, loc.bookmarks];

    return Column(
      children: [
        // ── Compact segmented control ────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.sm, AppDimensions.sm, AppDimensions.sm, 0,
          ),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Row(
              children: [
                for (final (i, label) in tabs.indexed)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.xs,
                          horizontal: AppDimensions.sm,
                        ),
                        decoration: BoxDecoration(
                          color: i == _selectedIndex
                              ? colors.surface
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSm),
                          boxShadow: i == _selectedIndex
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (i == _selectedIndex)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  i == 0
                                      ? Icons.menu_book
                                      : i == 1
                                          ? Icons.tab
                                          : Icons.bookmark,
                                  size: 12,
                                  color: colors.primary,
                                ),
                              ),
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              style: AppTypography.labelSmall.copyWith(
                                color: i == _selectedIndex
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                                fontWeight: i == _selectedIndex
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.sm),
        // ── Tab content ───────────────────────────────────────────
        Expanded(
          child: _buildTabContent(colors),
        ),
      ],
    );
  }

  Widget _buildTabContent(ColorScheme colors) {
    switch (_selectedIndex) {
      case 1:
        return _ReadingTab(colors: colors);
      case 2:
        return const BookmarksPanel();
      default:
        return LibraryBrowser(
          maxWidth: double.infinity,
          autoFocusFilter: widget.autoFocus,
        );
    }
  }
}

// ── Reading Tab ─────────────────────────────────────────────────────────

class _ReadingTab extends ConsumerWidget {
  final ColorScheme colors;
  const _ReadingTab({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabsState = ref.watch(readerTabsProvider);
    final loc = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
      children: [
        // Open Tabs (or a hint) — history is always shown below.
        if (tabsState.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tab, size: 24, color: colors.outlineVariant),
                  const SizedBox(height: AppDimensions.xs),
                  Text(
                    loc.noBooksOpenShort,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  loc.openTabs,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${tabsState.tabs.length}',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ...tabsState.tabs.map((tab) => _OpenTabCard(
                tab: tab,
                colors: colors,
                onTap: () {
                  ref.read(readerTabsProvider.notifier).switchTo(
                        tabsState.tabs.indexOf(tab),
                      );
                  if (!ResponsiveBreakpoint.isDesktop(context)) {
                    context.push('/reader');
                  }
                },
                onClose: () {
                  final index = tabsState.tabs.indexOf(tab);
                  if (index >= 0) {
                    ref.read(readerTabsProvider.notifier).closeTab(index);
                  }
                },
              )),
        ],
        const SizedBox(height: AppDimensions.sm),
        // History with Reading / Listening sub-tabs (open books in place —
        // the reader is already shown in the desktop main area)
        HistoryTabsSection(colors: colors, compact: true, openBookInPlace: true),
      ],
    );
  }
}

class _OpenTabCard extends ConsumerWidget {
  final ReaderTabInfo tab;
  final ColorScheme colors;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _OpenTabCard({
    required this.tab,
    required this.colors,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final script = ref.watch(settingsProvider).paliScript;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        side: BorderSide(color: colors.outlineVariant, width: 0.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(children: [
            Expanded(
              child: PaliTextStatic(
                tab.bookName,
                script,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: Icon(Icons.close, size: 14, color: colors.outline),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ]),
        ),
      ),
    );
  }
}

