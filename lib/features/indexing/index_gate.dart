import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
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

  /// When set, the inline color picker is shown instead of the normal wizard.
  _ColorPickerConfig? _colorPickerConfig;

  /// Predefined color options for Pāli text.
  static const List<Color> _paliColors = [
    Color(0xFF7A2E1D), // Default warm brown
    Color(0xFF994532), // Rust red
    Color(0xFFB5651D), // Golden amber
    Color(0xFF8B1A1A), // Deep red
    Color(0xFF3D3D8F), // Indigo
    Color(0xFF2A6B6B), // Teal
    Color(0xFF5D4037), // Coffee brown
    Color(0xFF6A1B9A), // Purple
  ];

  /// Predefined color options for translation text.
  static const List<Color> _transColors = [
    Color(0xFF33312E), // Default dark gray
    Color(0xFF221A14), // Espresso
    Color(0xFF544338), // Warm taupe
    Color(0xFF3C6E47), // Forest green
    Color(0xFF4A6FA5), // Steel blue
    Color(0xFF6B635A), // Charcoal
    Color(0xFF2E7D32), // Green
    Color(0xFF5D4037), // Brown
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

    // Listen for download completions and invalidate FTS required-asset
    // providers so the "all ready" check re-evaluates.
    ref.listen(translationDownloadProvider, (prev, next) {
      final completedNow = next.entries.any((e) =>
          e.value.status == DownloadStatus.completed &&
          (prev?[e.key]?.status != DownloadStatus.completed));
      if (completedNow) {
        ref.invalidate(ftsRequiredCoreAssetsProvider);
        ref.invalidate(ftsRequiredTranslationsProvider);
        ref.invalidate(ftsAllRequiredReadyProvider);
      }
    });

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
    // Inline color picker takes over the full screen — no nested Scaffold.
    if (_colorPickerConfig != null) {
      return _buildInlineColorPicker();
    }

    final colors = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final settings = ref.watch(settingsProvider);
    final availableAsync = ref.watch(ftsAvailableVersionsProvider);
    final downloadableAsync = ref.watch(ftsDownloadableVersionsProvider);
    final downloadStates = ref.watch(translationDownloadProvider);
    final requiredCoreAsync = ref.watch(ftsRequiredCoreAssetsProvider);
    final requiredTransAsync = ref.watch(ftsRequiredTranslationsProvider);
    final allRequiredReady = ref.watch(ftsAllRequiredReadyProvider);

    // Show loading while manifest is being fetched
    final isLoading = availableAsync.isLoading || downloadableAsync.isLoading ||
        requiredCoreAsync.isLoading || requiredTransAsync.isLoading;
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

    // Gather required core assets that are not yet installed
    final requiredCoreAssets = <CoreAsset>[];
    requiredCoreAsync.whenData((v) => requiredCoreAssets.addAll(v));

    // Gather required translations that are not yet installed
    final requiredTranslations = <TranslationVersion>[];
    requiredTransAsync.whenData((v) => requiredTranslations.addAll(v));

    // Remove required (compulsory) translations from the optional list
    // so they don't appear twice (once in Required + once in Optional).
    final requiredCodes = requiredTranslations
        .map((v) => '${v.languageCode}_${v.suffix ?? ''}')
        .toSet();
    final optionalVersions = versions
        .where((v) => !requiredCodes
            .contains('${v.languageCode}_${v.suffix ?? ''}'))
        .toList();

    // Compute all-ready from download states as well — the FutureProvider
    // caches its result and won't re-run until invalidated, but download
    // state updates instantly via the StateNotifier.
    bool coreAllComplete(List<CoreAsset> assets) => assets.every((a) {
      final s = downloadStates[a.slug] ?? const TranslationDownloadState();
      return s.status == DownloadStatus.completed;
    });
    bool transAllComplete(List<TranslationVersion> versions) =>
        versions.every((v) {
      // Must match the key format used in TranslationDownloadNotifier.downloadVersion
      final key = v.suffix != null && v.suffix!.isNotEmpty
          ? '${v.languageCode}_${v.suffix}'
          : v.languageCode;
      final s = downloadStates[key] ?? const TranslationDownloadState();
      return s.status == DownloadStatus.completed;
    });
    final allReady = (allRequiredReady.valueOrNull ?? false) ||
        (coreAllComplete(requiredCoreAssets) &&
         transAllComplete(requiredTranslations));    // Determine current Pāli and translation colors
    // For selection highlighting, we compare against the LIGHT color from
    // the ColorPair (the user's chosen color), not the resolved
    // brightness-specific color, which in dark mode is a derived variant
    // that won't match any preset.
    final paliColor = settings.paliColorFor(brightness);
    final transColor = settings.translationColorFor(brightness);
    final paliLightColor = settings.paliColorPair.light;
    final transLightColor = settings.translationColorPair.light;

    return Scaffold(
      body: SafeArea(          child: FadeTransition(
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
                      'Download the required databases to get started.',
                      style: AppTypography.labelMedium
                          .copyWith(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You can add more translations later.',
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
                    // ── Required Core Assets ──────────────────────
                    if (requiredCoreAssets.isNotEmpty) ...[
                      _buildRequiredSectionLabel(
                        'Required Databases',
                        'These are needed for the app to function.',
                        colors,
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      ...requiredCoreAssets.map((asset) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildCoreAssetCard(
                              asset: asset,
                              colors: colors,
                            ),
                          )),
                      const SizedBox(height: AppDimensions.md),
                    ],

                    // ── Required Translations ─────────────────────
                    if (requiredTranslations.isNotEmpty) ...[
                      _buildRequiredSectionLabel(
                        'Required Translations',
                        'An English translation is needed for AI search features.',
                        colors,
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      ...requiredTranslations.map((v) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildVersionCard(
                              version: v,
                              colors: colors,
                              isRequired: true,
                            ),
                          )),
                      const SizedBox(height: AppDimensions.md),
                    ],

                    // ── Optional translations ─────────────────────
                    Text(
                      'Optional Translations',
                      style: AppTypography.labelMedium.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    if (optionalVersions.isEmpty)
                      _buildNoVersions(colors)
                    else
                      ...optionalVersions.map((v) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildVersionCard(
                              version: v,
                              colors: colors,
                              isRequired: false,
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
                    _ColorPickerSection(
                      title: 'Pāli Text Color',
                      icon: Icons.format_italic,
                      currentColor: paliColor,
                      selectedColor: paliLightColor,
                      presetColors: _paliColors,
                      colors: colors,
                      onColorSelected: (c) {
                        ref.read(settingsProvider.notifier).setPaliColor(c);
                      },
                      onCustomColor: () {
                        setState(() {
                          _colorPickerConfig = _ColorPickerConfig(
                            currentColor: paliLightColor,
                            label: 'Pick Pāli Text Color',
                            onColorPicked: (c) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .setPaliColor(c);
                            },
                          );
                        });
                      },
                    ),
                    const SizedBox(height: AppDimensions.sm),

                    // Translation color
                    _ColorPickerSection(
                      title: 'Translation Text Color',
                      icon: Icons.translate,
                      currentColor: transColor,
                      selectedColor: transLightColor,
                      presetColors: _transColors,
                      colors: colors,
                      onColorSelected: (c) {
                        ref
                            .read(settingsProvider.notifier)
                            .setTranslationColor(c);
                      },
                      onCustomColor: () {
                        setState(() {
                          _colorPickerConfig = _ColorPickerConfig(
                            currentColor: transLightColor,
                            label: 'Pick Translation Text Color',
                            onColorPicked: (c) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .setTranslationColor(c);
                            },
                          );
                        });
                      },
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
                      onPressed: allReady ? () => _startBuild() : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        allReady
                            ? 'Build Search Index'
                            : 'Download required items first'),
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

  Widget _buildRequiredSectionLabel(String title, String subtitle, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.labelMedium.copyWith(
            color: colors.error,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          subtitle,
          style: AppTypography.labelSmall.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
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

  /// Build a card for a core asset that needs to be downloaded.
  Widget _buildCoreAssetCard({
    required CoreAsset asset,
    required ColorScheme colors,
  }) {
    final downloadStates = ref.watch(translationDownloadProvider);
    final assetKey = asset.slug;
    final downloadState = downloadStates[assetKey] ??
        const TranslationDownloadState();

    final isActive = downloadState.status == DownloadStatus.downloading ||
        downloadState.status == DownloadStatus.extracting;
    final isComplete = downloadState.status == DownloadStatus.completed;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: isComplete
              ? AppColors.successGreen.withValues(alpha: 0.3)
              : colors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Asset icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isComplete
                      ? AppColors.successGreen.withValues(alpha: 0.15)
                      : colors.errorContainer,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Center(
                  child: isComplete
                      ? Icon(Icons.check_circle,
                          size: 22, color: AppColors.successGreen)
                      : Icon(Icons.storage,
                          size: 22, color: colors.error),
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              // Name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          asset.displayName,
                          style: AppTypography.labelMedium.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: colors.error.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusSm),
                          ),
                          child: Text(
                            'Required',
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 10,
                              color: colors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isComplete
                          ? 'Installed'
                          : 'Not installed',
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
              else if (!isComplete)
                FilledButton.tonal(
                  onPressed: () {
                    final filename = asset.filename ??
                        '${asset.slug.replaceAll('_', '-')}.db';
                    ref
                        .read(translationDownloadProvider.notifier)
                        .downloadCoreAsset(
                          url: asset.url,
                          filename: filename,
                          displayName: asset.displayName,
                          ref: ref,
                          versionKey: assetKey,
                        );
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
          if (asset.size != null && !isComplete)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _formatSize(asset.size!),
                style: AppTypography.labelSmall
                    .copyWith(color: colors.onSurfaceVariant, fontSize: 11),
              ),
            ),
          // Progress bar
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

  Widget _buildVersionCard({
    required TranslationVersion version,
    required ColorScheme colors,
    bool isRequired = false,
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
                    Row(
                      children: [
                        Text(
                          version.englishName,
                          style: AppTypography.labelMedium.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isRequired && !isComplete) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: colors.error.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppDimensions.radiusSm),
                            ),
                            child: Text(
                              'Required',
                              style: AppTypography.labelSmall.copyWith(
                                fontSize: 10,
                                color: colors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
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

  // ── Inline Color Picker ──────────────────────────────────────────────

  /// Replaces the wizard content with a full-screen color picker using the
  /// [flutter_colorpicker](https://pub.dev/packages/flutter_colorpicker) package.
  /// Rendered directly in the widget tree — no Navigator dependency needed.
  Widget _buildInlineColorPicker() {
    final config = _colorPickerConfig!;
    Color pickedColor = config.currentColor;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _colorPickerConfig = null),
        ),
        title: Text(config.label),
        actions: [
          TextButton(
            onPressed: () {
              config.onColorPicked(pickedColor);
              setState(() => _colorPickerConfig = null);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
      body: StatefulBuilder(
        builder: (context, setLocalState) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Color picker from flutter_colorpicker package
                ColorPicker(
                  pickerColor: pickedColor,
                  onColorChanged: (color) {
                    setLocalState(() => pickedColor = color);
                  },
                  enableAlpha: false,
                  displayThumbColor: true,
                  labelTypes: const [],
                  pickerAreaHeightPercent: 0.7,
                ),
                const SizedBox(height: 16),
                // Preview
                Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: pickedColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                ),
                const SizedBox(height: 16),
                // Hex display
                Center(
                  child: Text(
                    '#${pickedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Configuration for the inline color picker.
class _ColorPickerConfig {
  final Color currentColor;
  final String label;
  final ValueChanged<Color> onColorPicked;

  const _ColorPickerConfig({
    required this.currentColor,
    required this.label,
    required this.onColorPicked,
  });
}

// ── Color Picker Section Widget ───────────────────────────────────────────

/// A reusable color picker section with preset swatches + a custom picker button.
///
/// [currentColor] is the resolved color (shown in the circle indicator),
/// while [selectedColor] is used for comparing against presets to determine
/// which swatch is selected. Usually [selectedColor] should be the light
/// color from the ColorPair (the user's chosen color).
class _ColorPickerSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color currentColor;
  final Color selectedColor;
  final List<Color> presetColors;
  final ColorScheme colors;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback onCustomColor;

  const _ColorPickerSection({
    required this.title,
    required this.icon,
    required this.currentColor,
    required this.selectedColor,
    required this.presetColors,
    required this.colors,
    required this.onColorSelected,
    required this.onCustomColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Current color indicator (shows the resolved brightness color)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: currentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.outlineVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // Preset swatches — compare against selectedColor (light color)
              ...presetColors.map((c) => swatch.ColorSwatch(
                color: c,
                isSelected: selectedColor.toARGB32() == c.toARGB32(),
                size: 36,
                iconSize: 14,
                onTap: () => onColorSelected(c),
              )),
              // Custom color button
              GestureDetector(
                onTap: onCustomColor,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: presetColors.any((c) => c.toARGB32() == selectedColor.toARGB32())
                          ? colors.outlineVariant
                          : colors.primary,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.colorize,
                    size: 16,
                    color: presetColors.any((c) => c.toARGB32() == selectedColor.toARGB32())
                        ? colors.onSurfaceVariant
                        : colors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
