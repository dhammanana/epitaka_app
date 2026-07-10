import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../core/providers/translation_registry_provider.dart';
import 'index_controller.dart';
import 'index_state.dart';
import 'indexing_provider.dart';
import 'widgets/fts_build_complete.dart';
import 'widgets/fts_build_error.dart';
import 'widgets/fts_build_progress.dart';
import 'widgets/fts_translation_selector.dart';

/// Dialog that guides the user through building the FTS index.
///
/// Flow:
/// 1. Show available translations to choose from
/// 2. Show build progress (with detailed phase labels)
/// 3. Show completion / error
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
  String? _selectedLang;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(indexControllerProvider);
    final controller = ref.read(indexControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final availableTranslations = ref.watch(ftsAvailableTranslationsProvider);

    debugPrint('[INDEX_DIALOG] build: status=${state.status}, '
        'selectedLang=$_selectedLang, '
        'progress=${state.currentProgress}/${state.totalProgress}, '
        'phase=${state.phaseLabel}');

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
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
          const SizedBox(height: 8),
          if (!state.isBuilt && !state.isBuilding)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Choose a translation to include in the search index. '
                'Pāli text is always included.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ),
          const SizedBox(height: 16),
          // Content
          Expanded(
            child: _buildContent(
              context: context,
              state: state,
              controller: controller,
              availableTranslations: availableTranslations,
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
    required List<AvailableTranslation> availableTranslations,
    required ColorScheme colors,
  }) {
    switch (state.status) {
      case IndexStatus.needsTranslationChoice:
        return FtsTranslationSelector(
          translations: availableTranslations,
          selectedLang: _selectedLang,
          onSelected: (lang) {
            debugPrint('[INDEX_DIALOG] selected lang=$lang');
            setState(() => _selectedLang = lang);
          },
          onBuild: () {
            // Index building is now handled automatically by IndexController
            debugPrint('[INDEX_DIALOG] retry to build missing indexes');
            controller.retry();
          },
          colors: colors,
        );

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
          count: state.totalProgress,
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
        return const Center(child: CircularProgressIndicator());
    }
  }
}
