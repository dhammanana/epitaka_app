import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';
import '../../../core/providers/translation_registry_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../settings/providers/translation_download_provider.dart';
import '../index_controller.dart';

/// A tile showing a downloadable translation with download, progress, and
/// build-index buttons for use in the startup gate screen.
class DownloadOptionTile extends ConsumerWidget {
  final AvailableTranslation translation;
  final TranslationDownloadState downloadState;
  final ColorScheme colors;

  const DownloadOptionTile({
    super.key,
    required this.translation,
    required this.downloadState,
    required this.colors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = downloadState.status == DownloadStatus.downloading ||
        downloadState.status == DownloadStatus.extracting;
    final isComplete = downloadState.status == DownloadStatus.completed;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: colors.outlineVariant),
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
                      ? Icon(Icons.check_circle, size: 22, color: AppColors.successGreen)
                      : Text(
                          translation.languageCode.toUpperCase(),
                          style: AppTypography.labelMedium.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              // Name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translation.englishName,
                      style: AppTypography.labelMedium.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _statusText,
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
              if (!isActive && !isComplete)
                FilledButton.tonal(
                  onPressed: () {
                    final lang = TranslationLanguage.fromCode(
                      translation.languageCode,
                    );
                    ref
                        .read(translationDownloadProvider.notifier)
                        .downloadTranslation(lang, ref);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    textStyle: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Download'),
                ),
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
                ),
              if (isComplete)
                FilledButton(
                  onPressed: () {
                    // Trigger index build via the controller
                    ref.read(indexControllerProvider.notifier).retry();
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    textStyle: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Build Index'),
                ),
            ],
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

  String get _statusText {
    switch (downloadState.status) {
      case DownloadStatus.downloading:
        return 'Downloading… ${(downloadState.progress * 100).round()}%';
      case DownloadStatus.extracting:
        return 'Installing…';
      case DownloadStatus.completed:
        return 'Ready to index';
      case DownloadStatus.cancelled:
        return 'Download cancelled';
      case DownloadStatus.error:
        return downloadState.errorMessage ?? 'Download failed';
      case DownloadStatus.idle:
        return translation.nativeName;
    }
  }
}
