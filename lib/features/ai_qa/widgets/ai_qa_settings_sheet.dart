library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../shared/models/ai_provider.dart';
import '../../shared/services/ai_model_service.dart';
import '../providers/ai_qa_settings_provider.dart';
import 'mention_index_build_dialog.dart';

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

  /// Last API key that was successfully validated against the provider.
  String _lastValidatedKey = '';

  /// Whether the currently-typed key passed validation (models loaded).
  bool _keyIsValid = false;

  /// Whether the currently-typed key failed validation.
  bool _keyCheckFailed = false;

  late final FocusNode _apiKeyFocusNode;
  late AiProvider _selectedProvider;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(aiQaSettingsProvider);
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _toolModelController = TextEditingController(text: settings.toolModel);
    _answerModelController = TextEditingController(text: settings.answerModel);
    _baseUrlController = TextEditingController(text: settings.baseUrl);
    _systemPromptController = TextEditingController(
      text: settings.customSystemPrompt,
    );
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
    _apiKeyFocusNode = FocusNode()..addListener(_onApiKeyFocusChanged);
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
    _apiKeyFocusNode.dispose();
    super.dispose();
  }

  /// Validates the current API key by fetching the model list from the
  /// provider. Persists the key first so a valid key survives even if the
  /// user closes the sheet without tapping Save.
  Future<void> _fetchModels() async {
    if (_loadingModels || !mounted) return;
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) return;

    setState(() {
      _loadingModels = true;
      _modelsError = null;
      _keyIsValid = false;
      _keyCheckFailed = false;
    });

    await ref.read(aiQaSettingsProvider.notifier).setApiKey(key);

    final result = await AiModelService.fetchModels(
      provider: _selectedProvider,
      apiKey: key,
      baseUrl: _baseUrlController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _loadingModels = false;
      _lastValidatedKey = key;
      if (result.isSuccess) {
        _availableModels = result.models;
        _keyIsValid = true;
        _keyCheckFailed = false;
        _autoFillModelFieldsIfEmpty();
      } else {
        _modelsError = result.error;
        _keyIsValid = false;
        _keyCheckFailed = true;
      }
    });
  }

  /// Called when the API key field loses focus: validate the key (and load
  /// models) automatically if it changed and is non-empty.
  void _onApiKeyFocusChanged() {
    if (!mounted) return;
    if (!_apiKeyFocusNode.hasFocus) {
      _validateApiKey();
    }
  }

  /// Validate the key on submit or focus-loss — skip if unchanged/empty.
  Future<void> _validateApiKey() async {
    if (!mounted) return;
    final key = _apiKeyController.text.trim();
    if (key.isEmpty || key == _lastValidatedKey) return;
    await _fetchModels();
  }

  /// If the tool/answer model fields are empty or no longer in the fetched
  /// list, pick sensible defaults from the models we just loaded.
  void _autoFillModelFieldsIfEmpty() {
    if (_availableModels.isEmpty) return;

    // The fetched list is sorted descending, so `.first` is the newest
    // (preferred) model, e.g. gemini-flash-lite-latest / gemini-flash-latest.
    final tool = _toolModelController.text.trim();
    if (tool.isEmpty || !_availableModels.contains(tool)) {
      final flashLite = _availableModels
          .where((m) => m.toLowerCase().contains('flash-lite'))
          .toList();
      final fallback = flashLite.isNotEmpty
          ? flashLite.first
          : _availableModels.first;
      _toolModelController.text = fallback;
    }

    final answer = _answerModelController.text.trim();
    if (answer.isEmpty || !_availableModels.contains(answer)) {
      final flash = _availableModels
          .where(
            (m) =>
                m.toLowerCase().contains('flash') &&
                !m.toLowerCase().contains('lite'),
          )
          .toList();
      final fallback = flash.isNotEmpty ? flash.first : _availableModels.first;
      _answerModelController.text = fallback;
    }
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
                    child: const Icon(
                      Icons.question_answer,
                      size: 18,
                      color: Colors.white,
                    ),
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

              // Status indicator (reflects live validation state)
              _buildStatusCard(colors),
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
                focusNode: _apiKeyFocusNode,
                obscureText: _obscureKey,
                maxLines: 1,
                style: TextStyle(color: colors.onSurface, fontSize: 14),
                onChanged: (_) {
                  setState(() {
                    _keyIsValid = false;
                    _keyCheckFailed = false;
                    _modelsError = null;
                    _availableModels = [];
                  });
                },
                onSubmitted: (_) => _validateApiKey(),
                decoration: InputDecoration(
                  hintText: _selectedProvider == AiProvider.gemini
                      ? 'AIza...'
                      : 'sk-...',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
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
                          _obscureKey ? Icons.visibility_off : Icons.visibility,
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
                            _lastValidatedKey = '';
                            _keyIsValid = false;
                            _keyCheckFailed = false;
                            _modelsError = null;
                            _availableModels = [];
                            ref
                                .read(aiQaSettingsProvider.notifier)
                                .clearApiKey();
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // ── Beginner guide: get a free Gemini key ───────────
              if (_selectedProvider == AiProvider.gemini)
                _buildGeminiGuide(colors),
              const SizedBox(height: 20),

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
                    fillColor: colors.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSm,
                      ),
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

              // ── Fetch Models (also validates the key) ───────────
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
                        ? 'Checking key & loading models...'
                        : 'Check key & load models',
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
              _sectionLabel(
                colors,
                'Tool Model (for search & function calling)',
              ),
              const SizedBox(height: 6),
              _buildModelField(
                controller: _toolModelController,
                colors: colors,
                hintText: 'gemini-flash-latest-latest',
              ),
              const SizedBox(height: 4),
              Text(
                'Fast/cheap model for tool orchestration (e.g. gemini-flash-lite-latest)',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 20),

              // ── Answer Model ────────────────────────────────────
              _sectionLabel(
                colors,
                'Answer Model (for final answer generation)',
              ),
              const SizedBox(height: 6),
              _buildModelField(
                controller: _answerModelController,
                colors: colors,
                hintText: 'gemini-flash-latest',
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
                  fillColor: colors.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
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
                  fillColor: colors.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
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
                  fillColor: colors.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
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
                  fillColor: colors.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
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
                      color: colors.primary.withValues(alpha: 0.3),
                    ),
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

  /// Status banner that reflects the live validation state of the API key
  /// field (empty / typed / checking / valid / failed).
  Widget _buildStatusCard(ColorScheme colors) {
    final hasKey = _apiKeyController.text.trim().isNotEmpty;

    final IconData icon;
    final Color color;
    final String text;

    if (!hasKey) {
      icon = Icons.warning_amber;
      color = Colors.orange[700]!;
      text = _selectedProvider == AiProvider.gemini
          ? 'API key required — get your free Gemini key below'
          : 'API key required — enter your key below';
    } else if (_loadingModels) {
      icon = Icons.sync;
      color = Colors.blue[700]!;
      text = 'Checking API key...';
    } else if (_keyCheckFailed) {
      icon = Icons.error_outline;
      color = Colors.red[700]!;
      text = 'API key rejected — see the error below';
    } else if (_keyIsValid) {
      icon = Icons.check_circle;
      color = Colors.green[700]!;
      text = _availableModels.isNotEmpty
          ? 'API key valid — ${_availableModels.length} models available'
          : 'API key valid';
    } else {
      icon = Icons.info_outline;
      color = Colors.blue[700]!;
      text = 'Key entered — press Enter or "Check key" to verify';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTypography.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Step-by-step card that walks a non-technical user through getting a
  /// free Gemini API key and pasting it back here.
  Widget _buildGeminiGuide(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
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
                child: const Icon(Icons.key, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Get a free Gemini API key',
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Gemini is free for everyone — just 4 easy steps:',
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _guideStep(colors, '1', 'Tap "Get free Gemini API key" below.'),
          _guideStep(
            colors,
            '2',
            'Sign in with your Google account (free, no credit card).',
          ),
          _guideStep(
            colors,
            '3',
            'Tap "Create API key" and copy it (it starts with AIza).',
          ),
          _guideStep(
            colors,
            '4',
            'Paste it in the API Key field above — it is checked automatically.',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () =>
                  _openUrl(context, _selectedProvider.apiKeyCreationUrl),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Get free Gemini API key'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No credit card needed. The free tier includes generous daily '
            'limits for Gemini Flash models.',
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _guideStep(ColorScheme colors, String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurface,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the link'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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

  InputDecoration _inputDecoration(ColorScheme colors, {String hintText = ''}) {
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        color: isSelected ? colors.onPrimary : colors.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () {
                      controller.text = model;
                      controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: controller.text.length),
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
    final count = await showMentionIndexBuildDialog(context);
    debugPrint('[SETTINGS] Mention index rebuild: $count entries');
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
            Icon(
              Icons.open_in_new,
              size: 12,
              color: color.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
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
