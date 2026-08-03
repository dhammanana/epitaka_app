import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../providers/gavesana_provider.dart';

/// Modal dialog that builds the chunk-level BM25 FTS index (`vec_chunks_fts`)
/// inside epitaka.db.
///
/// This is always triggered by an explicit user action (never lazily in the
/// background, which would jank the app). Shows live progress, a completion
/// state, and an error state with retry. When the user dismisses it, vector
/// search still works without BM25.
class GavesanaFtsBuildDialog extends ConsumerStatefulWidget {
  /// When true, the dialog drops and rebuilds an existing index (used when
  /// the user explicitly asks to rebuild, e.g. after a killed build).
  final bool rebuild;

  const GavesanaFtsBuildDialog({super.key, this.rebuild = false});

  /// Show the dialog as a modal bottom sheet.
  /// Set [rebuild] to true to drop and rebuild an existing index.
  static Future<void> show(BuildContext context, {bool rebuild = false}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GavesanaFtsBuildDialog(rebuild: rebuild),
    );
  }

  @override
  ConsumerState<GavesanaFtsBuildDialog> createState() =>
      _GavesanaFtsBuildDialogState();
}

class _GavesanaFtsBuildDialogState
    extends ConsumerState<GavesanaFtsBuildDialog> {
  double _progress = 0.0;
  String _status = 'Preparing…';
  bool _building = false;
  bool _done = false;
  String? _error;
  bool _triggered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_triggered) {
      _triggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startBuild());
    }
  }

  Future<void> _startBuild() async {
    if (_building || _done) return;
    setState(() {
      _building = true;
      _error = null;
      _progress = 0.0;
      _status = widget.rebuild
          ? AppLocalizations.of(context).rebuildingBm25Index
          : AppLocalizations.of(context).preparingBm25Index;
    });

    final ok = await (widget.rebuild
        ? ref
              .read(gavesanaProvider.notifier)
              .rebuildBm25Index(onProgress: _onProgress, onError: _onError)
        : ref
              .read(gavesanaProvider.notifier)
              .ensureBm25Index(onProgress: _onProgress, onError: _onError));

    if (!mounted) return;
    setState(() {
      _building = false;
      if (ok) {
        _done = true;
        _progress = 1.0;
        _status = AppLocalizations.of(context).bm25IndexReady;
      }
    });
  }

  void _onProgress(double p, String msg) {
    if (mounted)
      setState(() {
        _progress = p;
        _status = msg;
      });
  }

  void _onError(String msg) {
    if (mounted) setState(() => _error = msg);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final pct = (_progress * 100).round();

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Icon(Icons.text_fields, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  loc.buildBm25SearchIndex,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: colors.onSurface),
                ),
                const Spacer(),
                if (_done || _error != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    color: colors.onSurfaceVariant,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildContent(colors, pct)),
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme colors, int pct) {
    final loc = AppLocalizations.of(context);
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.error),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: AppTypography.bodyTranslation.copyWith(
                color: colors.error,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _startBuild,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(loc.retry),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(loc.continueWithoutBm25),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_done) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 48, color: colors.tertiary),
            const SizedBox(height: 12),
            Text(
              loc.bm25IndexReady,
              style: AppTypography.bodyTranslation.copyWith(
                color: colors.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              loc.hybridSearchEnabled,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(loc.done),
            ),
          ],
        ),
      );
    }

    // Building / preparing
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.marginMobile,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
                    value: _progress,
                    strokeWidth: 7,
                    backgroundColor: colors.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(colors.primary),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '$pct%',
                  style: AppTypography.headlineSmall.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          Text(
            _status,
            style: AppTypography.labelMedium.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 6,
              backgroundColor: colors.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colors.primary),
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          Text(
            loc.bm25IndexesOnce,
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
