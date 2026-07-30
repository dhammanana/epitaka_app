library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../shared/models/ai_provider.dart';
import '../../shared/services/ai_model_service.dart';
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
  ConsumerState<_AiQaSettingsSheet> createState() =>
      _AiQaSettingsSheetState();
}

class _AiQaSettingsSheetState extends ConsumerState<_AiQaSettingsSheet> {
  late TextEditingController _apiKeyController;
  late TextEditingController _toolModelController;
  late TextEditingController _answerModelController;
  late TextEditingController _baseUrlController;
  late TextEditingController _systemPromptController;
  late TextEditingController _maxResultCharsController;
  late TextEditingController _answerMaxTokensController;
  late TextEditingController _maxQueriesController;
  bool _obscureKey = true;
  bool _saving = false;

  // Model fetching
  bool _loadingModels = false;
  List<String> _availableModels = [];
  String? _modelsError;
  late AiProvider _selectedProvider;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(aiQaSettingsProvider);
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _toolModelController = TextEditingController(text: settings.toolModel);
    _answerModelController = TextEditingController(text: settings.answerModel);
    _baseUrlController = TextEditingController(text: settings.baseUrl);
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
    _selectedProvider = settings.provider;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _toolModelController.dispose();
    _answerModelController.dispose();
    _baseUrlController.dispose();
    _systemPromptController.dispose();
    _maxResultCharsController.dispose();
    _answerMaxTokensController.dispose();
    _maxQueriesController.dispose();
    super.dispose();
  }

  Future<void> _fetchModels() async {
    setState(() {
      _loadingModels = true;
      _modelsError = null;
    });

    final result = await AiModelService.fetchModels(
      provider: _selectedProvider,
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _loadingModels = false;
      if (result.isSuccess) {
        _availableModels = result.models;
      } else {
        _modelsError = result.error;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final notifier = ref.read(aiQaSettingsProvider.notifier);
      await notifier.setApiKey(_apiKeyController.text.trim());
      await notifier.setProvider(_selectedProvider);
      await notifier.setBaseUrl(_baseUrlController.text.trim());
      await notifier.setToolModel(_toolModelController.text.trim());
      await notifier.setAnswerModel(_answerModelController.text.trim());
      await notifier.setCustomSystemPrompt(_systemPromptController.text.trim());
      final maxCharsText = _maxResultCharsController.text.trim();
      final maxChars =
          maxCharsText.isEmpty ? 0 : int.tryParse(maxCharsText) ?? 0;
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
      initialChildSize: 0.85,
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
                            : 'API key required — enter your key below',
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

              // ── Provider ─────────────────────────────────────────
              _sectionLabel(colors, 'AI Provider'),
              const SizedBox(height: 6),
              DropdownButtonFormField<AiProvider>(
                initialValue: _selectedProvider,
                items: AiProvider.values
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedProvider = value;
                      _availableModels = [];
                      _modelsError = null;
                    });
                  }
                },
                decoration: _inputDecoration(colors),
                style: TextStyle(color: colors.onSurface, fontSize: 14),
                dropdownColor: colors.surface,
              ),
              const SizedBox(height: 20),

              // ── API Key ─────────────────────────────────────────
              _sectionLabel(colors, 'API Key'),
              const SizedBox(height: 6),
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureKey,
                maxLines: 1,
                style: TextStyle(color: colors.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: _selectedProvider == AiProvider.gemini
                      ? 'AIza...'
                      : 'sk-...',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor:
                      colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
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
              const SizedBox(height: 6),

              // ── Help links ───────────────────────────────────────
              _HelpLinks(provider: _selectedProvider),
              const SizedBox(height: 20),

              // ── Base URL (OpenAI only) ───────────────────────────
              if (_selectedProvider == AiProvider.openai) ...[
                _sectionLabel(colors, 'Base URL'),
                const SizedBox(height: 6),
                TextField(
                  controller: _baseUrlController,
                  maxLines: 1,
                  style: TextStyle(color: colors.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'https://api.openai.com/v1',
                    hintStyle: TextStyle(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor:
                        colors.surfaceContainerHighest.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      borderSide: BorderSide(color: colors.outlineVariant),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Examples: https://openrouter.ai/api/v1, https://api.deepseek.com/v1',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Fetch Models ─────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _apiKeyController.text.trim().isEmpty
                      ? null
                      : _fetchModels,
                  icon: _loadingModels
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_outlined, size: 18),
                  label: Text(
                    _loadingModels
                        ? 'Fetching models...'
                        : 'Fetch available models',
                  ),
                ),
              ),
              if (_modelsError != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 14, color: colors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _modelsError!,
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.error,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_availableModels.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '${_availableModels.length} models found',
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.green[600],
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // ── Tool Model ──────────────────────────────────────
              _sectionLabel(colors, 'Tool Model (for search & function calling)'),
              const SizedBox(height: 6),
              _buildModelField(
                controller: _toolModelController,
                colors: colors,
                hintText: 'gemini-2.0-flash-lite',
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
              _sectionLabel(colors, 'Answer Model (for final answer generation)'),
              const SizedBox(height: 6),
              _buildModelField(
                controller: _answerModelController,
                colors: colors,
                hintText: 'gemini-2.0-flash',
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
                  fillColor:
                      colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
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
                  fillColor:
                      colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Max output tokens for the answer model. '
                'Higher values allow longer answers. '
                '(Default: 64000)',
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
                  fillColor:
                      colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
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
                  fillColor:
                      colors.surfaceContainerHighest.withValues(alpha: 0.3),
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
                    side: BorderSide(
                        color: colors.primary.withValues(alpha: 0.3)),
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

  Widget _sectionLabel(ColorScheme colors, String label) {
    return Text(
      label,
      style: AppTypography.labelMedium.copyWith(
        color: colors.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }

  InputDecoration _inputDecoration(
    ColorScheme colors, {
    String hintText = '',
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: colors.onSurfaceVariant.withValues(alpha: 0.5),
        fontSize: 14,
      ),
      filled: true,
      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildModelField({
    required TextEditingController controller,
    required ColorScheme colors,
    String hintText = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          maxLines: 1,
          style: TextStyle(color: colors.onSurface, fontSize: 14),
          decoration: _inputDecoration(colors, hintText: hintText),
        ),
        if (_availableModels.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _availableModels.take(15).map((model) {
                final isSelected = controller.text == model;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(
                      model,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isSelected ? colors.onPrimary : colors.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () {
                      controller.text = model;
                      controller.selection = TextSelection.fromPosition(
                        TextPosition(
                            offset: controller.text.length),
                      );
                      setState(() {});
                    },
                    backgroundColor: isSelected
                        ? colors.primary
                        : colors.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
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
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
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

/// Widget that shows clickable help links for getting API keys.
class _HelpLinks extends StatelessWidget {
  final AiProvider provider;

  const _HelpLinks({required this.provider});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LinkTile(
          icon: Icons.info_outline,
          label: provider.helpLabel,
          url: provider.helpUrl,
          color: colors.primary,
          iconColor: colors.primary.withValues(alpha: 0.8),
        ),
        ...provider.additionalHelps.map(
          (help) => _LinkTile(
            icon: Icons.link,
            label: help.label,
            url: help.url,
            color: colors.onSurfaceVariant,
            iconColor: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;
  final Color color;
  final Color iconColor;

  const _LinkTile({
    required this.icon,
    required this.label,
    required this.url,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openUrl(context, url),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 14, child: Icon(icon, size: 14, color: iconColor)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: color,
                  decoration: TextDecoration.underline,
                  fontSize: 11,
                ),
              ),
            ),
            Icon(Icons.open_in_new,
                size: 12, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open: $urlString'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
