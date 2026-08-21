import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/velthuis.dart';
import '../../ai_qa/widgets/ai_qa_settings_sheet.dart';
import '../../search/providers/search_provider.dart';
import '../../search/widgets/search_results_view.dart';
import '../providers/ai_search_provider.dart';

/// Shared Gavesana AI search UI.
///
/// Contains the query bar and the live AI search states (idle hint,
/// running log, error, results). Used in two places so desktop and mobile
/// get the same search experience:
///
///   * **Desktop sidebar** — embedded directly in [GavesanaPanel] (dense
///     padding, no AppBar to host the AI-settings button, so the widget
///     provides its own).
///   * **Full screen** — the body of [GavesanaScreen].
class GavesanaSearchView extends ConsumerStatefulWidget {
  /// Focus the query field as soon as the widget is built.
  final bool autoFocus;

  /// Compact padding for narrow sidebar panels (vs. full-screen margins).
  final bool dense;

  const GavesanaSearchView({
    super.key,
    this.autoFocus = false,
    this.dense = false,
  });

  @override
  ConsumerState<GavesanaSearchView> createState() => _GavesanaSearchViewState();
}

class _GavesanaSearchViewState extends ConsumerState<GavesanaSearchView> {
  final _queryController = TextEditingController();
  final _focusNode = FocusNode();

  /// Prevents re-entry while the controller text is being updated after
  /// Velthuis conversion (the value setter notifies listeners synchronously).
  bool _isConverting = false;

  double get _hPad =>
      widget.dense ? AppDimensions.sm : AppDimensions.marginMobile;

  @override
  void initState() {
    super.initState();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Applies Velthuis conversion on-the-fly while typing (same behavior as
  /// the regular search boxes): `dhamma.m` becomes `dhammaṃ`, `raaga`
  /// becomes `rāga`, and any non-Roman script is converted to IAST Roman.
  void _onSearchChanged(String value) {
    // Prevent re-entry when updating the controller text after conversion.
    if (_isConverting) return;

    final converted = velthuis(value);
    if (converted != value && converted.trim().isNotEmpty) {
      _isConverting = true;
      _queryController.value = convertedTextEditingValue(
        _queryController.value,
      );
      _isConverting = false;
    }

    // Refresh the suffix (clear) button visibility.
    setState(() {});
  }

  void _executeSearch() {
    final query = velthuis(_queryController.text.trim());
    if (query.isEmpty) return;
    _focusNode.unfocus();
    ref.read(aiSearchProvider.notifier).search(query);
  }

  void _clearSearch() {
    _queryController.clear();
    ref.read(searchProvider.notifier).clear();
    ref.read(aiSearchProvider.notifier).reset();
    setState(() {});
  }

  /// Run a new AI search for [term] (used by the term chips).
  void _searchTerm(String term) {
    _queryController.text = term;
    ref.read(aiSearchProvider.notifier).search(term);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final aiState = ref.watch(aiSearchProvider);
    final searchState = ref.watch(searchProvider);

    return Column(
      children: [
        // ── Search bar + AI settings ─────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(_hPad, AppDimensions.sm, _hPad, 0),
          child: Row(
            children: [
              Expanded(child: _buildSearchField(colors, loc)),
              const SizedBox(width: 4),
              // AI settings — the same sheet used by Vimaṃsa (API key,
              // model). Lives here (not an AppBar) so the sidebar panel
              // gets it too.
              IconButton(
                icon: Icon(
                  Icons.tune,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
                tooltip: loc.vimamsaSettings,
                visualDensity: VisualDensity.compact,
                onPressed: () => showAiQaSettingsSheet(context),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppDimensions.sm),

        // ── Body ─────────────────────────────────────────────
        Expanded(child: _buildBody(colors, aiState, searchState, loc)),
      ],
    );
  }

  Widget _buildSearchField(ColorScheme colors, AppLocalizations loc) {
    return TextField(
      controller: _queryController,
      focusNode: _focusNode,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: loc.askAboutTipitaka,
        isDense: widget.dense,
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
          borderRadius: BorderRadius.circular(
            widget.dense ? AppDimensions.radiusLg : AppDimensions.radiusXl,
          ),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: widget.dense ? AppDimensions.sm : AppDimensions.md,
          vertical: widget.dense ? 8 : 12,
        ),
      ),
      style: AppTypography.bodyPali.copyWith(
        fontSize: widget.dense ? 14 : 16,
        color: colors.onSurface,
      ),
      onChanged: _onSearchChanged,
      onSubmitted: (_) => _executeSearch(),
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

      case AiSearchRunning(:final toolLogs, :final termsUsed):
        return _buildRunningState(colors, loc, toolLogs, termsUsed);

      case AiSearchError(:final message):
        return _buildErrorState(colors, loc, message);

      case AiSearchDone(:final passageCount, :final termsUsed):
        if (searchState is SearchResults && searchState.totalResults > 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDoneHeader(colors, loc, passageCount),
              if (termsUsed.isNotEmpty) _buildTermsRow(colors, loc, termsUsed),
              const SizedBox(height: AppDimensions.sm),
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
              child: Icon(Icons.psychology, size: 34, color: colors.primary),
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
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
    List<String> termsUsed,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(_hPad, 0, _hPad, AppDimensions.sm),
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
        if (termsUsed.isNotEmpty) _buildTermsRow(colors, loc, termsUsed),
        if (toolLogs.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _hPad),
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
            padding: EdgeInsets.fromLTRB(
              _hPad,
              0,
              _hPad,
              widget.dense
                  ? AppDimensions.lg
                  : AppDimensions.bottomToolbarHeight + AppDimensions.lg,
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

  /// Row of tappable chips for the search terms the AI actually used.
  /// Tapping a chip re-runs the search with that exact term — a quick way
  /// to refine when the results aren't what you wanted.
  Widget _buildTermsRow(
    ColorScheme colors,
    AppLocalizations loc,
    List<String> terms,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(_hPad, 0, _hPad, AppDimensions.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.gavesanaAiTerms,
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final term in terms)
                ActionChip(
                  label: Text(
                    term,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.primary,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: colors.primaryContainer.withValues(
                    alpha: 0.25,
                  ),
                  side: BorderSide(color: colors.outlineVariant),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _searchTerm(term),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoneHeader(
    ColorScheme colors,
    AppLocalizations loc,
    int passageCount,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(_hPad, 0, _hPad, AppDimensions.sm),
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
