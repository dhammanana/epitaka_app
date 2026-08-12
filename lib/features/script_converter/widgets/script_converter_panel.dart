// lib/features/script_converter/widgets/script_converter_panel.dart
//
// Compact single-column Pāli script converter for the desktop sidebar.
// Uses the same Sinhala-pivot conversion as the reader, search and
// dictionary, so output always matches what the app shows elsewhere.
//
// The full-screen [ScriptConverterScreen] keeps the wide two-column layout
// for the route; this panel is the narrow-space variant (source field, a
// horizontally scrolling script picker, and the result with copy).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/pali_script_converter.dart';
import '../../../core/utils/pali_text_utils.dart' show scriptFontFamily;
import '../services/script_conversion.dart';

/// Desktop sidebar panel: convert Pāli text between any of the app's scripts.
class ScriptConverterPanel extends ConsumerStatefulWidget {
  const ScriptConverterPanel({super.key});

  @override
  ConsumerState<ScriptConverterPanel> createState() =>
      _ScriptConverterPanelState();
}

class _ScriptConverterPanelState extends ConsumerState<ScriptConverterPanel> {
  final TextEditingController _input = TextEditingController();
  Script _target = Script.roman;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    // Default to the user's reading script so the first conversion already
    // feels useful.
    _target = ref.read(settingsProvider).paliScript;
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String get _output => convertPaliAnyScript(_input.text, _target);

  Future<void> _copyResult() async {
    final output = _output;
    if (output.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: output));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _clearInput() {
    _input.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final output = _output;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Source input ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.sm,
            AppDimensions.sm,
            AppDimensions.sm,
            0,
          ),
          child: TextField(
            controller: _input,
            minLines: 2,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            style: AppTypography.bodyPali.copyWith(
              fontSize: 15,
              color: colors.onSurface,
            ),
            decoration: InputDecoration(
              hintText: loc.typePaliText,
              hintStyle: AppTypography.bodyTranslation.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 13,
              ),
              filled: true,
              fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppDimensions.sm, 4, AppDimensions.sm, 0),
          child: Row(
            children: [
              Text(
                '${_input.text.characters.length} ${loc.characters}',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.outline,
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              if (_input.text.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearInput,
                  icon: const Icon(Icons.clear, size: 13),
                  label: Text(loc.clear),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 28),
                    foregroundColor: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),

        // ── Target script picker ──────────────────────────────────
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
            itemCount: listOfScripts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final info = listOfScripts[index];
              final selected = info.script == _target;
              return GestureDetector(
                onTap: () => setState(() => _target = info.script),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.primaryContainer
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    border: Border.all(
                      color: selected
                          ? colors.primary.withValues(alpha: 0.6)
                          : colors.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      info.nameInLocale,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? colors.onPrimaryContainer
                            : colors.onSurfaceVariant,
                        fontFamily: scriptFontFamily(info.script),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),

        // ── Output ────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.sm,
              0,
              AppDimensions.sm,
              0,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
              ),
              child: output.isEmpty
                  ? Center(
                      child: Text(
                        loc.converterOutputHint,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyTranslation.copyWith(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: SelectableText(
                        output,
                        style: AppTypography.bodyPali.copyWith(
                          fontSize: 16,
                          height: 1.5,
                          color: colors.onSurface,
                          fontFamily: scriptFontFamily(_target),
                        ),
                      ),
                    ),
            ),
          ),
        ),

        // ── Footer actions ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(AppDimensions.sm, 6, AppDimensions.sm, AppDimensions.sm),
          child: Row(
            children: [
              Text(
                '${output.characters.length} ${loc.characters}',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.outline,
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: output.isEmpty ? null : _copyResult,
                icon: Icon(_copied ? Icons.check : Icons.copy, size: 14),
                label: Text(_copied ? loc.copied : loc.copy),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 30),
                  textStyle: const TextStyle(fontSize: 11.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
