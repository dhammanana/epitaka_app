import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../index_state.dart';

/// Displays FTS index build progress with rich status information.
///
/// Shows:
/// - Phase icon + step label (e.g. "Step 2/4" + "Indexing Pāli sentences…")
/// - Circular percentage indicator
/// - Formatted sentence count ("3,420 / 15,000 sentences")
/// - Batch progress ("Batch 14 / 30")
/// - Processing speed ("~340/s")
/// - Linear progress bar
class FtsBuildProgress extends StatelessWidget {
  final int current;
  final int total;
  final String? phaseLabel;
  final IndexBuildPhase? buildPhase;
  final int batchCurrent;
  final int batchTotal;
  final double itemsPerSecond;
  final ColorScheme colors;

  const FtsBuildProgress({
    super.key,
    required this.current,
    required this.total,
    this.phaseLabel,
    this.buildPhase,
    this.batchCurrent = 0,
    this.batchTotal = 0,
    this.itemsPerSecond = 0,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? current / total : 0.0;
    final phaseIcon = _phaseIcon();
    final phaseColor = buildPhase == IndexBuildPhase.indexingCombined
        ? colors.primary
        : buildPhase == IndexBuildPhase.loadingTranslations
            ? AppColors.successGreen
            : colors.secondary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.marginMobile,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),

          // ── Phase label row with icon ───────────────────────────────
          if (phaseLabel != null && phaseLabel!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: phaseColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(phaseIcon, size: 16, color: phaseColor),
                  const SizedBox(width: 6),
                  Text(
                    phaseLabel!,
                    style: AppTypography.labelSmall.copyWith(
                      color: phaseColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppDimensions.lg),

          // ── Circular progress ───────────────────────────────────────
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
                    valueColor: AlwaysStoppedAnimation(colors.primary),
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

          // ── Sentence count (formatted) ──────────────────────────────
          Text(
            total > 0
                ? '${_fmt(current)} / ${_fmt(total)} sentences'
                : 'Preparing…',
            style: AppTypography.labelMedium.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: AppDimensions.sm),

          // ── Batch progress + speed row ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (batchTotal > 0) ...[
                Icon(Icons.list_alt, size: 12, color: colors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  'Batch $batchCurrent / $batchTotal',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppDimensions.md),
              ],
              if (itemsPerSecond >= 1) ...[
                Icon(Icons.speed, size: 12, color: colors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '~${(itemsPerSecond >= 1000 ? "${(itemsPerSecond / 1000).toStringAsFixed(1)}k" : itemsPerSecond.round().toString())}/s',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: AppDimensions.sm),

          // ── Linear progress bar ─────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colors.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colors.primary),
            ),
          ),

          const SizedBox(height: AppDimensions.sm),
        ],
      ),
    );
  }

  /// Pick an icon that matches the current build phase.
  IconData _phaseIcon() {
    switch (buildPhase) {
      case IndexBuildPhase.loadingTranslations:
        return Icons.language;
      case IndexBuildPhase.indexingCombined:
        return Icons.merge;
      default:
        return Icons.build;
    }
  }
}

/// Format a large number with comma separators (e.g. 15000 → "15,000").
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
