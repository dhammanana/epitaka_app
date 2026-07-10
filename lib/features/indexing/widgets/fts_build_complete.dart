import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// Displays the successful completion state of the FTS index build.
class FtsBuildComplete extends StatelessWidget {
  final String lang;
  final int count;
  final ColorScheme colors;

  const FtsBuildComplete({
    super.key,
    required this.lang,
    required this.count,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.marginMobile,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Icon(
            Icons.check_circle,
            size: 72,
            color: AppColors.successGreen,
          ),
          const SizedBox(height: AppDimensions.md),
          Text(
            'Index Built!',
            style: AppTypography.headlineSmall.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'Pāli + ${lang.toUpperCase()} translation indexed\n'
            '$count sentences',
            textAlign: TextAlign.center,
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              ),
            ),
            child: const Text('Done'),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
