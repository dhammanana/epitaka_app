import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_db_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../shared/utils/app_navigation.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../providers/heading_title_provider.dart';

/// History section with two sub-tabs: **Reading** history (as before) and
/// **Listening** history (books played with TTS).
///
/// Shared by the full-screen [LibraryScreen] Reading tab and the compact
/// desktop sidebar panel ([LibraryPanel]).
class HistoryTabsSection extends ConsumerStatefulWidget {
  final ColorScheme colors;

  /// Compact styling for the desktop sidebar panel.
  final bool compact;

  /// When true (desktop sidebar panel), opening an entry only switches the
  /// reader tab in place instead of navigating to the reader route.
  final bool openBookInPlace;

  const HistoryTabsSection({
    super.key,
    required this.colors,
    this.compact = false,
    this.openBookInPlace = false,
  });

  @override
  ConsumerState<HistoryTabsSection> createState() => _HistoryTabsSectionState();
}

class _HistoryTabsSectionState extends ConsumerState<HistoryTabsSection> {
  /// 0 = Reading history, 1 = Listening history.
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final loc = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ─────────────────────────────────────────────────
        Row(
          children: [
            Icon(Icons.history, size: widget.compact ? 16 : 18, color: colors.tertiary),
            const SizedBox(width: 8),
            Text(
              loc.history,
              style: AppTypography.headlineSmall.copyWith(
                color: colors.tertiary,
                fontWeight: FontWeight.w600,
                fontSize: widget.compact ? 16 : 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // ── Reading / Listening sub-tab bar ─────────────────────────
        _HistoryTabBar(
          selectedIndex: _selectedTab,
          colors: colors,
          compact: widget.compact,
          onChanged: (i) => setState(() => _selectedTab = i),
        ),
        const SizedBox(height: 10),
        // ── List ───────────────────────────────────────────────────
        if (_selectedTab == 0)
          _ReadingHistoryList(
            colors: colors,
            compact: widget.compact,
            openBookInPlace: widget.openBookInPlace,
          )
        else
          _ListeningHistoryList(
            colors: colors,
            compact: widget.compact,
            openBookInPlace: widget.openBookInPlace,
          ),
      ],
    );
  }
}

// ── Sub-tab bar (Reading | Listening) ─────────────────────────────────

class _HistoryTabBar extends StatelessWidget {
  final int selectedIndex;
  final ColorScheme colors;
  final bool compact;
  final ValueChanged<int> onChanged;

  const _HistoryTabBar({
    required this.selectedIndex,
    required this.colors,
    required this.compact,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final tabs = [
      (Icons.menu_book, loc.reading),
      (Icons.headphones, loc.listening),
    ];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        children: [
          for (final (i, tab) in tabs.indexed)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    vertical: compact ? 5 : 8,
                    horizontal: AppDimensions.sm,
                  ),
                  decoration: BoxDecoration(
                    color: i == selectedIndex
                        ? colors.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusSm,
                    ),
                    boxShadow: i == selectedIndex
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
                      Icon(
                        tab.$1,
                        size: compact ? 12 : 14,
                        color: i == selectedIndex
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          tab.$2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall.copyWith(
                            color: i == selectedIndex
                                ? colors.primary
                                : colors.onSurfaceVariant,
                            fontWeight: i == selectedIndex
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: compact ? 11 : 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Reading history list ──────────────────────────────────────────────

class _ReadingHistoryList extends ConsumerWidget {
  final ColorScheme colors;
  final bool compact;
  final bool openBookInPlace;

  const _ReadingHistoryList({
    required this.colors,
    required this.compact,
    required this.openBookInPlace,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final historyAsync = ref.watch(historyProvider);

    return historyAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '${loc.errorLoadingHistory} $e',
          style: AppTypography.labelSmall.copyWith(color: colors.error),
        ),
      ),
      data: (history) {
        if (history.isEmpty) {
          return _HistoryEmpty(
            icon: Icons.history,
            message: loc.noHistory,
            colors: colors,
            compact: compact,
          );
        }
        return Column(
          children: history
              .map(
                (entry) => _HistoryCard(
                  bookId: entry.bookId,
                  bookName: entry.bookName,
                  paraId: entry.paraId,
                  lineId: entry.lineId,
                  updatedAt: entry.updatedAt,
                  count: entry.readCount,
                  icon: Icons.history,
                  colors: colors,
                  compact: compact,
                  onTap: () => openBookInReader(context, ref,
                      bookId: entry.bookId,
                      bookName: entry.bookName,
                      paraId: entry.paraId,
                      lineId: entry.lineId,
                      inPlace: openBookInPlace),
                  onDelete: () => confirmDeleteHistoryEntry(
                    context,
                    ref,
                    label: entry.bookName ?? entry.bookId,
                    onDelete: () async {
                      final db = await ref.read(appDbProvider.future);
                      await db.deleteHistoryEntry(entry.id);
                      ref.invalidate(historyProvider);
                    },
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

// ── Listening history list ────────────────────────────────────────────

class _ListeningHistoryList extends ConsumerWidget {
  final ColorScheme colors;
  final bool compact;
  final bool openBookInPlace;

  const _ListeningHistoryList({
    required this.colors,
    required this.compact,
    required this.openBookInPlace,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final historyAsync = ref.watch(listeningHistoryProvider);

    return historyAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '${loc.errorLoadingHistory} $e',
          style: AppTypography.labelSmall.copyWith(color: colors.error),
        ),
      ),
      data: (history) {
        if (history.isEmpty) {
          return _HistoryEmpty(
            icon: Icons.headphones,
            message: loc.noListeningHistory,
            colors: colors,
            compact: compact,
          );
        }
        return Column(
          children: history
              .map(
                (entry) => _HistoryCard(
                  bookId: entry.bookId,
                  bookName: entry.bookName,
                  paraId: entry.paraId,
                  lineId: entry.lineId,
                  updatedAt: entry.updatedAt,
                  count: entry.listenCount,
                  icon: Icons.headphones,
                  colors: colors,
                  compact: compact,
                  onTap: () => openBookInReader(context, ref,
                      bookId: entry.bookId,
                      bookName: entry.bookName,
                      paraId: entry.paraId,
                      lineId: entry.lineId,
                      inPlace: openBookInPlace),
                  onDelete: () => confirmDeleteHistoryEntry(
                    context,
                    ref,
                    label: entry.bookName ?? entry.bookId,
                    onDelete: () async {
                      final db = await ref.read(appDbProvider.future);
                      await db.deleteListeningHistoryEntry(entry.id);
                      ref.invalidate(listeningHistoryProvider);
                    },
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────

class _HistoryEmpty extends StatelessWidget {
  final IconData icon;
  final String message;
  final ColorScheme colors;
  final bool compact;

  const _HistoryEmpty({
    required this.icon,
    required this.message,
    required this.colors,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(          padding: EdgeInsets.symmetric(vertical: compact ? 12 : 24),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: compact ? 22 : 36, color: colors.outlineVariant),
            SizedBox(height: compact ? 6 : 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTranslation.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: compact ? 12 : 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── History card ──────────────────────────────────────────────────────

class _HistoryCard extends ConsumerWidget {
  final String bookId;
  final String? bookName;
  final int? paraId;
  final int? lineId;
  final DateTime updatedAt;
  final int count;
  final IconData icon;
  final ColorScheme colors;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.bookId,
    this.bookName,
    this.paraId,
    this.lineId,
    required this.updatedAt,
    required this.count,
    required this.icon,
    required this.colors,
    required this.compact,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final script = ref.watch(settingsProvider).paliScript;

    // Look up the nearest heading title for a nicer main title.
    final headingAsync = paraId != null
        ? ref.watch(
            headingTitleProvider(
              HeadingQuery(bookId: bookId, paraId: paraId!),
            ),
          )
        : null;
    final headingTitle = headingAsync?.when(
      data: (t) => t,
      loading: () => null,
      error: (_, _) => null,
    );
    final mainTitle =
        headingTitle ?? (paraId != null ? 'Para $paraId' : null);

    return Card(
      margin: EdgeInsets.only(bottom: compact ? 4 : 6),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          compact ? AppDimensions.radiusSm : AppDimensions.radiusMd,
        ),
        side: BorderSide(color: colors.outlineVariant, width: 0.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          compact ? AppDimensions.radiusSm : AppDimensions.radiusMd,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 16,
            vertical: compact ? 8 : 12,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 26 : 32,
                height: compact ? 26 : 32,
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(compact ? 6 : 8),
                ),
                child: Icon(
                  icon,
                  size: compact ? 13 : 16,
                  color: colors.tertiary,
                ),
              ),
              SizedBox(width: compact ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (mainTitle != null)
                      PaliTextStatic(
                        mainTitle,
                        script,
                        style: AppTypography.bodyTranslation.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: compact ? 13 : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Padding(
                      padding: EdgeInsets.only(top: mainTitle != null ? 2 : 0),
                      child: PaliTextStatic(
                        bookName ?? bookId,
                        script,
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: compact ? 11 : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Timestamp + count
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Text(
                            formatTimeAgo(updatedAt, loc),
                            style: AppTypography.labelSmall.copyWith(
                              color: colors.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                          if (count > 1) ...[
                            const SizedBox(width: 8),
                            Icon(
                              icon == Icons.headphones
                                  ? Icons.play_circle_outline
                                  : Icons.touch_app,
                              size: 10,
                              color: colors.outline,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$count',
                              style: AppTypography.labelSmall.copyWith(
                                color: colors.outline,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  size: compact ? 14 : 16,
                  color: colors.error.withValues(alpha: 0.6),
                ),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: compact ? 24 : 28,
                  minHeight: compact ? 24 : 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────

/// Open a history entry in the reader (switching/opening the tab), then
/// navigate to the reader route — unless [inPlace] is set (desktop sidebar
/// panel), in which case only the active tab is switched.
void openBookInReader(
  BuildContext context,
  WidgetRef ref, {
  required String bookId,
  String? bookName,
  int? paraId,
  int? lineId,
  bool inPlace = false,
}) {
  ref.read(readerTabsProvider.notifier).openTab(
        ReaderTabInfo(
          bookId: bookId,
          bookName: bookName ?? bookId,
          initialParaId: paraId,
          initialLineId: lineId,
        ),
      );
  if (!inPlace) {
    openReaderRoute(context);
  }
}

/// Show the delete-confirmation dialog for a history entry, then delete.
Future<void> confirmDeleteHistoryEntry(
  BuildContext context,
  WidgetRef ref, {
  required String label,
  required Future<void> Function() onDelete,
}) async {
  final loc = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(loc.removeHistoryEntry),
      content: Text(loc.deleteHistoryEntryConfirm(label)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(loc.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: Text(loc.delete),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await onDelete();
  } catch (_) {
    // Silently fail — deletion is non-critical
  }
}

/// Human-friendly relative timestamp, e.g. "Just now", "5m ago", "2h ago".
String formatTimeAgo(DateTime dt, AppLocalizations loc) {
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inMinutes < 1) return loc.justNow;
  if (diff.inMinutes < 60) return '${diff.inMinutes} ${loc.minutesAgo}';
  if (diff.inHours < 24) return '${diff.inHours} ${loc.hoursAgo}';
  if (diff.inDays < 7) return '${diff.inDays} ${loc.daysAgo}';
  return '${dt.month}/${dt.day}/${dt.year}';
}
