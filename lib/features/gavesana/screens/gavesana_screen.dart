import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../ai_qa/widgets/ai_qa_settings_sheet.dart';
import '../../search/providers/search_provider.dart';
import '../../search/widgets/search_results_view.dart';
import '../providers/ai_search_provider.dart';

/// Full-screen Gavesana AI search.
///
/// The user describes what they're looking for; an AI model plans and runs
/// the searches against the local Tipitaka databases (using the same
/// tool-calling engine as Vimaṃsa), then the passages it gathers are shown
/// in the normal search results format.
class GavesanaScreen extends ConsumerStatefulWidget {
  const GavesanaScreen({super.key});

  @override
  ConsumerState<GavesanaScreen> createState() => _GavesanaScreenState();
}

class _GavesanaScreenState extends ConsumerState<GavesanaScreen> {
  final _queryController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _executeSearch() {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    _focusNode.unfocus();
    ref.read(aiSearchProvider.notifier).search(query);
  }

  void _clearSearch() {
    _queryController.clear();
    ref.read(searchProvider.notifier).clear();
    ref.read(aiSearchProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final aiState = ref.watch(aiSearchProvider);
    final searchState = ref.watch(searchProvider);

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
              loc.gavesana,
              style: AppTypography.headlineSmall.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          // AI settings — the same sheet used by Vimaṃsa (API key, model).
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(Icons.tune, size: 20, color: colors.onSurfaceVariant),
              tooltip: loc.aiQaSettings,
              onPressed: () => showAiQaSettingsSheet(context),
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
                hintText: loc.askAboutTipitaka,
                prefixIcon: IconButton(
                  icon: Icon(Icons.search, color: colors.onSurfaceVariant),
                  onPressed: _executeSearch,
                  tooltip: loc.search,
                ),
                suffixIcon: _queryController.text.isNotEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.search),
                            color: colors.primary,
                            onPressed: _executeSearch,
                            tooltip: loc.search,
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                            tooltip: loc.clear,
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

          const SizedBox(height: AppDimensions.sm),

          // ── Body ────────────────────────────────────────────
          Expanded(child: _buildBody(colors, aiState, searchState, loc)),
        ],
      ),
    );
  }

  Widget _buildBody(
    ColorScheme colors,
    AiSearchState aiState,
    SearchState searchState,
    AppLocalizations loc,
  ) {
    switch (aiState) {
      case AiSearchIdle():
        // Show any existing search results first; otherwise the idle hint.
        if (searchState is SearchResults) {
          return SearchResultsView(state: searchState);
        }
        return _buildIdleState(colors, loc);

      case AiSearchRunning(:final toolLogs):
        return _buildRunningState(colors, loc, toolLogs);

      case AiSearchError(:final message):
        return _buildErrorState(colors, loc, message);

      case AiSearchDone(:final passageCount):
        if (searchState is SearchResults && searchState.totalResults > 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDoneHeader(colors, loc, passageCount),
              Expanded(child: SearchResultsView(state: searchState)),
            ],
          );
        }
        return _buildNoResultsState(colors, loc);
    }
  }

  Widget _buildIdleState(ColorScheme colors, AppLocalizations loc) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.psychology,
                size: 34,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              loc.searchSemantically,
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmall.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 300,
              child: Text(
                loc.gavesanaAiSearchHint,
                textAlign: TextAlign.center,
                style: AppTypography.bodyTranslation.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunningState(
    ColorScheme colors,
    AppLocalizations loc,
    List toolLogs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.marginMobile,
            0,
            AppDimensions.marginMobile,
            AppDimensions.sm,
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  loc.gavesanaSearching,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (toolLogs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.marginMobile,
            ),
            child: Text(
              loc.gavesanaAiTools,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.marginMobile,
              0,
              AppDimensions.marginMobile,
              AppDimensions.bottomToolbarHeight + AppDimensions.lg,
            ),
            itemCount: toolLogs.length,
            itemBuilder: (context, index) {
              final log = toolLogs[index];
              final isLast = index == toolLogs.length - 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isLast ? Icons.radar : Icons.check_circle,
                      size: 16,
                      color: isLast
                          ? colors.primary
                          : colors.tertiary.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        log.resultSummary.isNotEmpty
                            ? log.resultSummary
                            : log.toolName,
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDoneHeader(
    ColorScheme colors,
    AppLocalizations loc,
    int passageCount,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        0,
        AppDimensions.marginMobile,
        AppDimensions.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 14, color: colors.primary),
          const SizedBox(width: 6),
          Text(
            loc.gavesanaAiResults,
            style: AppTypography.labelMedium.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              loc.nResults(passageCount),
              style: AppTypography.labelSmall.copyWith(
                color: colors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(ColorScheme colors, AppLocalizations loc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: colors.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              loc.gavesanaNoResults,
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            FilledButton.tonalIcon(
              onPressed: _executeSearch,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(loc.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    ColorScheme colors,
    AppLocalizations loc,
    String message,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.error),
            const SizedBox(height: AppDimensions.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTranslation.copyWith(
                color: colors.error,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            FilledButton.tonalIcon(
              onPressed: () => showAiQaSettingsSheet(context),
              icon: const Icon(Icons.tune, size: 16),
              label: Text(loc.gavesanaConfigureSettings),
            ),
          ],
        ),
      ),
    );
  }
}
