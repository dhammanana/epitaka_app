import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/translation_registry_provider.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../features/settings/providers/translation_download_provider.dart';
import 'index_controller.dart';
import 'index_state.dart';
import 'indexing_provider.dart';
import 'widgets/download_option_tile.dart';
import 'widgets/translation_option_tile.dart';

/// A gate widget that checks whether the FTS index is built.
///
/// - If the index is ready, [child] is shown.
/// - If not, the index build screen is shown instead, guiding the user
///   to build the search index before proceeding to the app.
class IndexGate extends ConsumerStatefulWidget {
  final Widget child;

  const IndexGate({super.key, required this.child});

  @override
  ConsumerState<IndexGate> createState() => _IndexGateState();
}

class _IndexGateState extends ConsumerState<IndexGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(indexControllerProvider.notifier).checkStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(indexControllerProvider);
    debugPrint('[INDEX_GATE] build: status=${state.status}, '
        'progress=${state.currentProgress}/${state.totalProgress}, '
        'phase=${state.phaseLabel}');

    switch (state.status) {
      case IndexStatus.unknown:
        return _buildLoadingScreen();
      case IndexStatus.ready:
        return widget.child;
      case IndexStatus.needsTranslationChoice:
      case IndexStatus.building:
      case IndexStatus.error:
        return _buildIndexGateScreen(state);
    }
  }

  Widget _buildLoadingScreen() {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colors.primary),
            const SizedBox(height: AppDimensions.md),
            Text(
              'Checking search index…',
              style: AppTypography.labelMedium.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndexGateScreen(IndexState state) {
    final colors = Theme.of(context).colorScheme;
    final availableTranslations = ref.watch(ftsAvailableTranslationsProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.marginMobile),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // App icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                  ),
                  child: Icon(
                    Icons.menu_book,
                    size: 40,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),

                // Title
                Text(
                  'Welcome to ePitaka',
                  style: AppTypography.headlineLarge.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppDimensions.md),

                // Description
                Text(
                  'To enable full-text search, we need to build a search index '
                  'of the Pāli texts and a translation. This will allow you '
                  'to quickly search across all texts.',
                  textAlign: TextAlign.center,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  'The indexing only needs to happen once.\n'
                  'You can rebuild later from Settings.',
                  textAlign: TextAlign.center,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: AppDimensions.xl),

                // Build progress with detailed phase label
                if (state.isBuilding) ...[
                  _buildGateProgress(state, colors),
                ] else if (state.status == IndexStatus.error) ...[
                  Icon(Icons.error_outline, size: 64, color: colors.error),
                  const SizedBox(height: AppDimensions.md),
                  Text(
                    state.errorMessage ?? 'Unknown error',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.error,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.md),
                  FilledButton.icon(
                    onPressed: () {
                      ref.read(indexControllerProvider.notifier).retry();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ] else ...[
                  if (availableTranslations.isEmpty)
                    _buildNoTranslations(colors)
                  else
                    _buildTranslationSelector(availableTranslations, colors),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGateProgress(IndexState state, ColorScheme colors) {
    final progress = state.progressFraction;
    final phaseIcon = _gatePhaseIcon(state.buildPhase);
    final phaseColor = state.buildPhase == IndexBuildPhase.indexingCombined
        ? colors.primary
        : state.buildPhase == IndexBuildPhase.loadingTranslations
            ? const Color(0xff2E7D32)
            : colors.secondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Phase label chip
        if (state.phaseLabel != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: phaseColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(phaseIcon, size: 14, color: phaseColor),
                const SizedBox(width: 4),
                Text(
                  state.phaseLabel!,
                  style: AppTypography.labelSmall.copyWith(
                    color: phaseColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        // Circular progress
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 5,
                  backgroundColor: colors.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(colors.primary),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: AppTypography.labelMedium.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.sm),

        // Sentence count
        if (state.totalProgress > 0)
          Text(
            '${_fmtCount(state.currentProgress)} / ${_fmtCount(state.totalProgress)} sentences',
            style: AppTypography.labelMedium.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),

        // Batch + speed row
        if (state.batchTotal > 0 || state.itemsPerSecond >= 1)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state.batchTotal > 0) ...[  
                  Icon(Icons.list_alt, size: 12, color: colors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Batch ${state.batchCurrent} / ${state.batchTotal}',
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                ],
                if (state.itemsPerSecond >= 1) ...[  
                  Icon(Icons.speed, size: 12, color: colors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '~${state.itemsPerSecond >= 1000 ? "${(state.itemsPerSecond / 1000).toStringAsFixed(1)}k" : state.itemsPerSecond.round().toString()}/s',
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  IconData _gatePhaseIcon(IndexBuildPhase? phase) {
    switch (phase) {
      case IndexBuildPhase.loadingTranslations:
        return Icons.language;
      case IndexBuildPhase.indexingCombined:
        return Icons.merge;
      default:
        return Icons.build;
    }
  }

  String _fmtCount(int n) {
    if (n < 1000) return n.toString();
    final s = n.toString();
    final b = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) b.write(',');
      b.write(s[i]);
      count++;
    }
    return b.toString().split('').reversed.join();
  }

  Widget _buildNoTranslations(ColorScheme colors) {
    final downloadable = ref.watch(ftsDownloadableTranslationsProvider);
    final downloadStates = ref.watch(translationDownloadProvider);

    if (downloadable.isEmpty) {
      return Column(
        children: [
          Icon(
            Icons.cloud_off,
            size: 48,
            color: colors.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppDimensions.md),
          Text(
            'No translations available for download.',
            textAlign: TextAlign.center,
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.cloud_download,
          size: 48,
          color: colors.primary.withValues(alpha: 0.7),
        ),
        const SizedBox(height: AppDimensions.sm),
        Text(
          'Download a translation to get started:',
          textAlign: TextAlign.center,
          style: AppTypography.labelMedium.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        ...downloadable.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DownloadOptionTile(
                translation: t,
                downloadState: downloadStates[t.languageCode] ??
                    const TranslationDownloadState(),
                colors: colors,
              ),
            )),
      ],
    );
  }

  Widget _buildTranslationSelector(
    List<AvailableTranslation> translations,
    ColorScheme colors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose a translation to index:',
          style: AppTypography.labelMedium.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        ...translations.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TranslationOptionTile(
                translation: t,
                onSelect: () {
                  debugPrint('[INDEX_GATE] building index for ${t.languageCode}');                    // Build dialog / gate now uses the controller's built-in logic
                    ref.read(indexControllerProvider.notifier).retry();
                },
                colors: colors,
              ),
            )),
      ],
    );
  }
}
