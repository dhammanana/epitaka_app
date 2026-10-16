import 'package:flutter/material.dart';

import '../../core/utils/app_localizations.dart';
import '../../core/utils/velthuis.dart';

/// Help icon for every box where Pāli is typed. Pointing at it shows the
/// Velthuis shortcuts at once; on a touch screen a tap shows them, and the
/// next tap anywhere hides them.
///
/// The card ignores the pointer and hides as soon as the pointer leaves the
/// icon, so it never stands in the way of a click.
class VelthuisHelpIcon extends StatelessWidget {
  /// Off for boxes where English is typed: the card then leaves out the
  /// Sanskrit rows, which those boxes do not convert.
  final bool sanskrit;

  const VelthuisHelpIcon({super.key, this.sanskrit = true});

  /// The rows the card lists: the converter's lowercase Pāli rules, then its
  /// lowercase Sanskrit rules.
  static final rows = _lowercase(velthuisRules);
  static final sanskritRows = _lowercase(velthuisSanskritRules);

  static List<(String, String)> _lowercase(List<(String, String)> rules) => [
    for (final rule in rules)
      if (rule.$1 == rule.$1.toLowerCase()) rule,
  ];

  static String _lines(List<(String, String)> rules) => [
    for (final (from, to) in rules) '${from.padRight(3)}  →  $to',
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final mono = TextStyle(
      fontFamily: 'monospace',
      fontSize: 14,
      height: 1.4,
      color: colors.onSurface,
    );
    final heading = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.bold,
      color: colors.onSurface,
    );

    return Tooltip(
      richMessage: TextSpan(
        children: [
          TextSpan(text: '${loc.velthuisTyping}\n', style: heading),
          TextSpan(text: _lines(rows), style: mono),
          TextSpan(text: '\n${_lines(velthuisDoubleVowels)}', style: mono),
          if (sanskrit) ...[
            TextSpan(text: '\n\n${loc.sanskrit}\n', style: heading),
            TextSpan(text: _lines(sanskritRows), style: mono),
          ],
        ],
      ),
      waitDuration: Duration.zero,
      showDuration: const Duration(seconds: 10),
      triggerMode: TooltipTriggerMode.tap,
      ignorePointer: true,
      // A screen reader would read the whole card on every box.
      excludeFromSemantics: true,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        border: Border.all(color: colors.primary, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Icon(
          Icons.help_outline,
          size: 18,
          color: colors.onSurfaceVariant,
          semanticLabel: loc.velthuisTyping,
        ),
      ),
    );
  }
}
