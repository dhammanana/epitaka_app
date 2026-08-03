import 'package:flutter/material.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';

/// Displays an error state during FTS index building with retry/cancel.
class FtsBuildError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final ColorScheme colors;

  const FtsBuildError({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onCancel,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.marginMobile,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Icon(
            Icons.error_outline,
            size: 64,
            color: colors.error,
          ),
          const SizedBox(height: AppDimensions.md),
          Text(
            loc.buildFailed,
            style: AppTypography.headlineSmall.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: onCancel,
                child: Text(loc.cancel),
              ),
              const SizedBox(width: AppDimensions.md),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(loc.retry),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
