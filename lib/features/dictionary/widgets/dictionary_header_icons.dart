import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_localizations.dart';
import '../../dpd/providers/dpd_settings_provider.dart';
import '../providers/dictionary_font_scale_provider.dart';
import '../providers/dictionary_header_provider.dart';
import 'dictionary_level_controls.dart';

/// Width of [DictionaryHeaderIcons], so a header can tell whether it fits.
const kDictionaryHeaderIconsWidth = 352.0;

/// The dictionary's icon row: the three levels, the summary, grammar and
/// examples open, the text size,
/// jump to top, the history list, and a button that hides the row.
class DictionaryHeaderIcons extends ConsumerWidget {
  const DictionaryHeaderIcons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final showSummary = ref.watch(
      dpdSettingsProvider.select((s) => s.showSummary),
    );
    final grammarOpen = ref.watch(
      dpdSettingsProvider.select((s) => s.grammarOpen),
    );
    final examplesOpen = ref.watch(
      dpdSettingsProvider.select((s) => s.examplesOpen),
    );
    final scale = ref.watch(dictionaryFontScaleProvider);
    void step(double by) => ref
        .read(dictionaryFontScaleProvider.notifier)
        .setScale(ref.read(dictionaryFontScaleProvider) + by);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DictionaryLevelButtons(),
        DictionaryHeaderIconButton(
          icon: Icons.view_list,
          tooltip: loc.dictionaryHeaderSummary,
          lit: showSummary,
          onTap: () => ref
              .read(dpdSettingsProvider.notifier)
              .setShowSummary(!showSummary),
        ),
        DictionaryHeaderIconButton(
          label: 'g',
          tooltip: loc.dictionaryHeaderGrammar,
          lit: grammarOpen,
          onTap: () => ref
              .read(dpdSettingsProvider.notifier)
              .setGrammarOpen(!grammarOpen),
        ),
        DictionaryHeaderIconButton(
          label: 'e',
          tooltip: loc.dictionaryHeaderExamples,
          lit: examplesOpen,
          onTap: () => ref
              .read(dpdSettingsProvider.notifier)
              .setExamplesOpen(!examplesOpen),
        ),
        DictionaryHeaderIconButton(
          icon: Icons.text_decrease,
          flash: true,
          tooltip: loc.dictionaryHeaderSmaller,
          onTap: scale <= kDictionaryFontScaleMin
              ? null
              : () => step(-kDictionaryFontScaleStep),
        ),
        DictionaryHeaderIconButton(
          icon: Icons.text_increase,
          flash: true,
          tooltip: loc.dictionaryHeaderLarger,
          onTap: scale >= kDictionaryFontScaleMax
              ? null
              : () => step(kDictionaryFontScaleStep),
        ),
        DictionaryHeaderIconButton(
          icon: Icons.vertical_align_top,
          tooltip: loc.dictionaryHeaderTop,
          onTap: () =>
              ref.read(dictionaryScrollTopRequestProvider.notifier).state++,
        ),
        DictionaryHeaderIconButton(
          icon: Icons.history,
          tooltip: loc.dictionaryHeaderHistory,
          onTap: () =>
              ref.read(dictionaryHistoryRequestProvider.notifier).state++,
        ),
        DictionaryHeaderIconButton(
          icon: Icons.visibility_off_outlined,
          tooltip: loc.dictionaryHeaderHide,
          onTap: () =>
              ref.read(dictionaryHeaderIconsProvider.notifier).set(false),
        ),
      ],
    );
  }
}

/// One 28 px icon button of the row. [lit] marks an option that is on; a null
/// [onTap] greys the icon. With [flash] the button lights up for a moment when
/// tapped, for an action that has no on or off state of its own.
class DictionaryHeaderIconButton extends StatefulWidget {
  const DictionaryHeaderIconButton({
    super.key,
    this.icon,
    this.label,
    required this.tooltip,
    required this.onTap,
    this.lit = false,
    this.flash = false,
  });

  /// Either an [icon] or a short [label] fills the button.
  final IconData? icon;
  final String? label;
  final String tooltip;
  final VoidCallback? onTap;
  final bool lit;
  final bool flash;

  @override
  State<DictionaryHeaderIconButton> createState() =>
      _DictionaryHeaderIconButtonState();
}

class _DictionaryHeaderIconButtonState extends State<DictionaryHeaderIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    value: 1,
  );

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  void _tap() {
    if (widget.flash) _flash.forward(from: 0);
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final onTap = widget.onTap;
    return Tooltip(
      message: widget.tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kDictionaryIconGap),
        child: InkWell(
          onTap: onTap == null ? null : _tap,
          borderRadius: BorderRadius.circular(6),
          child: AnimatedBuilder(
            animation: _flash,
            builder: (context, _) {
              // 0 right after a tap, 1 at rest: the lit look fades out.
              final lit = widget.lit || _flash.value < 1;
              final color = onTap == null
                  ? colors.onSurface.withValues(alpha: 0.3)
                  : lit
                  ? colors.onPrimaryContainer
                  : colors.onSurfaceVariant;
              final background = widget.lit
                  ? colors.primaryContainer
                  : Color.lerp(
                      colors.primaryContainer,
                      colors.primaryContainer.withValues(alpha: 0),
                      _flash.value,
                    );
              return Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: widget.icon != null
                    ? Icon(widget.icon, size: 16, color: color)
                    : Center(
                        child: Text(
                          widget.label!,
                          // A line height of 1 keeps the letter centred on
                          // the icons beside it; the default sits it low.
                          style: TextStyle(
                            fontSize: 14,
                            height: 1,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                          strutStyle: const StrutStyle(
                            fontSize: 14,
                            height: 1,
                            forceStrutHeight: true,
                          ),
                        ),
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}
