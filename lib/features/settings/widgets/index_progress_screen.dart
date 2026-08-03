import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/app_db_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/translation_registry_provider.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';

/// Shows a full-screen progress overlay for index building (and optionally
/// resetting app data first). The dialog manages its own lifecycle and
/// closes automatically on success or when the user taps close on error.
///
/// Usage:
/// ```dart
/// final success = await IndexProgressScreen.show(context, resetFirst: true);
/// ```
class IndexProgressScreen extends ConsumerStatefulWidget {
  final bool resetFirst;

  const IndexProgressScreen({super.key, this.resetFirst = false});

  /// Show as a full-screen dialog. Returns `true` if the operation
  /// completed successfully, `false` on error or cancel.
  static Future<bool> show(BuildContext context, {bool resetFirst = false}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => IndexProgressScreen(resetFirst: resetFirst),
    ).then((result) => result ?? false);
  }

  @override
  ConsumerState<IndexProgressScreen> createState() =>
      _IndexProgressScreenState();
}

class _IndexProgressScreenState extends ConsumerState<IndexProgressScreen> {
  // ── Operation phases ─────────────────────────────────────────────────
  String _phaseLabel = 'Preparing…';
  double _progress = 0.0;
  String _detailText = '';
  bool _isComplete = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startOperation());
  }

  Future<void> _startOperation() async {
    if (_started) return;
    _started = true;

    try {
      // ── Phase 1: Export & reset (if requested) ────────────────────
      if (widget.resetFirst) {
        setState(() {
          _phaseLabel = 'Resetting app data…';
          _detailText = '';
          _progress = 0.0;
        });

        await AppDatabase.deleteDatabaseFile();
        ref.invalidate(appDbProvider);

        // Wait for the new app_db to be created
        await ref.read(appDbProvider.future);
      }

      // ── Phase 2: Build Pali index ─────────────────────────────────
      setState(() {
        _phaseLabel = 'Building Pāli search index…';
        _detailText = '';
        _progress = 0.0;
      });

      final appDb = await ref.read(appDbProvider.future);
      final epitakaDb = await ref.read(epitakaDbProvider.future);

      await appDb.buildSearchIndex(
        epitakaDb,
        onProgress: (p, msg) {
          if (mounted) {
            setState(() {
              _progress = p;
              _detailText = msg;
            });
          }
        },
      );

      // ── Phase 3: Build translation indexes ────────────────────────
      int translationErrors = 0;
      try {
        final available = await ref.read(translationRegistryProvider.future);
        for (final trans in available) {
          if (!trans.isAvailable) continue;

          setState(() {
            _phaseLabel = 'Building ${trans.englishName} translation index…';
            _detailText = '';
          });

          final translationDb =
              await ref.read(translationDbProvider(trans.languageCode).future);
          if (translationDb != null) {
            try {
              await appDb.buildTranslationSearchIndex(
                trans.languageCode,
                translationDb,
                onProgress: (p, msg) {
                  if (mounted) {
                    setState(() {
                      _progress = p;
                      _detailText = msg;
                    });
                  }
                },
              );
            } catch (e) {
              translationErrors++;
            }
          }
        }
      } catch (_) {
        translationErrors++;
      }

      // ── Done ──────────────────────────────────────────────────────
      if (mounted) {
        setState(() {
          _isComplete = true;
          _phaseLabel = 'Complete';
          _progress = 1.0;
          _detailText = widget.resetFirst
              ? 'App data reset and index rebuilt successfully.'
              : 'Search index rebuilt successfully.';
          if (translationErrors > 0) {
            _detailText += '\nNote: $translationErrors translation index(es) failed to build.';
          }
        });

        // Auto-close after a short delay
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: colors.surface,
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: _hasError || _isComplete
              ? IconButton(
                  icon: Icon(Icons.close, color: colors.onSurfaceVariant),
                  onPressed: () => Navigator.of(context).pop(_isComplete),
                )
              : null,
          title: Text(
            widget.resetFirst ? loc.resettingAndRebuilding : loc.rebuildingIndex,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Phase icon ──────────────────────────────────────
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _hasError
                        ? colors.errorContainer
                        : _isComplete
                            ? Colors.green.withValues(alpha: 0.15)
                            : colors.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    _hasError
                        ? Icons.error_outline
                        : _isComplete
                            ? Icons.check_circle
                            : Icons.storage,
                    size: 36,
                    color: _hasError
                        ? colors.error
                        : _isComplete
                            ? Colors.green
                            : colors.primary,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Phase label ─────────────────────────────────────
                Text(
                  _phaseLabel,
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineSmall.copyWith(
                    color: colors.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Detail / error message ──────────────────────────
                if (_hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.error,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _detailText,
                      textAlign: TextAlign.center,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),

                // ── Progress bar ────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _hasError ? null : _progress,
                    minHeight: 8,
                    backgroundColor: colors.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      _hasError ? colors.error : colors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Percentage text ─────────────────────────────────
                if (!_hasError && !_isComplete)
                  Text(
                    _progress > 0
                        ? '${(_progress * 100).toStringAsFixed(0)}%'
                        : '',
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),

                // ── Error action buttons ────────────────────────────
                if (_hasError) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () =>
                            Navigator.of(context).pop(false),
                        child: Text(loc.close),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _hasError = false;
                            _errorMessage = '';
                            _progress = 0.0;
                            _started = false;
                          });
                          _startOperation();
                        },
                        child: Text(loc.retry),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
