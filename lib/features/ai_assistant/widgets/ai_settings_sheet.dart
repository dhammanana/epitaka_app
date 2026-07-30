library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../shared/models/ai_provider.dart';
import '../../shared/services/ai_model_service.dart';
import '../providers/ai_settings_provider.dart';

/// Shows the AI Assistant settings bottom sheet.
void showAiSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _AiSettingsSheet(),
  );
}

class _AiSettingsSheet extends ConsumerStatefulWidget {
  const _AiSettingsSheet();

  @override
  ConsumerState<_AiSettingsSheet> createState() => _AiSettingsSheetState();
}

class _AiSettingsSheetState extends ConsumerState<_AiSettingsSheet> {
  late TextEditingController _apiKeyController;
  late TextEditingController _renderModelController;
  late TextEditingController _liteModelController;
  late TextEditingController _baseUrlController;
  bool _obscureKey = true;
  bool _saving = false;

  // Model fetching state
  bool _loadingModels = false;
  List<String> _availableModels = [];
  String? _modelsError;

  // Selected provider (local to sheet until saved)
  late AiProvider _selectedProvider;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(aiSettingsProvider);
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _renderModelController = TextEditingController(text: settings.renderModel);
    _liteModelController = TextEditingController(text: settings.liteModel);
    _baseUrlController = TextEditingController(text: settings.baseUrl);
    _selectedProvider = settings.provider;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _renderModelController.dispose();
    _liteModelController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  /// Fetch models from the selected provider and update the dropdown.
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
      final notifier = ref.read(aiSettingsProvider.notifier);
      await notifier.setApiKey(_apiKeyController.text.trim());
      await notifier.setProvider(_selectedProvider);
      await notifier.setBaseUrl(_baseUrlController.text.trim());
      await notifier.setRenderModel(_renderModelController.text.trim());
      await notifier.setLiteModel(_liteModelController.text.trim());
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI settings saved'),
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
    final settings = ref.watch(aiSettingsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
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
                  Icon(Icons.smart_toy, size: 22, color: colors.primary),
                  const SizedBox(width: 10),
                  Text(
                    'AI Assistant Settings',
                    style: AppTypography.headlineSmall.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Status indicator ─────────────────────────────────
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
                          : Icons.warning_amber_rounded,
                      size: 18,
                      color: settings.isValid ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        settings.isValid
                            ? 'API key is configured'
                            : 'API key required — enter your key below',
                        style: AppTypography.labelMedium.copyWith(
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

              // ── Provider selection ───────────────────────────────
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
                decoration: _inputDecoration(colors, hintText: 'Select provider...'),
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
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor:
                      colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
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
                          color: colors.outline,
                        ),
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                      if (_apiKeyController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.clear, size: 18, color: colors.outline),
                          onPressed: () {
                            _apiKeyController.clear();
                            ref
                                .read(aiSettingsProvider.notifier)
                                .clearApiKey();
                          },
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // ── Help links ───────────────────────────────────────
              _HelpLinks(provider: _selectedProvider),
              const SizedBox(height: 20),

              // ── Base URL (OpenAI-compatible only) ────────────────
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
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor:
                        colors.surfaceContainerHighest.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      borderSide: BorderSide(color: colors.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
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

              // ── Fetch Models button ──────────────────────────────
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

              // ── Render Model ─────────────────────────────────────
              _sectionLabel(colors, 'Render Model (for generating answers)'),
              const SizedBox(height: 6),
              _buildModelField(
                controller: _renderModelController,
                colors: colors,
              ),
              const SizedBox(height: 4),
              Text(
                'Used for the main answer generation. Needs strong reasoning.',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 16),

              // ── Lite Model ───────────────────────────────────────
              _sectionLabel(colors, 'Lite Model (for filtering & search)'),
              const SizedBox(height: 6),
              _buildModelField(
                controller: _liteModelController,
                colors: colors,
              ),
              const SizedBox(height: 4),
              Text(
                'Fast model for re-ranking results and query expansion.',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 20),

              // ── Strict Mode toggle ───────────────────────────────
              Row(
                children: [
                  Icon(Icons.psychology, size: 20, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Strict Source Mode',
                          style: AppTypography.labelMedium.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'When ON, AI answers only from provided sources. '
                          'When OFF, AI can answer freely using its own knowledge.',
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: settings.strictMode,
                    activeTrackColor: colors.primary,
                    onChanged: (val) =>
                        ref.read(aiSettingsProvider.notifier).setStrictMode(val),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Save Button ──────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Settings'),
                ),
              ),
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
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  /// Model text field with autocomplete-like suggestion chips from fetched models.
  Widget _buildModelField({
    required TextEditingController controller,
    required ColorScheme colors,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          maxLines: 1,
          style: TextStyle(color: colors.onSurface, fontSize: 14),
          decoration: _inputDecoration(
            colors,
            hintText: _selectedProvider == AiProvider.gemini
                ? 'gemini-2.0-flash'
                : 'gpt-4o',
          ),
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
        // Main help link for this provider
        _LinkTile(
          icon: Icons.info_outline,
          label: provider.helpLabel,
          url: provider.helpUrl,
          color: colors.primary,
          iconColor: colors.primary.withValues(alpha: 0.8),
        ),
        // Additional provider links
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

/// A single tappable help link row.
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
            Icon(Icons.open_in_new, size: 12, color: color.withValues(alpha: 0.5)),
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
