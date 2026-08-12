// lib/features/script_converter/screens/script_converter_screen.dart
//
// Convert Pāli text between any of the app's 18 scripts.
//
// Responsive design:
//   • Mobile / narrow — a vertical stack: intro, source card, swap button,
//     target card (script chips in a horizontal scroll row).
//   • Desktop / wide — a centered, max-width two-column layout: source on
//     the left, target on the right, with the swap button between them and
//     the script chips wrapped into a grid instead of scrolling.
//
// The conversion itself uses the same Sinhala pivot as the reader, search
// and dictionary, so output always matches what the app shows elsewhere.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/pali_script_converter.dart';
import '../../../core/utils/pali_text_utils.dart' show scriptFontFamily;
import '../../../core/utils/responsive_breakpoint.dart';
import '../services/script_conversion.dart';

/// Full-screen Pāli script converter.
class ScriptConverterScreen extends ConsumerStatefulWidget {
  const ScriptConverterScreen({super.key});

  @override
  ConsumerState<ScriptConverterScreen> createState() =>
      _ScriptConverterScreenState();
}

class _ScriptConverterScreenState extends ConsumerState<ScriptConverterScreen> {
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

  void _copyResult() {
    final output = _output;
    if (output.isEmpty) return;
    Clipboard.setData(ClipboardData(text: output));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _swapToInput() {
    final output = _output;
    if (output.isEmpty) return;
    _input.text = output;
    _input.selection = TextSelection.collapsed(offset: output.length);
    setState(() {});
  }

  void _clearInput() {
    _input.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    final isFromDrawer =
        GoRouterState.of(context).uri.queryParameters['fromDrawer'] == 'true';
    final wide = _isWide(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: AppDimensions.appBarHeight,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(isFromDrawer ? Icons.menu : Icons.arrow_back),
          color: colors.onSurfaceVariant,
          tooltip: loc.navigationMenu,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          loc.scriptConverter,
          style: AppTypography.headlineSmall.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: wide ? _buildDesktopBody(colors, loc) : _buildMobileBody(colors, loc),
    );
  }

  /// True when there is room for the side-by-side layout: a desktop-width
  /// window (this includes desktop web / tablet landscape via width only).
  bool _isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= ResponsiveBreakpoint.desktopWidth;

  // ── Mobile: vertical stack ───────────────────────────────────────────

  Widget _buildMobileBody(ColorScheme colors, AppLocalizations loc) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.sm,
        AppDimensions.md,
        AppDimensions.xl,
      ),
      children: [
        _buildIntro(colors, loc),
        const SizedBox(height: AppDimensions.md),
        _buildSourceCard(colors, loc),
        Center(
          child: _buildSwapButton(colors, loc),
        ),
        _buildTargetCard(colors, loc, wrapScripts: false),
      ],
    );
  }

  // ── Desktop: centered two-column layout ───────────────────────────────

  Widget _buildDesktopBody(ColorScheme colors, AppLocalizations loc) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIntro(colors, loc),
              const SizedBox(height: AppDimensions.md),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Source (left)
                    Expanded(child: _buildSourceCard(colors, loc)),
                    // Swap button (center)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.md,
                        ),
                        child: _buildSwapButton(colors, loc),
                      ),
                    ),
                    // Target (right)
                    Expanded(child: _buildTargetCard(colors, loc, wrapScripts: true)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Intro ────────────────────────────────────────────────────────────

  Widget _buildIntro(ColorScheme colors, AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withValues(alpha: 0.5),
            colors.tertiaryContainer.withValues(alpha: 0.35),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.swap_horiz, color: colors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.scriptConverterTitle,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  loc.scriptConverterSubtitle,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Source card ──────────────────────────────────────────────────────

  Widget _buildSourceCard(ColorScheme colors, AppLocalizations loc) {
    final detected = detectDominantScript(_input.text);

    return _Card(
      title: loc.from,
      icon: Icons.input,
      colors: colors,
      trailing: detected == null
          ? null
          : _ScriptBadge(label: _scriptLabel(detected), script: detected, colors: colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _input,
            // A roomy input — the main working area of the converter.
            minLines: 6,
            maxLines: 14,
            onChanged: (_) => setState(() {}),
            style: AppTypography.bodyPali.copyWith(
              fontSize: 17,
              color: colors.onSurface,
            ),
            decoration: InputDecoration(
              hintText: loc.typePaliText,
              hintStyle: AppTypography.bodyTranslation.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              filled: true,
              fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${_input.text.characters.length} ${loc.characters}',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.outline,
                  fontSize: 10.5,
                ),
              ),
              const Spacer(),
              if (_input.text.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearInput,
                  icon: const Icon(Icons.clear, size: 14),
                  label: Text(loc.clear),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Target card ──────────────────────────────────────────────────────

  Widget _buildTargetCard(
    ColorScheme colors,
    AppLocalizations loc, {
    required bool wrapScripts,
  }) {
    final output = _output;

    return _Card(
      title: loc.to,
      icon: Icons.abc,
      colors: colors,
      trailing: _ScriptBadge(script: _target, colors: colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Target script chips: horizontal scroll on mobile, Wrap grid on
          // desktop.
          if (wrapScripts)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final info in listOfScripts)
                  _ScriptChip(
                    info: info,
                    selected: info.script == _target,
                    colors: colors,
                    onTap: () => setState(() => _target = info.script),
                  ),
              ],
            )
          else
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: listOfScripts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final info = listOfScripts[index];
                  return _ScriptChip(
                    info: info,
                    selected: info.script == _target,
                    colors: colors,
                    onTap: () => setState(() => _target = info.script),
                  );
                },
              ),
            ),
          const SizedBox(height: 10),
          // Output box (taller so it balances the roomy source input)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
            ),
            child: output.isEmpty
                ? Text(
                    loc.converterOutputHint,
                    style: AppTypography.bodyTranslation.copyWith(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 13.5,
                    ),
                  )
                : SelectableText(
                    output,
                    style: AppTypography.bodyPali.copyWith(
                      fontSize: 18,
                      height: 1.5,
                      color: colors.onSurface,
                      fontFamily: scriptFontFamily(_target),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${output.characters.length} ${loc.characters}',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.outline,
                  fontSize: 10.5,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: output.isEmpty ? null : _copyResult,
                icon: Icon(_copied ? Icons.check : Icons.copy, size: 15),
                label: Text(_copied ? loc.copied : loc.copy),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwapButton(ColorScheme colors, AppLocalizations loc) {
    return IconButton.filledTonal(
      onPressed: _swapToInput,
      tooltip: loc.useResultAsInput,
      icon: const Icon(Icons.south, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  String _scriptLabel(Script script) {
    for (final info in listOfScripts) {
      if (info.script == script) return info.nameInLocale;
    }
    return script.name;
  }
}

// ── Small building blocks ───────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final ColorScheme colors;
  final Widget? trailing;
  final Widget child;

  const _Card({
    required this.title,
    required this.icon,
    required this.colors,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppTypography.labelMedium.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// A rounded badge showing a script name, rendered in that script's font.
class _ScriptBadge extends StatelessWidget {
  final String? label;
  final Script script;
  final ColorScheme colors;

  const _ScriptBadge({this.label, required this.script, required this.colors});

  @override
  Widget build(BuildContext context) {
    final text = label ?? _nativeName(script);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colors.onSecondaryContainer,
          fontFamily: scriptFontFamily(script),
        ),
      ),
    );
  }

  static String _nativeName(Script script) {
    for (final info in listOfScripts) {
      if (info.script == script) return info.nameInLocale;
    }
    return script.name;
  }
}

/// A script chip in the target selector.
class _ScriptChip extends StatelessWidget {
  final ScriptInfo info;
  final bool selected;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _ScriptChip({
    required this.info,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              fontSize: 14,
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
  }
}
