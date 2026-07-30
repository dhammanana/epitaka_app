/// A dialog showing a progress bar while the @ mention index is being rebuilt.
///
/// The rebuild runs on the main thread but yields to the Flutter event loop
/// at regular intervals so the progress bar updates smoothly and the app
/// stays responsive.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../services/mention_service.dart';

/// Shows a modal dialog with a progress bar during mention index rebuild.
///
/// The dialog cannot be dismissed while building; it closes automatically
/// on completion or error.
Future<int> showMentionIndexBuildDialog(BuildContext context) {
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _MentionIndexBuildDialog(),
  ).then((result) => result ?? 0);
}

class _MentionIndexBuildDialog extends ConsumerStatefulWidget {
  const _MentionIndexBuildDialog();

  @override
  ConsumerState<_MentionIndexBuildDialog> createState() =>
      _MentionIndexBuildDialogState();
}

class _MentionIndexBuildDialogState
    extends ConsumerState<_MentionIndexBuildDialog> {
  double _progress = 0.0;
  String _label = 'Preparing…';
  bool _isComplete = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startBuild();
  }

  Future<void> _startBuild() async {
    try {
      final service = ref.read(mentionServiceProvider);
      final count = await service.buildIndex(
        onProgress: (progress, label) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _label = label;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _isComplete = true;
          _progress = 1.0;
          _label = '$_label — $count entries';
        });
        // Auto-dismiss after a brief pause so the user sees "Complete"
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.of(context).pop(count);
      }
    } catch (e) {
      debugPrint('[MENTION_BUILD] Build error: $e');
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      backgroundColor: colors.surface,
      surfaceTintColor: colors.surfaceTint,
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _error != null
                    ? colors.error.withValues(alpha: 0.1)
                    : _isComplete
                        ? Colors.green.withValues(alpha: 0.1)
                        : colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                _error != null
                    ? Icons.error_outline
                    : _isComplete
                        ? Icons.check_circle_outline
                        : Icons.bookmark_add_outlined,
                size: 24,
                color: _error != null
                    ? colors.error
                    : _isComplete
                        ? Colors.green
                        : colors.primary,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              _error != null
                  ? 'Build Failed'
                  : _isComplete
                      ? 'Index Built'
                      : 'Building Heading Index…',
              style: AppTypography.headlineSmall.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),

            // Error message
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _error!,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onErrorContainer,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(0),
                child: const Text('Close'),
              ),
            ] else ...[
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 8,
                  backgroundColor: colors.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(
                    _isComplete ? Colors.green : colors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Percentage + label
              Text(
                '${(_progress * 100).round()}%',
                style: AppTypography.headlineSmall.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _label,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
