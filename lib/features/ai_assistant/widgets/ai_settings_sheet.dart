library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/ai_settings_provider.dart';

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
  bool _obscureKey = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(aiSettingsProvider);
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _renderModelController = TextEditingController(text: settings.renderModel);
    _liteModelController = TextEditingController(text: settings.liteModel);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _renderModelController.dispose();
    _liteModelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final notifier = ref.read(aiSettingsProvider.notifier);
      await notifier.setApiKey(_apiKeyController.text.trim());
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
          SnackBar(content: Text('Failed to save: $e'), behavior: SnackBarBehavior.floating),
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
      initialChildSize: 0.65,
      minChildSize: 0.5,
      maxChildSize: 0.9,
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
                  Text('AI Assistant Settings', style: AppTypography.headlineSmall.copyWith(
                    color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 20,
                  )),
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
                      settings.isValid ? Icons.check_circle : Icons.warning_amber_rounded,
                      size: 18,
                      color: settings.isValid ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        settings.isValid
                            ? 'API key is configured'
                            : 'API key required \u2014 enter your Gemini key below',
                        style: AppTypography.labelMedium.copyWith(
                          color: settings.isValid ? Colors.green[700] : Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _sectionLabel(colors, 'Gemini API Key'),
              const SizedBox(height: 6),
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureKey,
                maxLines: 1,
                style: TextStyle(color: colors.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'AIza...',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 14,
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
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _obscureKey ? Icons.visibility_off : Icons.visibility,
                          size: 18, color: colors.outline,
                        ),
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                      if (_apiKeyController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.clear, size: 18, color: colors.outline),
                          onPressed: () {
                            _apiKeyController.clear();
                            ref.read(aiSettingsProvider.notifier).clearApiKey();
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Get your free Gemini API key at makersuite.google.com',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 10,
                ),
              ),
              const SizedBox(height: 20),
              _sectionLabel(colors, 'Render Model (for generating answers)'),
              const SizedBox(height: 6),
              _modelDropdown(context, controller: _renderModelController, colors: colors),
              const SizedBox(height: 4),
              Text(
                'Used for the main answer generation. Needs strong reasoning.',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 10,
                ),
              ),
              const SizedBox(height: 16),
              _sectionLabel(colors, 'Lite Model (for filtering & search)'),
              const SizedBox(height: 6),
              _modelDropdown(context, controller: _liteModelController, colors: colors),
              const SizedBox(height: 4),
              Text(
                'Fast model for re-ranking results and query expansion.',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 10,
                ),
              ),
              const SizedBox(height: 20),
              // ── Strict Mode toggle ───────────────────────────────────
              Row(
                children: [
                  Icon(Icons.psychology, size: 20, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Strict Source Mode', style: AppTypography.labelMedium.copyWith(
                          color: colors.onSurface, fontWeight: FontWeight.w600, fontSize: 13,
                        )),
                        const SizedBox(height: 2),
                        Text(
                          'When ON, AI answers only from provided sources. '
                          'When OFF, AI can answer freely using its own knowledge.',
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: settings.strictMode,
                    activeTrackColor: colors.primary,
                    onChanged: (val) => ref.read(aiSettingsProvider.notifier).setStrictMode(val),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
    return Text(label, style: AppTypography.labelMedium.copyWith(
      color: colors.onSurface, fontWeight: FontWeight.w600, fontSize: 13,
    ));
  }

  Widget _modelDropdown(BuildContext context, {
    required TextEditingController controller,
    required ColorScheme colors,
  }) {
    final models = [
      'gemini-2.0-flash',
      'gemini-2.0-flash-lite',
      'gemini-1.5-pro',
      'gemini-1.5-flash',
      'gemini-2.5-flash-preview-04-17',
      'gemini-2.5-pro-preview-03-25',
    ];

    return DropdownButtonFormField<String>(
      initialValue: models.contains(controller.text) ? controller.text : null,
      items: models.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: (value) {
        if (value != null) controller.text = value;
      },
      decoration: InputDecoration(
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
        hintText: 'Select a model...',
        hintStyle: TextStyle(
          color: colors.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 14,
        ),
      ),
      style: TextStyle(color: colors.onSurface, fontSize: 14),
      dropdownColor: colors.surface,
    );
  }
}
