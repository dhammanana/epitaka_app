import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';

/// How the Search box matches text. Fuzzy: every term is a prefix, so
/// `katv` still finds `katvāna`. Exact: whole words only. Rx: the box holds
/// a regular expression, which sets its own matching.
enum MatchMode { fuzzy, exact, regex }

/// The Fuzzy | Exact | Rx switch at the start of the Search options row.
/// The three are one choice, so one tap gets from any mode to any other;
/// the old Fuzzy chip vanished in rx mode and could not lead out of it.
class MatchModeSwitch extends StatelessWidget {
  final MatchMode mode;
  final ValueChanged<MatchMode> onSelected;

  /// The sidebar's smaller size; the Search screen uses the full one.
  final bool compact;

  const MatchModeSwitch({
    super.key,
    required this.mode,
    required this.onSelected,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(compact ? 12 : 16);
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: radius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _part(MatchMode.fuzzy, loc.fuzzy, colors, radius),
          _part(MatchMode.exact, loc.exact, colors, radius),
          // Every rx match runs in an isolate, and web has none.
          if (!kIsWeb)
            Tooltip(
              message: loc.regularExpression,
              child: _part(MatchMode.regex, 'Rx', colors, radius),
            ),
        ],
      ),
    );
  }

  Widget _part(
    MatchMode part,
    String label,
    ColorScheme colors,
    BorderRadius radius,
  ) {
    final selected = part == mode;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selected ? null : () => onSelected(part),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 8,
            vertical: compact ? 2 : 4,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.secondaryContainer : null,
            borderRadius: radius,
          ),
          child: Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              fontSize: compact ? 10 : null,
              color: selected
                  ? colors.onSecondaryContainer
                  : colors.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
