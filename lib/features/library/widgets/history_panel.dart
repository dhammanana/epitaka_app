import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import 'history_tabs.dart';

/// A self-contained history panel for the desktop sidebar.
///
/// Shows the currently open reader tabs on top, then the reading/listening
/// history below. Opening an entry only switches the reader tab in place
/// (the reader is always visible in the desktop main area).
class HistoryPanel extends ConsumerWidget {
  const HistoryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final tabsState = ref.watch(readerTabsProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
      children: [
        // ── Open tabs ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.tab, size: 14, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                loc.openTabs,
                style: AppTypography.labelMedium.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (tabsState.isNotEmpty)
                Text(
                  '${tabsState.tabs.length}',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
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
        else
          ...tabsState.tabs.indexed.map(
            (entry) => _OpenTabCard(
              tab: entry.$2,
              colors: colors,
              onTap: () {
                ref
                    .read(readerTabsProvider.notifier)
                    .switchTo(entry.$1);
              },
              onClose: () {
                ref
                    .read(readerTabsProvider.notifier)
                    .closeTab(entry.$1);
              },
            ),
          ),
        const SizedBox(height: AppDimensions.sm),
        // ── Reading / Listening history ──────────────────────────
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
