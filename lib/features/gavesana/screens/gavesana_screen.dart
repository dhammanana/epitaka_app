import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../providers/gavesana_download_provider.dart';
import '../providers/gavesana_provider.dart';
import 'gavesana_fts_build_dialog.dart';

/// Full-screen Gavesana semantic search.
///
/// Users type a query, Gavesana finds semantically related passages
/// using vector search, and results show Pāli + translation text
/// with a similarity score badge.
class GavesanaScreen extends ConsumerStatefulWidget {
  const GavesanaScreen({super.key});

  @override
  ConsumerState<GavesanaScreen> createState() => _GavesanaScreenState();
}

class _GavesanaScreenState extends ConsumerState<GavesanaScreen> {
  final _queryController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _initializing = false;
  int _topK = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initIfReady();
      _focusNode.requestFocus();
    });
  }

  void _initIfReady() {
    final notifier = ref.read(gavesanaProvider.notifier);
    if (!notifier.isInitialized) {
      setState(() => _initializing = true);
      notifier
          .init()
          .then((_) {
            if (mounted) setState(() => _initializing = false);
            _maybePromptBm25Build();
          })
          .catchError((_) {
            if (mounted) setState(() => _initializing = false);
          });
    } else {
      _maybePromptBm25Build();
    }
  }

  /// Show the BM25 build dialog automatically if the index hasn't been
  /// built yet. The user can dismiss it and still use vector search.
  void _maybePromptBm25Build() {
    final notifier = ref.read(gavesanaProvider.notifier);
    if (notifier.isInitialized && !notifier.isBm25IndexBuilt && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) GavesanaFtsBuildDialog.show(context);
      });
    }
  }

  void _navigateToSettings(BuildContext context) {
    context.push('/settings');
  }

  @override
  void dispose() {
    _queryController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _executeSearch() {
    final query = _queryController.text.trim();
    if (query.isNotEmpty) {
      ref.read(gavesanaProvider.notifier).search(query, topK: _topK);
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = ref.watch(gavesanaProvider);
    final notifier = ref.read(gavesanaProvider.notifier);
    final assetsReady = ref.watch(gavesanaAssetsReadyProvider);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: AppDimensions.appBarHeight,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: colors.onSurfaceVariant,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.psychology, size: 16, color: colors.primary),
            ),
            const SizedBox(width: 8),
            Text(
              'Gavesana',
              style: AppTypography.headlineSmall.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          // Assets status indicator — clickable when not ready
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: assetsReady.when(
              data: (ready) => ready
                  ? Icon(Icons.check_circle, size: 16, color: colors.tertiary)
                  : GestureDetector(
                      onTap: () => _navigateToSettings(context),
                      child: Tooltip(
                        message: 'Download AI assets in Settings',
                        child: Icon(
                          Icons.cloud_download,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
              loading: () => const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) =>
                  Icon(Icons.warning, size: 16, color: colors.error),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.marginMobile,
              AppDimensions.sm,
              AppDimensions.marginMobile,
              0,
            ),
            child: TextField(
              controller: _queryController,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Ask about the Tipitaka…',
                prefixIcon: IconButton(
                  icon: Icon(Icons.search, color: colors.onSurfaceVariant),
                  onPressed: _executeSearch,
                  tooltip: 'Search',
                ),
                suffixIcon: _queryController.text.isNotEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.search),
                            color: colors.primary,
                            onPressed: _executeSearch,
                            tooltip: 'Search',
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _queryController.clear();
                            },
                            tooltip: 'Clear',
                          ),
                        ],
                      )
                    : null,
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md,
                  vertical: 12,
                ),
              ),
              style: AppTypography.bodyPali.copyWith(
                fontSize: 16,
                color: colors.onSurface,
              ),
              onSubmitted: (_) => _executeSearch(),
            ),
          ),

          // ── Options bar ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.marginMobile,
              AppDimensions.sm,
              AppDimensions.marginMobile,
              0,
            ),
            child: Row(
              children: [
                // Top-K selector
                PopupMenuButton<int>(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Number of results',
                  initialValue: _topK,
                  onSelected: (val) {
                    setState(() => _topK = val);
                    if (_queryController.text.isNotEmpty) _executeSearch();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 5,
                      child: Text('Show 5 results'),
                    ),
                    const PopupMenuItem(
                      value: 10,
                      child: Text('Show 10 results'),
                    ),
                    const PopupMenuItem(
                      value: 20,
                      child: Text('Show 20 results'),
                    ),
                    const PopupMenuItem(
                      value: 50,
                      child: Text('Show 50 results'),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.format_list_numbered,
                          size: 14,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_topK results',
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Build / Rebuild BM25 index button (always available)
                TextButton.icon(
                  onPressed: () => GavesanaFtsBuildDialog.show(
                    context,
                    rebuild: notifier.isBm25IndexBuilt,
                  ),
                  icon: Icon(
                    notifier.isBm25IndexBuilt
                        ? Icons.refresh
                        : Icons.text_fields,
                    size: 14,
                  ),
                  label: Text(
                    notifier.isBm25IndexBuilt ? 'Rebuild BM25' : 'Build BM25',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),

                // Result count
                if (state == GavesanaState.ready && notifier.results.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSm,
                      ),
                    ),
                    child: Text(
                      '${notifier.results.length} result${notifier.results.length == 1 ? '' : 's'}',
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Vector/BM25 weight slider ─────────────────────────
          if (state == GavesanaState.ready && notifier.results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.marginMobile,
                AppDimensions.xs,
                AppDimensions.marginMobile,
                0,
              ),
              child: Row(
                children: [
                  Icon(Icons.hub, size: 14, color: colors.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Vector ${((notifier.vectorWeight) * 100).toStringAsFixed(0)}%',
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: notifier.vectorWeight,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      onChanged: (v) {
                        setState(() => notifier.vectorWeight = v);
                        notifier.rerank();
                      },
                    ),
                  ),
                  Text(
                    'BM25 ${((1 - notifier.vectorWeight) * 100).toStringAsFixed(0)}%',
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.text_fields,
                    size: 14,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppDimensions.sm),

          // ── Body ────────────────────────────────────────────
          Expanded(child: _buildBody(colors, state, notifier, assetsReady)),
        ],
      ),
    );
  }

  Widget _buildBody(
    ColorScheme colors,
    GavesanaState state,
    GavesanaNotifier notifier,
    AsyncValue<bool> assetsReady,
  ) {
    // Initializing
    if (_initializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 12),
            Text('Loading Gavesana…'),
          ],
        ),
      );
    }

    // Error state
    if (state == GavesanaState.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.error),
              const SizedBox(height: 12),
              Text(
                notifier.errorMessage ?? 'An error occurred',
                style: AppTypography.bodyTranslation.copyWith(
                  color: colors.error,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () {
                  setState(() => _initializing = true);
                  notifier.init().then((_) {
                    if (mounted) setState(() => _initializing = false);
                  });
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Assets not ready
    return assetsReady.when(
      data: (ready) {
        if (!ready) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_download,
                    size: 48,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Gavesana AI assets not found.',
                    style: AppTypography.bodyTranslation.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Download them in Settings.',
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Loading states
        if (state == GavesanaState.loadingModel) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(height: 12),
                Text('Loading models…'),
              ],
            ),
          );
        }

        if (state == GavesanaState.embedding) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(height: 12),
                Text('Computing query embedding…'),
              ],
            ),
          );
        }

        if (state == GavesanaState.searching) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(height: 12),
                Text('Searching vector database…'),
              ],
            ),
          );
        }

        // Ready state with results
        if (state == GavesanaState.ready && notifier.results.isNotEmpty) {
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.marginMobile,
              0,
              AppDimensions.marginMobile,
              AppDimensions.bottomToolbarHeight + AppDimensions.lg,
            ),
            itemCount: notifier.results.length,
            itemBuilder: (context, index) {
              return _GavesanaResultCard(
                hit: notifier.results[index],
                index: index,
              );
            },
          );
        }

        // Idle state
        return _buildIdleState(colors);
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildIdleState(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.psychology,
            size: 56,
            color: colors.primary.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Search semantically across the Tipitaka',
            style: AppTypography.headlineSmall.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 280,
            child: Text(
              'Gavesana uses AI to find passages related to your\n'
              'query, even if they don\'t share exact words.',
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Result Card ──────────────────────────────────────────────────────────

class _GavesanaResultCard extends ConsumerWidget {
  final GavesanaSearchHit hit;
  final int index;

  const _GavesanaResultCard({required this.hit, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigateToResult(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row: book name + similarity badge ────
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.import_contacts,
                      size: 14,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hit.bookName.isNotEmpty ? hit.bookName : hit.bookId,
                      style: AppTypography.labelMedium.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Similarity badge — shows vector cosine + RRF score
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: hit.displayScore > 0.7
                          ? colors.tertiaryContainer
                          : (hit.displayScore > 0.5
                                ? colors.secondaryContainer
                                : colors.surfaceContainerHighest),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.trending_up,
                          size: 10,
                          color: hit.displayScore > 0.7
                              ? colors.onTertiaryContainer
                              : colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'V ${(hit.similarity * 100).toStringAsFixed(0)}%',
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: hit.displayScore > 0.7
                                ? colors.onTertiaryContainer
                                : colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '· RRF ${(hit.rrfScore).toStringAsFixed(4)}',
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: hit.displayScore > 0.7
                                ? colors.onTertiaryContainer
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Location info ──────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Text(
                  'Para ${hit.startPara} – ${hit.endPara} · Line ${hit.startLine} – ${hit.endLine}',
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 10,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),

              // ── Pāli text ──────────────────────────────────
              if (hit.paliText.isNotEmpty)
                PaliText(
                  hit.paliText,
                  style: AppTypography.bodyPali.copyWith(
                    color: colors.onSurface,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

              // ── Translation text ───────────────────────────
              if (hit.translation.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    hit.translation,
                    style: AppTypography.bodyTranslation.copyWith(
                      color: colors.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToResult(BuildContext context, WidgetRef ref) {
    ref
        .read(readerTabsProvider.notifier)
        .openTab(
          ReaderTabInfo(
            bookId: hit.bookId,
            bookName: hit.bookName.isNotEmpty ? hit.bookName : hit.bookId,
            initialParaId: hit.startPara,
            initialLineId: hit.startLine,
          ),
        );
    context.push('/reader');
  }
}
