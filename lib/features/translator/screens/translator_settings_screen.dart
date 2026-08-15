// lib/features/translator/screens/translator_settings_screen.dart
//
// Settings for the on-device Translation Builder:
//   * AI configuration reusing the AI Q&A settings UX — provider guide +
//     help links, "check key & load models" validation, and a chip list to
//     pick the model — plus a sheet to manage MULTIPLE API keys (the runner
//     round-robins across them to spread rate limits),
//   * target language (searchable list of the 40+ supported languages),
//   * books to translate (searchable, diacritic-insensitive tick-list
//     grouped by category/nikāya),
//   * editable system prompt with reset-to-default,
//   * overwrite toggle,
//   * a Start button that opens the run screen. While a run is in progress
//     the button becomes a "View running translation" shortcut back to the
//     live run screen.
//
// When [TranslatorSettingsScreen.embedded] is true the Scaffold/app bar are
// skipped so the same body can live inside the desktop sidebar panel.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/pali_search_utils.dart';
import '../../ai_qa/providers/ai_qa_settings_provider.dart';
import '../../settings/widgets/settings_app_bar.dart';
import '../../shared/models/ai_provider.dart';
import '../../shared/services/ai_model_service.dart';
import '../providers/translator_provider.dart';
import '../translator_constants.dart';
import '../translator_settings.dart';

/// Book entry for the tick-list picker.
class TranslatorBookEntry {
  final String bookId;
  final String bookName;
  final String category;
  final String? nikaya;
  final String? subNikaya;

  const TranslatorBookEntry({
    required this.bookId,
    required this.bookName,
    this.category = '',
    this.nikaya,
    this.subNikaya,
  });
}

/// Settings screen for the Translation Builder.
class TranslatorSettingsScreen extends ConsumerStatefulWidget {
  /// When true the Scaffold/app bar are skipped so the body can be embedded
  /// in the desktop sidebar panel (which provides its own chrome).
  final bool embedded;

  const TranslatorSettingsScreen({super.key, this.embedded = false});

  @override
  ConsumerState<TranslatorSettingsScreen> createState() =>
      _TranslatorSettingsScreenState();
}

class _TranslatorSettingsScreenState
    extends ConsumerState<TranslatorSettingsScreen> {
  late final TextEditingController _modelController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _promptController;

  bool _modelInitialized = false;

  // Model fetching (mirrors the AI Q&A settings sheet UX).
  bool _loadingModels = false;
  List<String> _availableModels = [];
  String? _modelsError;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(translatorSettingsProvider);
    _modelController = TextEditingController(text: settings.model);
    _baseUrlController = TextEditingController(text: settings.baseUrl);
    _promptController = TextEditingController(text: settings.customPrompt);
  }

  @override
  void dispose() {
    _modelController.dispose();
    _baseUrlController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _saveFields() {
    final notifier = ref.read(translatorSettingsProvider.notifier);
    notifier.setModel(_modelController.text.trim().isEmpty
        ? kTranslatorDefaultModel
        : _modelController.text.trim());
    notifier.setBaseUrl(_baseUrlController.text);
    notifier.setCustomPrompt(_promptController.text);
  }

  /// The key used for validation/model listing: the first translator key,
  /// falling back to the AI Q&A key (which the runner also honours).
  String _primaryKey() {
    final settings = ref.read(translatorSettingsProvider);
    final key = settings.primaryApiKey.trim();
    if (key.length >= 5) return key;
    return ref.read(aiQaSettingsProvider).apiKey.trim();
  }

  Future<void> _checkKeyAndLoadModels() async {
    if (_loadingModels || !mounted) return;
    final key = _primaryKey();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an API key first, then check again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final provider = ref.read(translatorSettingsProvider).provider;

    setState(() {
      _loadingModels = true;
      _modelsError = null;
      _availableModels = [];
    });

    final result = await AiModelService.fetchModels(
      provider: provider,
      apiKey: key,
      baseUrl: _baseUrlController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _loadingModels = false;
      if (result.isSuccess) {
        _availableModels = result.models;
        final current = _modelController.text.trim();
        if (current.isEmpty || !result.models.contains(current)) {
          _modelController.text = _sensibleDefaultModel(result.models);
        }
      } else {
        _modelsError = result.error;
      }
    });
  }

  String _sensibleDefaultModel(List<String> models) {
    if (models.isEmpty) return kTranslatorDefaultModel;
    final flash = models
        .where((m) => m.toLowerCase().contains('flash'))
        .toList();
    return flash.isNotEmpty ? flash.first : models.first;
  }

  void _start() {
    _saveFields();
    if (_primaryKey().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an API key to start.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (ref.read(translatorSettingsProvider).bookIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tick at least one book to translate.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    context.push('/translator/run');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final settings = ref.watch(translatorSettingsProvider);

    // Seed the model from the AI Q&A answer model once (before the
    // persisted translator settings load), so a fresh install shows a
    // working model instead of only the placeholder default.
    if (!_modelInitialized &&
        (settings.model.isEmpty || settings.model == kTranslatorDefaultModel)) {
      final ai = ref.read(aiQaSettingsProvider);
      if (ai.answerModel.isNotEmpty) {
        _modelController.text = ai.answerModel;
        _modelInitialized = true;
      }
    }

    final body = ListView(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        widget.embedded ? 0 : AppDimensions.md,
        AppDimensions.marginMobile,
        120,
      ),
      children: [
        if (!widget.embedded) ...[
          Text(
            loc.t('Translation Builder'),
            style: AppTypography.headlineLarge.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            loc.t('Translate the Tipiṭaka on-device with AI. '
                'Pick a language, tick the books, then run.'),
            style: AppTypography.labelMedium.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
        ],

        // ── AI configuration ────────────────────────────────────────
        _Section(
          title: loc.t('AI Configuration'),
          colors: colors,
          children: [
            _DropdownTile<AiProvider>(
              colors: colors,
              icon: Icons.cloud_outlined,
              label: loc.t('AI Provider'),
              value: settings.provider,
              options: AiProvider.values,
              optionLabel: (p) => p.displayName,
              onChanged: (p) {
                if (p != null) {
                  ref
                      .read(translatorSettingsProvider.notifier)
                      .setProvider(p);
                  setState(() {
                    _availableModels = [];
                    _modelsError = null;
                    // Prefill the provider's default base URL for
                    // OpenAI-compatible providers (Gemini's is hardcoded).
                    if (p != AiProvider.gemini &&
                        _baseUrlController.text.trim().isEmpty) {
                      _baseUrlController.text = p.defaultBaseUrl;
                    }
                  });
                }
              },
            ),
            // Beginner guide: get a free key (Gemini / OpenRouter only).
            if (settings.provider == AiProvider.gemini ||
                settings.provider == AiProvider.openrouter)
              _ProviderGuideCard(provider: settings.provider, colors: colors),
            _ApiKeysTile(
              colors: colors,
              keys: settings.apiKeys,
              onChanged: (keys) => ref
                  .read(translatorSettingsProvider.notifier)
                  .setApiKeys(keys),
            ),
            _ModelConfigTile(
              colors: colors,
              controller: _modelController,
              loading: _loadingModels,
              models: _availableModels,
              error: _modelsError,
              onCheckKey: _checkKeyAndLoadModels,
              onChanged: (_) => _saveFields(),
            ),
            if (settings.provider != AiProvider.gemini)
              _TextFieldTile(
                colors: colors,
                icon: Icons.link,
                label: loc.t('Base URL'),
                hint: settings.provider.defaultBaseUrl,
                controller: _baseUrlController,
                onChanged: (_) => _saveFields(),
              ),
          ],
        ),

        const SizedBox(height: AppDimensions.md),

        // ── Target language ─────────────────────────────────────────
        _Section(
          title: loc.t('Target Language'),
          colors: colors,
          children: [
            _LanguagePickerTile(
              colors: colors,
              selected: settings.langCode,
              onSelected: (code) => ref
                  .read(translatorSettingsProvider.notifier)
                  .setLangCode(code),
            ),
            _SwitchTile(
              colors: colors,
              icon: Icons.sync,
              label: loc.t('Re-translate existing lines'),
              subtitle: loc.t('Off: only translate lines without a '
                  'translation yet.'),
              value: settings.overwrite,
              onChanged: (v) => ref
                  .read(translatorSettingsProvider.notifier)
                  .setOverwrite(v),
            ),
            _ChunkSizeTile(
              colors: colors,
              lines: settings.chunkMaxLines,
              tokens: settings.chunkMaxTokens,
              onLinesChanged: (v) => ref
                  .read(translatorSettingsProvider.notifier)
                  .setChunkMaxLines(v),
              onTokensChanged: (v) => ref
                  .read(translatorSettingsProvider.notifier)
                  .setChunkMaxTokens(v),
            ),
          ],
        ),

        const SizedBox(height: AppDimensions.md),

        // ── Books to translate ──────────────────────────────────────
        _Section(
          title: loc.t('Books to Translate'),
          colors: colors,
          children: [
            _BookPickerTile(
              colors: colors,
              selectedIds: settings.bookIds,
              onChanged: (ids) => ref
                  .read(translatorSettingsProvider.notifier)
                  .setBookIds(ids),
            ),
          ],
        ),

        const SizedBox(height: AppDimensions.md),

        // ── System prompt ───────────────────────────────────────────
        _Section(
          title: loc.t('System Prompt'),
          colors: colors,
          children: [
            _PromptTile(
              colors: colors,
              controller: _promptController,
              onChanged: (_) => _saveFields(),
              onReset: () {
                _promptController.text = '';
                ref
                    .read(translatorSettingsProvider.notifier)
                    .resetCustomPrompt();
              },
              onLoadDefault: () {
                // Fill the editor with the default template so the user
                // can tweak it from there ({lang_name} is substituted at
                // run time either way).
                final template = kTranslatorSystemPromptTemplate;
                _promptController.text = template;
                _promptController.selection = TextSelection.fromPosition(
                  TextPosition(offset: template.length),
                );
                _saveFields();
              },
            ),
          ],
        ),

        const SizedBox(height: AppDimensions.xl),

        // ── Start / View running ────────────────────────────────────
        if (ref.watch(translatorRunnerProvider).isRunning) ...[
          FilledButton.icon(
            onPressed: () => context.push('/translator/run'),
            icon: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colors.onPrimary,
              ),
            ),
            label: Text(loc.t('View Running Translation')),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              textStyle: AppTypography.labelMedium,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            loc.t('A translation is running in the background — tap above '
                'to see its live progress.'),
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ] else ...[
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow),
            label: Text(loc.t('Start Translation')),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              textStyle: AppTypography.labelMedium,
            ),
          ),
        ],
      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: SettingsAppBar(colors: colors),
      body: body,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Small building blocks
// ═══════════════════════════════════════════════════════════════════

/// A titled card matching the app's SettingsSection look.
class _Section extends StatelessWidget {
  final String title;
  final ColorScheme colors;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.colors,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppDimensions.md, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 56),
                    child: Divider(height: 1, color: colors.outlineVariant),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RowContainer extends StatelessWidget {
  final Widget child;
  final ColorScheme colors;
  final Widget? trailing;

  const _RowContainer({
    required this.child,
    required this.colors,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          Expanded(child: child),
          if (trailing != null) ...[
            const SizedBox(width: AppDimensions.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  final ColorScheme colors;
  final IconData icon;
  final String label;
  final T value;
  final List<T> options;
  final String Function(T) optionLabel;
  final ValueChanged<T?> onChanged;

  const _DropdownTile({
    required this.colors,
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _RowContainer(
      colors: colors,
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: AppTypography.labelMedium),
          ),
          DropdownButton<T>(
            value: value,
            underline: const SizedBox.shrink(),
            isDense: true,
            items: [
              for (final o in options)
                DropdownMenuItem(value: o, child: Text(optionLabel(o))),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TextFieldTile extends StatelessWidget {
  final ColorScheme colors;
  final IconData icon;
  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _TextFieldTile({
    required this.colors,
    required this.icon,
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _RowContainer(
      colors: colors,
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final ColorScheme colors;
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.colors,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _RowContainer(
      colors: colors,
      trailing: Switch(value: value, onChanged: onChanged),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.labelMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chunk batching tile: lines per call (primary knob) + token budget
/// (secondary safety cap, wide range so users can go very large).
class _ChunkSizeTile extends StatelessWidget {
  final ColorScheme colors;
  final int lines;
  final int tokens;
  final ValueChanged<int> onLinesChanged;
  final ValueChanged<int> onTokensChanged;

  const _ChunkSizeTile({
    required this.colors,
    required this.lines,
    required this.tokens,
    required this.onLinesChanged,
    required this.onTokensChanged,
  });

  static const _linesMin = 25;
  static const _linesMax = 500;
  static const _linesStep = 25;

  // Wide token range: modern models accept very large contexts (250k+), so
  // let the user choose freely; the size-reduction cascade is the safety net.
  static const _tokensMin = 1000;
  static const _tokensMax = 250000;
  static const _tokensStep = 1000;

  @override
  Widget build(BuildContext context) {
    return _RowContainer(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SliderRow(
            icon: Icons.view_agenda_outlined,
            label: 'Lines per call',
            valueLabel: '$lines lines',
            colors: colors,
            value: lines.toDouble(),
            min: _linesMin.toDouble(),
            max: _linesMax.toDouble(),
            step: _linesStep,
            onChanged: (v) => onLinesChanged((v / _linesStep).round() * _linesStep),
          ),
          const SizedBox(height: 4),
          _SliderRow(
            icon: Icons.data_object,
            label: 'Token budget',
            valueLabel: '~$tokens tokens',
            colors: colors,
            value: tokens.toDouble(),
            min: _tokensMin.toDouble(),
            max: _tokensMax.toDouble(),
            step: _tokensStep,
            onChanged: (v) =>
                onTokensChanged((v / _tokensStep).round() * _tokensStep),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              'Sentences per AI call — the main knob. If the assembled '
              'prompt gets too big, it is split in half automatically.',
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One labeled slider row inside [_ChunkSizeTile].
class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valueLabel;
  final ColorScheme colors;
  final double value;
  final double min;
  final double max;
  final int step;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.colors,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(label, style: AppTypography.labelMedium),
                  ),
                  Text(
                    valueLabel,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: ((max - min) ~/ step).toInt(),
                label: valueLabel,
                activeColor: colors.primary,
                inactiveColor: colors.outlineVariant,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tile showing the configured API keys; tap opens the manage-keys sheet.
class _ApiKeysTile extends StatelessWidget {
  final ColorScheme colors;
  final List<String> keys;
  final ValueChanged<List<String>> onChanged;

  const _ApiKeysTile({
    required this.colors,
    required this.keys,
    required this.onChanged,
  });

  static String maskKey(String key) {
    if (key.length <= 8) return '••••••';
    return '${key.substring(0, 4)}…${key.substring(key.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final usable = keys.where((k) => k.trim().length >= 5).toList();
    return _RowContainer(
      colors: colors,
      trailing: const Icon(Icons.chevron_right, size: 20),
      child: InkWell(
        onTap: () => _showManageKeysSheet(context),
        child: Row(
          children: [
            const Icon(Icons.key, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('API Keys', style: AppTypography.labelMedium),
                  const SizedBox(height: 2),
                  Text(
                    usable.isEmpty
                        ? 'None — the AI Q&A key is used automatically'
                        : '${usable.length} key(s) · ${maskKey(usable.first)}',
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showManageKeysSheet(BuildContext context) async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ManageKeysSheet(keys: keys),
    );
    if (result != null) onChanged(result);
  }
}

/// Sheet to manage multiple API keys (add / remove / import from AI Q&A).
/// Keys are used in rotation by the runner to spread rate limits.
class _ManageKeysSheet extends ConsumerStatefulWidget {
  final List<String> keys;

  const _ManageKeysSheet({required this.keys});

  @override
  ConsumerState<_ManageKeysSheet> createState() => _ManageKeysSheetState();
}

class _ManageKeysSheetState extends ConsumerState<_ManageKeysSheet> {
  late final TextEditingController _addKeyController;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _addKeyController = TextEditingController();
  }

  @override
  void dispose() {
    _addKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final keys = List<String>.from(widget.keys);
    final aiKey = ref.read(aiQaSettingsProvider).apiKey.trim();
    final aiKeyImported =
        aiKey.isNotEmpty && keys.any((k) => k.trim() == aiKey);

    return Padding(
      // Keyboard insets so the add-field stays visible while typing.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusSheet),
          ),
        ),
        padding: const EdgeInsets.all(AppDimensions.md),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  Icon(Icons.key, size: 20, color: colors.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Manage API Keys',
                    style: AppTypography.headlineSmall.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Keys are used in rotation to spread rate limits across '
                'your accounts.',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // ── Existing keys ─────────────────────────────────────
              if (keys.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No keys yet.',
                    style: AppTypography.labelMedium.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (var i = 0; i < keys.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSm,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.vpn_key,
                            size: 16,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _ApiKeysTile.maskKey(keys[i]),
                              style: AppTypography.labelMedium.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (i == 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                'Primary',
                                style: AppTypography.labelSmall.copyWith(
                                  color: colors.primary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: colors.error,
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                setState(() => keys.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  ),

              const SizedBox(height: 12),

              // ── Add key ───────────────────────────────────────────
              TextField(
                controller: _addKeyController,
                obscureText: _obscure,
                maxLines: 1,
                decoration: InputDecoration(
                  labelText: 'Add an API key',
                  hintText: 'Paste a new key',
                  filled: true,
                  fillColor: colors.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) {
                  final trimmed = _addKeyController.text.trim();
                  if (trimmed.length >= 5 && !keys.contains(trimmed)) {
                    setState(() {
                      keys.add(trimmed);
                      _addKeyController.clear();
                    });
                  }
                },
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final trimmed = _addKeyController.text.trim();
                        if (trimmed.length < 5) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Enter a valid API key.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        setState(() {
                          if (!keys.contains(trimmed)) keys.add(trimmed);
                          _addKeyController.clear();
                        });
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                    ),
                  ),
                  if (!aiKeyImported && aiKey.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            if (!keys.any((k) => k.trim() == aiKey)) {
                              keys.add(aiKey);
                            }
                          });
                        },
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Import AI Q&A key'),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(keys),
                  icon: const Icon(Icons.check, size: 20),
                  label: Text(loc.t('Done')),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Model field with a "check key & load models" button and model chips
/// (mirrors the AI Q&A settings sheet).
class _ModelConfigTile extends StatelessWidget {
  final ColorScheme colors;
  final TextEditingController controller;
  final bool loading;
  final List<String> models;
  final String? error;
  final VoidCallback onCheckKey;
  final ValueChanged<String> onChanged;

  const _ModelConfigTile({
    required this.colors,
    required this.controller,
    required this.loading,
    required this.models,
    required this.error,
    required this.onCheckKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy_outlined, size: 20, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Model', style: AppTypography.labelMedium),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: 1,
            decoration: InputDecoration(
              hintText: 'gemini-flash-latest',
              filled: true,
              fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                borderSide: BorderSide(color: colors.outlineVariant),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
            onChanged: onChanged,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: loading ? null : onCheckKey,
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_download_outlined, size: 18),
              label: Text(
                loading
                    ? 'Checking key & loading models…'
                    : 'Check key & load models',
              ),
            ),
          ),
          if (error != null) ...[
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
                      error!,
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
          if (models.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${models.length} models available — tap to choose:',
              style: AppTypography.labelSmall.copyWith(
                color: Colors.green[600],
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: models.take(15).map((model) {
                  final isSelected = controller.text == model;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(
                        model,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? colors.onPrimary
                              : colors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () {
                        controller.text = model;
                        controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: controller.text.length),
                        );
                        onChanged(model);
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
      ),
    );
  }
}

/// Compact step-by-step guide to getting a free API key, mirroring the AI
/// Q&A settings sheet.
class _ProviderGuideCard extends StatelessWidget {
  final AiProvider provider;
  final ColorScheme colors;

  const _ProviderGuideCard({
    required this.provider,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isGemini = provider == AiProvider.gemini;
    final title = isGemini
        ? loc.t('Get a free Gemini API key')
        : loc.t('Get a free OpenRouter API key');
    final intro = isGemini
        ? loc.t('Gemini is free for everyone — just 4 easy steps:')
        : loc.t('OpenRouter is free to join — just 4 easy steps:');
    final steps = isGemini
        ? [
            loc.t('Tap "Get free Gemini API key" below.'),
            loc.t('Sign in with your Google account (free, no credit card).'),
            loc.t('Tap "Create API key" and copy it (it starts with AIza).'),
            loc.t('Paste it in the API Key field above — it is checked automatically.'),
          ]
        : [
            loc.t('Tap "Get free OpenRouter API key" below.'),
            loc.t('Sign in with Google or GitHub (free, no credit card).'),
            loc.t('Tap "Create API key" and copy it (it starts with sk-or-).'),
            loc.t('No credit card needed. Free models (marked :free) are selected automatically.'),
          ];

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Container(
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
                Icon(Icons.key, size: 16, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.labelMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              intro,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < steps.length; i++)
              Padding(
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
                          '${i + 1}',
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
                        steps[i],
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.onSurface,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(provider.apiKeyCreationUrl);
                  if (uri == null) return;
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(title),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Searchable language picker shown as a tile that opens a dialog.
class _LanguagePickerTile extends ConsumerWidget {
  final ColorScheme colors;
  final String selected;
  final ValueChanged<String> onSelected;

  const _LanguagePickerTile({
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _RowContainer(
      colors: colors,
      trailing: const Icon(Icons.chevron_right, size: 20),
      child: InkWell(
        onTap: () => _showLanguagePicker(context, selected, onSelected),
        child: Row(
          children: [
            const Icon(Icons.language, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                translatorLangName(selected),
                style: AppTypography.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLanguagePicker(
    BuildContext context,
    String selected,
    ValueChanged<String> onSelected,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _SearchableLanguageDialog(selected: selected),
    );
    if (result != null) onSelected(result);
  }
}

/// Searchable list of all supported target languages.
class _SearchableLanguageDialog extends StatefulWidget {
  final String selected;

  const _SearchableLanguageDialog({required this.selected});

  @override
  State<_SearchableLanguageDialog> createState() =>
      _SearchableLanguageDialogState();
}

class _SearchableLanguageDialogState extends State<_SearchableLanguageDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entries = kTranslatorLangNames.entries.where((e) {
      if (_query.isEmpty) return true;
      return e.key.contains(_query.toLowerCase()) ||
          e.value.toLowerCase().contains(_query.toLowerCase());
    }).toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return AlertDialog(
      title: TextField(
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Search languages…',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
      content: SizedBox(
        width: 360,
        height: 400,
        child: ListView.builder(
          itemCount: entries.length,
          itemBuilder: (ctx, i) {
            final e = entries[i];
            final isSelected = e.key == widget.selected;
            return ListTile(
              title: Text(e.value),
              subtitle: Text(e.key),
              trailing: isSelected
                  ? Icon(Icons.check, color: colors.primary)
                  : null,
              selected: isSelected,
              onTap: () => Navigator.of(ctx).pop(e.key),
            );
          },
        ),
      ),
    );
  }
}

/// Book tick-list tile; opens a searchable multi-select sheet.
class _BookPickerTile extends ConsumerStatefulWidget {
  final ColorScheme colors;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  const _BookPickerTile({
    required this.colors,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  ConsumerState<_BookPickerTile> createState() => _BookPickerTileState();
}

class _BookPickerTileState extends ConsumerState<_BookPickerTile> {
  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final count = widget.selectedIds.length;
    return _RowContainer(
      colors: colors,
      trailing: const Icon(Icons.chevron_right, size: 20),
      child: InkWell(
        onTap: () => _showBookPicker(context),
        child: Row(
          children: [
            const Icon(Icons.menu_book, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Books', style: AppTypography.labelMedium),
                  const SizedBox(height: 2),
                  Text(
                    count == 0
                        ? 'None selected — tap to choose'
                        : '$count book(s) selected',
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBookPicker(BuildContext context) async {
    final db = await ref.read(epitakaDbProvider.future);
    final rows = await db.customSelect(
      'SELECT book_id, book_name, category, nikaya, sub_nikaya '
      'FROM books ORDER BY category, nikaya, sub_nikaya, book_id ASC',
    ).get();
    if (!context.mounted) return;

    final books = [
      for (final r in rows)
        TranslatorBookEntry(
          bookId: r.data['book_id'] as String? ?? '',
          bookName: r.data['book_name'] as String? ?? '',
          category: r.data['category'] as String? ?? '',
          nikaya: r.data['nikaya'] as String?,
          subNikaya: r.data['sub_nikaya'] as String?,
        ),
    ]..removeWhere((b) => b.bookId.isEmpty);

    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => _BookPickerDialog(
        books: books,
        selectedIds: widget.selectedIds,
      ),
    );
    if (result != null) widget.onChanged(result);
  }
}

/// Searchable, category-grouped book picker (multi-select). Search ignores
/// Pāli diacritics (pācittiya ≡ pacittiya).
class _BookPickerDialog extends StatefulWidget {
  final List<TranslatorBookEntry> books;
  final List<String> selectedIds;

  const _BookPickerDialog({
    required this.books,
    required this.selectedIds,
  });

  @override
  State<_BookPickerDialog> createState() => _BookPickerDialogState();
}

class _BookPickerDialogState extends State<_BookPickerDialog> {
  String _query = '';
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedIds.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final q = normalizePaliFuzzy(_query);
    final filtered = widget.books.where((b) {
      if (q.isEmpty) return true;
      return normalizePaliFuzzy(b.bookId).contains(q) ||
          normalizePaliFuzzy(b.bookName).contains(q);
    }).toList();

    // Group by category → nikaya.
    final groups = <String, List<TranslatorBookEntry>>{};
    for (final b in filtered) {
      final keyParts = [b.category, b.nikaya ?? ''].where((s) => s.isNotEmpty);
      final key = keyParts.isEmpty ? 'Other' : keyParts.join(' / ');
      groups.putIfAbsent(key, () => []).add(b);
    }
    final sortedKeys = groups.keys.toList()..sort();

    return AlertDialog(
      title: TextField(
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Search books… (diacritics ignored)',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
      content: SizedBox(
        width: 420,
        height: 480,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  for (final key in sortedKeys) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        key.toUpperCase(),
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final b in groups[key]!)
                      CheckboxListTile(
                        dense: true,
                        title: Text(
                          b.bookName,
                          style: AppTypography.labelMedium,
                        ),
                        subtitle: Text(b.bookId),
                        value: _selected.contains(b.bookId),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(b.bookId);
                          } else {
                            _selected.remove(b.bookId);
                          }
                        }),
                      ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _selected = {}),
                    child: const Text('Clear'),
                  ),
                  Text('${_selected.length} selected'),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_selected.toList()),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Editable system prompt with reset.
class _PromptTile extends StatelessWidget {
  final ColorScheme colors;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onReset;
  final VoidCallback onLoadDefault;

  const _PromptTile({
    required this.colors,
    required this.controller,
    required this.onChanged,
    required this.onReset,
    required this.onLoadDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, size: 20, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Custom prompt',
                  style: AppTypography.labelMedium,
                ),
              ),
              TextButton.icon(
                onPressed: onLoadDefault,
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('Load default'),
              ),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt, size: 16),
                label: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Leave empty to use the default prompt, or tap "Load default" '
            'to edit a copy of it ({lang_name} is substituted at run time).',
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: TextField(
              controller: controller,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                hintText: 'Default prompt (leave empty)',
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
