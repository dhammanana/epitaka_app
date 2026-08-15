// lib/features/translator/screens/translator_run_screen.dart
//
// Live run screen for the Translation Builder: shows per-book / section /
// chunk progress, a scrolling log, a cancel button while running, and after
// completion a "Share the database" action that exports the target
// epitaka_<lang>.db via the system share sheet.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../core/models/translation_version.dart'
    show TranslationFilenameParser;
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/database_initializer.dart';
import '../../settings/widgets/settings_app_bar.dart';
import '../providers/translator_provider.dart';
import '../translator_constants.dart';
import '../translator_settings.dart';

/// Run screen for the Translation Builder.
class TranslatorRunScreen extends ConsumerStatefulWidget {
  const TranslatorRunScreen({super.key});

  @override
  ConsumerState<TranslatorRunScreen> createState() =>
      _TranslatorRunScreenState();
}

class _TranslatorRunScreenState extends ConsumerState<TranslatorRunScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Kick off the run shortly after the first frame so the "running" UI
    // is visible before the (long) run begins.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(translatorRunnerProvider.notifier).run();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _shareDatabase() async {
    final settings = ref.read(translatorSettingsProvider);
    final dir = await getDatabaseDirectory();
    final path = p.join(
      dir.path,
      TranslationFilenameParser.build(settings.langCode),
    );
    final file = File(path);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No database file found yet.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'application/octet-stream')],
        subject: 'ePitaka ${translatorLangName(settings.langCode)} translation',
        text: 'ePitaka ${translatorLangName(settings.langCode)} translation '
            'database (epitaka_${settings.langCode}.db)',
      ),
    );
  }

  /// Share the last chunk's prompt + response files (kept on disk by the
  /// runner, overwritten each chunk — only the most recent exchange).
  Future<void> _shareLastExchange() async {
    final promptPath = ref.read(translatorRunnerProvider).lastPromptPath;
    final responsePath = ref.read(translatorRunnerProvider).lastResponsePath;
    final files = <XFile>[];
    if (promptPath != null && await File(promptPath).exists()) {
      files.add(XFile(promptPath, mimeType: 'text/plain'));
    }
    if (responsePath != null && await File(responsePath).exists()) {
      files.add(XFile(responsePath, mimeType: 'text/plain'));
    }
    if (!mounted) return;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No prompt/response files yet — run at least one chunk.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: files,
        subject: 'ePitaka translation — last prompt & response',
        text: 'Last chunk prompt and raw AI response for the '
            'Translation Builder.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = ref.watch(translatorRunnerProvider);
    final settings = ref.watch(translatorSettingsProvider);

    // Auto-scroll the log as new lines arrive.
    _scrollToBottom();

    final progress = _progressValue(state);

    return Scaffold(
      appBar: SettingsAppBar(colors: colors),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.marginMobile,
              AppDimensions.md,
              AppDimensions.marginMobile,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Translation Builder — Run',
                  style: AppTypography.headlineLarge.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${translatorLangName(settings.langCode)} '
                  '(${settings.langCode}) · ${settings.bookIds.length} '
                  'book(s) · ${settings.model}',
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                // ── Progress bar ─────────────────────────────────────
                if (state.isRunning) ...[
                  LinearProgressIndicator(
                    value: progress,
                    color: colors.primary,
                    backgroundColor: colors.outlineVariant,
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    _progressText(state, settings),
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  // ── Live run stats ──────────────────────────────────
                  _RunStatsGrid(state: state),
                ] else if (state.phase == TranslatorRunPhase.done) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, color: colors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Done — ${state.translationsSaved} translations, '
                              '${state.glossarySaved} glossary, '
                              '${state.remarksSaved} remarks saved.',
                              style: AppTypography.labelMedium.copyWith(
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'The ${translatorLangName(settings.langCode)} '
                              'translation is now enabled for reading — open '
                              'a book to check it. Manage it in Settings → '
                              'Translations & Downloads.',
                              style: AppTypography.labelSmall.copyWith(
                                color: colors.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  _RunStatsGrid(state: state),
                  const SizedBox(height: AppDimensions.sm),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/settings/translation'),
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: const Text('Manage translations'),
                  ),
                ] else if (state.phase == TranslatorRunPhase.error) ...[
                  Row(
                    children: [
                      Icon(Icons.error_outline, color: colors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Error: ${state.error}',
                          style: AppTypography.labelMedium.copyWith(
                            color: colors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (state.phase == TranslatorRunPhase.cancelled) ...[
                  Row(
                    children: [
                      Icon(Icons.stop_circle_outlined,
                          color: colors.onSurfaceVariant, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Cancelled — ${state.translationsSaved} translations '
                        'saved before stopping.',
                        style: AppTypography.labelMedium,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppDimensions.md),
                // ── Actions ──────────────────────────────────────────
                Wrap(
                  spacing: AppDimensions.sm,
                  runSpacing: AppDimensions.sm,
                  children: [
                    if (state.isRunning)
                      OutlinedButton.icon(
                        onPressed: () => ref
                            .read(translatorRunnerProvider.notifier)
                            .cancel(),
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                      )
                    else ...[
                      FilledButton.icon(
                        onPressed: state.phase == TranslatorRunPhase.idle
                            ? null
                            : () => ref
                                .read(translatorRunnerProvider.notifier)
                                .reset(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _shareDatabase,
                        icon: const Icon(Icons.share),
                        label: const Text('Share DB'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _shareLastExchange,
                        icon: const Icon(Icons.swap_vert),
                        label: const Text('Share prompt & response'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          const Divider(height: 1),
          // ── Log ────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.marginMobile,
                AppDimensions.sm,
                AppDimensions.marginMobile,
                AppDimensions.xl,
              ),
              itemCount: state.logs.length,
              itemBuilder: (ctx, i) {
                final entry = state.logs[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    entry.text,
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 12,
                      height: 1.5,
                      fontFamily: 'monospace',
                      color: entry.isError
                          ? colors.error
                          : colors.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  double? _progressValue(TranslatorRunState state) {
    if (state.totalBooks == 0) return null;
    // Overall progress = books completed + the current book's fraction.
    final completedBooks = state.currentBookIndex;
    final bookFraction = state.totalSections == 0
        ? 0.0
        : (state.currentSection - 1) / state.totalSections;
    final value = (completedBooks + bookFraction) / state.totalBooks;
    return value.clamp(0.0, 1.0);
  }

  String _progressText(TranslatorRunState state, TranslatorSettings settings) {
    if (state.totalBooks == 0) return 'Preparing…';
    final bookName = state.currentBookIndex < settings.bookIds.length
        ? settings.bookIds[state.currentBookIndex]
        : '';
    final sb = StringBuffer('Book ${state.currentBookIndex + 1}/'
        '${state.totalBooks}');
    if (bookName.isNotEmpty) sb.write(' ($bookName)');
    if (state.totalSections > 0) {
      sb.write(' · section ${state.currentSection}/${state.totalSections}');
    }
    if (state.totalChunks > 0) {
      sb.write(' · chunk ${state.currentChunk}/${state.totalChunks}');
    }
    sb.write(' · ${state.translationsSaved} translated');
    return sb.toString();
  }
}

/// Compact 2×2 grid of live run statistics shown above the log.
class _RunStatsGrid extends StatelessWidget {
  final TranslatorRunState state;

  const _RunStatsGrid({required this.state});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final promptKb = state.currentChunkPromptBytes > 0
        ? (state.currentChunkPromptBytes / 1024).toStringAsFixed(1)
        : '—';

    Widget cell({
      required IconData icon,
      required String label,
      required String value,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sm,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: colors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ),
            Text(
              value,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: cell(
                icon: Icons.format_list_numbered,
                label: 'Pending sentences',
                value: state.pendingSentences.toString(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: cell(
                icon: Icons.auto_awesome,
                label: 'AI calls',
                value: state.apiCalls.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: cell(
                icon: Icons.view_agenda_outlined,
                label: 'This chunk',
                value: '${state.currentChunkSentences} sent'
                    '${state.currentChunkTokens > 0 ? ' · ~${state.currentChunkTokens} tok' : ''}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: cell(
                icon: Icons.data_object,
                label: 'Prompt size',
                value: '$promptKb KB',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
