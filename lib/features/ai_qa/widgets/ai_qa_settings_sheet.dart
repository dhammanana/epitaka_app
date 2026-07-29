library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/ai_qa_settings_provider.dart';
import '../services/mention_service.dart';

/// Show the AI Q&A settings bottom sheet.
void showAiQaSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _AiQaSettingsSheet(),
  );
}

class _AiQaSettingsSheet extends ConsumerStatefulWidget {
  const _AiQaSettingsSheet();

  @override
  ConsumerState<_AiQaSettingsSheet> createState() => _AiQaSettingsSheetState();
}

class _AiQaSettingsSheetState extends ConsumerState<_AiQaSettingsSheet> {
  late TextEditingController _apiKeyController;
  late TextEditingController _toolModelController;
  late TextEditingController _answerModelController;
  late TextEditingController _systemPromptController;
  late TextEditingController _maxResultCharsController;
  late TextEditingController _answerMaxTokensController;
  late TextEditingController _maxQueriesController;
  bool _obscureKey = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(aiQaSettingsProvider);
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _toolModelController = TextEditingController(text: settings.toolModel);
    _answerModelController = TextEditingController(text: settings.answerModel);
    _systemPromptController =
        TextEditingController(text: settings.customSystemPrompt);
    _maxResultCharsController = TextEditingController(
      text: settings.maxToolResultChars > 0
          ? settings.maxToolResultChars.toString()
          : '',
    );
    _answerMaxTokensController = TextEditingController(
      text: settings.answerMaxTokens.toString(),
    );
    _maxQueriesController = TextEditingController(
      text: settings.maxQueriesPerChat.toString(),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _toolModelController.dispose();
    _answerModelController.dispose();
    _systemPromptController.dispose();
    _maxResultCharsController.dispose();
    _answerMaxTokensController.dispose();
    _maxQueriesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final notifier = ref.read(aiQaSettingsProvider.notifier);
      await notifier.setApiKey(_apiKeyController.text.trim());
      await notifier.setToolModel(_toolModelController.text.trim());
      await notifier.setAnswerModel(_answerModelController.text.trim());
      await notifier.setCustomSystemPrompt(_systemPromptController.text.trim());
      final maxCharsText = _maxResultCharsController.text.trim();
      final maxChars = maxCharsText.isEmpty
          ? 0
          : int.tryParse(maxCharsText) ?? 0;
      await notifier.setMaxToolResultChars(maxChars);
      final answerTokensText = _answerMaxTokensController.text.trim();
      final answerTokens = int.tryParse(answerTokensText) ?? 64000;
      await notifier.setAnswerMaxTokens(answerTokens);
      final maxQueriesText = _maxQueriesController.text.trim();
      final maxQueries = int.tryParse(maxQueriesText) ?? 8;
      await notifier.setMaxQueriesPerChat(maxQueries);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI Q&A settings saved'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final settings = ref.watch(aiQaSettingsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusSheet),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppDimensions.md),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primary,
                          colors.primary.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.question_answer,
                        size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'AI Q&A Settings',
                    style: AppTypography.headlineSmall.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Status indicator
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: settings.isValid
                      ? Colors.green.withValues(alpha: 0.08)
                      : Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Row(
                  children: [
                    Icon(
                      settings.isValid
                          ? Icons.check_circle
                          : Icons.warning_amber,
                      size: 18,
                      color: settings.isValid ? Colors.green : Colors.orange[700],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        settings.isValid
                            ? 'API key configured'
                            : 'API key required — enter your Gemini API key below',
                        style: AppTypography.labelSmall.copyWith(
                          color: settings.isValid
                              ? Colors.green[700]
                              : Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── API Key ─────────────────────────────────────────
              Text(
                'API Key',
                style: AppTypography.labelMedium.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureKey,
                maxLines: 1,
                style: TextStyle(color: colors.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'AIza...',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _obscureKey
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 18,
                        ),
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                      ),
                      if (_apiKeyController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _apiKeyController.clear();
                            ref
                                .read(aiQaSettingsProvider.notifier)
                                .clearApiKey();
                          },
                        ),
                    ],
                  ),
                ),
              ),
              if (!settings.isValid) ...[
                const SizedBox(height: 4),
                Text(
                  'Get a free API key at ai.google.dev',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // ── Tool Model ──────────────────────────────────────
              Text(
                'Tool Model (for search & function calling)',
                style: AppTypography.labelMedium.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _toolModelController,
                maxLines: 1,
                style: TextStyle(color: colors.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'gemini-2.0-flash-lite',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fast/cheap model for tool orchestration (e.g. gemini-2.0-flash-lite)',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 20),

              // ── Answer Model ────────────────────────────────────
              Text(
                'Answer Model (for final answer generation)',
                style: AppTypography.labelMedium.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _answerModelController,
                maxLines: 1,
                style: TextStyle(color: colors.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'gemini-2.0-flash',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Capable model for final answers (e.g. gemini-2.0-flash, gemini-2.5-flash)',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 20),

              // ── Max Tool Result Chars ──────────────────────────
              Row(
                children: [
                  Icon(Icons.text_snippet, size: 16, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Max chars per tool result',
                    style: AppTypography.labelMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _maxResultCharsController,
                maxLines: 1,
                keyboardType: TextInputType.number,
                style: TextStyle(color: colors.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '0 = no truncation',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Max characters per tool result sent to the model. '
                'Set to 0 for no truncation (full content). '
                'Large values may increase API usage.',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 20),

              // ── Answer Max Tokens ────────────────────────────────
              Row(
                children: [
                  Icon(Icons.token, size: 16, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Answer max output tokens',
                    style: AppTypography.labelMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _answerMaxTokensController,
                maxLines: 1,
                keyboardType: TextInputType.number,
                style: TextStyle(color: colors.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '64000',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Max output tokens for the answer model. '
                'Higher values allow longer answers. '
                '(Default: 64000, max: 65536 for Gemini 2.0 Pro)',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 20),

              // ── Max Queries Per Chat ─────────────────────────────
              Row(
                children: [
                  Icon(Icons.forum, size: 16, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Max queries per chat',
                    style: AppTypography.labelMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _maxQueriesController,
                maxLines: 1,
                keyboardType: TextInputType.number,
                style: TextStyle(color: colors.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '8',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Max user queries (messages) allowed per chat thread before starting a new one. '
                '(Default: 8, min: 1)',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 20),

              // ── Custom System Prompt ────────────────────────────
              Row(
                children: [
                  Icon(Icons.psychology, size: 16, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Custom System Prompt (optional)',
                    style: AppTypography.labelMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _systemPromptController,
                maxLines: 8,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText:
                      'Leave empty to use the default system prompt.\n\n'
                      'Customize how the AI behaves, what tools to use,\n'
                      'and how to format answers.',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 20),

              // ── Save Button ─────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check, size: 20),
                  label: Text(_saving ? 'Saving...' : 'Save Settings'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Rebuild Suggestion Index ────────────────────────
              const Divider(height: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.refresh, size: 16, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Suggestion Index',
                    style: AppTypography.labelMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Reset the @ mention suggestion index to pick up any '
                'new or updated books/headings.',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _rebuildIndex(context),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Rebuild Suggestion Index'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: colors.primary.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _rebuildIndex(BuildContext context) async {
    final colors = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);

    try {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Rebuilding suggestion index…'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 30),
        ),
      );

      final service = ref.read(mentionServiceProvider);
      final count = await service.buildIndex();

      if (context.mounted) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Index rebuilt: $count entries'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Rebuild failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: colors.error,
          ),
        );
      }
    }
  }
}
