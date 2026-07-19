import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/translation_version.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../features/settings/providers/translation_download_provider.dart';
import '../../features/settings/widgets/color_swatch.dart' as swatch;
import 'index_controller.dart';
import 'index_state.dart';
import 'indexing_provider.dart';

/// A gate widget that checks whether the FTS index is built.
///
/// - If the index is ready, [child] is shown.
/// - If not, the index build setup wizard is shown instead, guiding the user
///   to download translations and build the search index.
class IndexGate extends ConsumerStatefulWidget {
  final Widget child;

  const IndexGate({super.key, required this.child});

  @override
  ConsumerState<IndexGate> createState() => _IndexGateState();
}

class _IndexGateState extends ConsumerState<IndexGate>
    with SingleTickerProviderStateMixin {
  /// Whether the controller has completed its initial check.
  bool _initialCheckDone = false;

  /// Whether the user has started building.
  bool _buildStarted = false;

  /// Animation controller for step transitions.
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  /// Predefined color options for Pāli and translation text.
  static const List<Color> _paliColors = [
    Color(0xFF7A2E1D), // Default warm brown
    Color(0xFF1A1A2E), // Deep navy
    Color(0xFF2D201A), // Dark sepia
    Color(0xFF4A2C2A), // Mahogany
    Color(0xFF5B3A29), // Dark amber
    Color(0xFF1B3A2D), // Forest
  ];

  static const List<Color> _transColors = [
    Color(0xFF33312E), // Default dark gray
    Color(0xFF1E3A5F), // Slate blue
    Color(0xFF2D3A3A), // Dark teal
    Color(0xFF3A2D2D), // Warm gray
    Color(0xFF1A2A3A), // Midnight
    Color(0xFF3A2A2A), // Coffee
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _animCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _initialCheckDone = true);
        ref.read(indexControllerProvider.notifier).checkStatus();
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(indexControllerProvider);
    debugPrint(
        '[INDEX_GATE] build: status=${state.status}, built=${state.isBuilt}, building=${state.isBuilding}');

    if (state.isBuilt) {
      return widget.child;
    }

    // First frame (before postFrameCallback fires): show loading
    if (!_initialCheckDone) {
      return _buildLoadingScreen();
    }

    if (state.isBuilding && _buildStarted) {
      return _buildBuildStep(state);
    }

    if (state.status == IndexStatus.error) {
      return _buildErrorScreen(state);
    }

    // Not built - show setup wizard
    return _buildSetupWizard(state);
  }

  Widget _buildLoadingScreen() {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search,
                size: 48, color: colors.primary.withValues(alpha: 0.5)),
            const SizedBox(height: AppDimensions.md),
            Text(
              'Checking search index…',
              style: AppTypography.labelMedium
                  .copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: AppDimensions.sm),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(IndexState state) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.marginMobile),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 64, color: colors.error),
                const SizedBox(height: AppDimensions.md),
                Text(
                  'Something went wrong',
                  style: AppTypography.headlineSmall.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  state.errorMessage ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: AppTypography.labelSmall
                      .copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: AppDimensions.lg),
                FilledButton.icon(
                  onPressed: () {
                    ref.read(indexControllerProvider.notifier).retry();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 1: Setup Wizard (Download + Colors) ────────────────────────

  Widget _buildSetupWizard(IndexState state) {
    final colors = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final settings = ref.watch(settingsProvider);
    final availableAsync = ref.watch(ftsAvailableVersionsProvider);
    final downloadableAsync = ref.watch(ftsDownloadableVersionsProvider);

    // Show loading while manifest is being fetched
    final isLoading = availableAsync.isLoading || downloadableAsync.isLoading;
    if (isLoading) {
      return _buildWizardLoading(colors);
    }

    // Build version list from async data (data is now available)
    final versions = <TranslationVersion>[];
    availableAsync.whenData((v) => versions.addAll(v));
    downloadableAsync.whenData((v) => versions.addAll(v));
    versions.sort((a, b) {
      if (a.isAvailable && !b.isAvailable) return -1;
      if (!a.isAvailable && b.isAvailable) return 1;
      final cmp = a.englishName.compareTo(b.englishName);
      if (cmp != 0) return cmp;
      return (a.displayName).compareTo(b.displayName);
    });

    final hasAnyDownloaded = versions.any((v) => v.isAvailable);

    // Determine current Pāli and translation colors
    final paliColor = settings.paliColorFor(brightness);
    final transColor = settings.translationColorFor(brightness);

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.marginMobile,
                  AppDimensions.lg,
                  AppDimensions.marginMobile,
                  0,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusXl),
                      ),
                      child: Icon(
                        Icons.menu_book,
                        size: 36,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.md),
                    Text(
                      'Welcome to ePitaka',
                      style: AppTypography.headlineLarge.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Set up your translations to get started.',
                      style: AppTypography.labelMedium
                          .copyWith(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You can change these settings later.',
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.lg),

              // ── Scrollable content ──────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.marginMobile,
                  ),
                  children: [
                    // ── Version cards ────────────────────────────
                    Text(
                      'Translations',
                      style: AppTypography.labelMedium.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    if (versions.isEmpty)
                      _buildNoVersions(colors)
                    else
                      ...versions.map((v) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildVersionCard(
                              version: v,
                              colors: colors,
                            ),
                          )),

                    const SizedBox(height: AppDimensions.lg),

                    // ── Color pickers ──────────────────────────────
                    Text(
                      'Text Colors',
                      style: AppTypography.labelMedium.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.sm),

                    // Pāli color
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.md),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.format_italic,
                                  size: 18, color: colors.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Text(
                                'Pāli Text Color',
                                style: AppTypography.labelMedium.copyWith(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.sm),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _paliColors.map((c) => swatch.ColorSwatch(
                              color: c,
                              isSelected: paliColor.value == c.value,
                              size: 36,
                              iconSize: 14,
                              onTap: () {
                                ref
                                    .read(settingsProvider.notifier)
                                    .setPaliColor(c);
                              },
                            )).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.sm),

                    // Translation color
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.md),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.translate,
                                  size: 18, color: colors.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Text(
                                'Translation Text Color',
                                style: AppTypography.labelMedium.copyWith(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.sm),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _transColors.map((c) => swatch.ColorSwatch(
                              color: c,
                              isSelected: transColor.value == c.value,
                              size: 36,
                              iconSize: 14,
                              onTap: () {
                                ref
                                    .read(settingsProvider.notifier)
                                    .setTranslationColor(c);
                              },
                            )).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppDimensions.xl),
                  ],
                ),
              ),

              // ── Continue button ────────────────────────────────
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.marginMobile,
                    AppDimensions.md,
                    AppDimensions.marginMobile,
                    AppDimensions.md,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: hasAnyDownloaded ? () => _startBuild() : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(hasAnyDownloaded
                          ? 'Build Search Index'
                          : 'Download a translation first'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusLg),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWizardLoading(ColorScheme colors) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              Text(
                'Loading available translations…',
                style: AppTypography.labelSmall
                    .copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoVersions(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off,
              size: 36,
              color: colors.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'No translations available.',
            textAlign: TextAlign.center,
            style:
                AppTypography.labelSmall.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionCard({
    required TranslationVersion version,
    required ColorScheme colors,
  }) {
    // Build version key for download state lookup
    final versionKey = version.suffix != null && version.suffix!.isNotEmpty
        ? '${version.languageCode}_${version.suffix}'
        : version.languageCode;

    final downloadStates = ref.watch(translationDownloadProvider);
    final downloadState = downloadStates[versionKey] ??
        const TranslationDownloadState();

    final isActive = downloadState.status == DownloadStatus.downloading ||
        downloadState.status == DownloadStatus.extracting;
    final isComplete = downloadState.status == DownloadStatus.completed || version.isAvailable;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: isComplete
              ? AppColors.successGreen.withValues(alpha: 0.3)
              : colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Language badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isComplete
                      ? AppColors.successGreen.withValues(alpha: 0.15)
                      : colors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Center(
                  child: isComplete
                      ? Icon(Icons.check_circle,
                          size: 22, color: AppColors.successGreen)
                      : Text(
                          version.languageCode.toUpperCase(),
                          style: AppTypography.labelMedium.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              // Name + status + version
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      version.englishName,
                      style: AppTypography.labelMedium.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        if (version.displayName.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: version.isNissaya
                                  ? Colors.indigo.withValues(alpha: 0.12)
                                  : colors.secondaryContainer,
                              borderRadius:
                                  BorderRadius.circular(AppDimensions.radiusSm),
                            ),
                            child: Text(
                              version.displayName,
                              style: AppTypography.labelSmall.copyWith(
                                fontSize: 10,
                                color: version.isNissaya
                                    ? Colors.indigo
                                    : colors.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Text(
                          isComplete
                              ? 'Ready'
                              : version.hasDownloadUrl
                                  ? 'Not installed'
                                  : 'Coming soon',
                          style: AppTypography.labelSmall.copyWith(
                            color: isComplete
                                ? AppColors.successGreen
                                : isActive
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action button / spinner
              if (isActive)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colors.primary,
                    value: downloadState.status == DownloadStatus.extracting
                        ? null
                        : downloadState.progress,
                  ),
                )
              else if (!isComplete && version.hasDownloadUrl)
                FilledButton.tonal(
                  onPressed: () {
                    ref
                        .read(translationDownloadProvider.notifier)
                        .downloadVersion(version, ref);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    textStyle: AppTypography.labelSmall
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Download'),
                ),
            ],
          ),
          // File size
          if (version.fileSize != null && !isComplete)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _formatSize(version.fileSize!),
                style: AppTypography.labelSmall
                    .copyWith(color: colors.onSurfaceVariant, fontSize: 11),
              ),
            ),
          // Progress bar for active downloads
          if (isActive && downloadState.progress > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                value: downloadState.progress,
                minHeight: 3,
                borderRadius: BorderRadius.circular(2),
                backgroundColor: colors.surfaceContainerHighest,
              ),
            ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // ── Step 2: Build Progress ──────────────────────────────────────────

  void _startBuild() {
    setState(() {
      _buildStarted = true;
    });
    _animCtrl.forward(from: 0);
    ref.read(indexControllerProvider.notifier).buildIndex();
  }

  Widget _buildBuildStep(IndexState state) {
    final colors = Theme.of(context).colorScheme;
    final progress = state.progressFraction;
    final phaseColor = state.buildPhase == IndexBuildPhase.indexingCombined
        ? colors.primary
        : state.buildPhase == IndexBuildPhase.loadingTranslations
            ? AppColors.successGreen
            : colors.secondary;

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.marginMobile),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Phase label chip ──────────────────────────────
                  if (state.phaseLabel != null && state.phaseLabel!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: phaseColor.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _phaseIcon(state.buildPhase),
                            size: 16,
                            color: phaseColor,
                          ),
                          const SizedBox(width: 6),
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

                  // ── Circular progress ────────────────────────────
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 88,
                          height: 88,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 7,
                            backgroundColor: colors.surfaceContainerHighest,
                            valueColor:
                                AlwaysStoppedAnimation(colors.primary),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Text(
                          '${(progress * 100).round()}%',
                          style: AppTypography.headlineSmall.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.md),

                  // ── Sentence count ───────────────────────────────
                  Text(
                    state.totalProgress > 0
                        ? '${_fmt(state.currentProgress)} / ${_fmt(state.totalProgress)} sentences'
                        : 'Preparing…',
                    style: AppTypography.labelMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),

                  // ── Batch + speed row ────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (state.batchTotal > 0) ...[
                        Icon(Icons.list_alt,
                            size: 12, color: colors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          'Batch ${state.batchCurrent} / ${state.batchTotal}',
                          style: AppTypography.labelSmall
                              .copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(width: AppDimensions.md),
                      ],
                      if (state.itemsPerSecond >= 1) ...[
                        Icon(Icons.speed,
                            size: 12, color: colors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '~${state.itemsPerSecond >= 1000 ? "${(state.itemsPerSecond / 1000).toStringAsFixed(1)}k" : state.itemsPerSecond.round().toString()}/s',
                          style: AppTypography.labelSmall
                              .copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppDimensions.sm),

                  // ── Linear progress bar ──────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: colors.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(colors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _phaseIcon(IndexBuildPhase? phase) {
    switch (phase) {
      case IndexBuildPhase.loadingTranslations:
        return Icons.language;
      case IndexBuildPhase.indexingCombined:
        return Icons.merge;
      default:
        return Icons.build;
    }
  }

  String _fmt(int n) {
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
}
