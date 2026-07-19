import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'index_controller.dart';
import 'index_state.dart';
import 'widgets/fts_build_complete.dart';
import 'widgets/fts_build_error.dart';
import 'widgets/fts_build_progress.dart';

/// Dialog that guides the user through building the FTS index.
///
/// Flow:
/// 1. If the index is already built, shows completion state.
/// 2. If building is in progress, shows build progress.
/// 3. Shows error states if things go wrong.
/// 4. If not yet built, triggers building automatically.
class IndexBuildDialog extends ConsumerStatefulWidget {
  const IndexBuildDialog({super.key});

  /// Show the dialog as a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const IndexBuildDialog(),
    );
  }

  @override
  ConsumerState<IndexBuildDialog> createState() => _IndexBuildDialogState();
}

class _IndexBuildDialogState extends ConsumerState<IndexBuildDialog> {
  bool _hasTriggeredBuild = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasTriggeredBuild) {
      final state = ref.read(indexControllerProvider);
      if (!state.isBuilt && !state.isBuilding) {
        _hasTriggeredBuild = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(indexControllerProvider.notifier).buildIndex();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(indexControllerProvider);
    final colors = Theme.of(context).colorScheme;

    debugPrint('[INDEX_DIALOG] build: status=${state.status}, '
        'progress=${state.currentProgress}/${state.totalProgress}, '
        'phase=${state.phaseLabel}');

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
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
                Icon(Icons.storage, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  'Build Search Index',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.onSurface,
                      ),
                ),
                const Spacer(),
                if (state.isBuilt)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    color: colors.onSurfaceVariant,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Content
          Expanded(
            child: _buildContent(
              context: context,
              state: state,
              controller: ref.read(indexControllerProvider.notifier),
              colors: colors,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required IndexState state,
    required IndexController controller,
    required ColorScheme colors,
  }) {
    switch (state.status) {
      case IndexStatus.building:
        return FtsBuildProgress(
          current: state.currentProgress,
          total: state.totalProgress,
          phaseLabel: state.phaseLabel,
          buildPhase: state.buildPhase,
          batchCurrent: state.batchCurrent,
          batchTotal: state.batchTotal,
          itemsPerSecond: state.itemsPerSecond,
          colors: colors,
        );

      case IndexStatus.ready:
        return FtsBuildComplete(
          lang: state.indexedTranslationLang ?? 'en',
          count: state.totalProgress > 0 ? state.totalProgress : state.currentProgress,
          colors: colors,
        );

      case IndexStatus.error:
        return FtsBuildError(
          message: state.errorMessage ?? 'Unknown error',
          onRetry: () {
            controller.retry();
          },
          onCancel: () => Navigator.of(context).pop(),
          colors: colors,
        );

      case IndexStatus.unknown:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Preparing…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        );
    }
  }
}
