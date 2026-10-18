import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/utils/app_localizations.dart';
import '../../core/theme/app_typography.dart';

/// The "regex" switch beside the clear button of a search box. On, the box
/// takes a regular expression instead of words. The label is "Rx" —
/// the user's pick after `.*` (the VS Code-style symbol) was tried.
class RegexToggleButton extends StatelessWidget {
  final bool on;
  final VoidCallback onToggle;

  const RegexToggleButton({
    super.key,
    required this.on,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Every Rx match runs in an isolate (spec K), and web has none.
    if (kIsWeb) return const SizedBox.shrink();
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: loc.regularExpression,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        toggled: on,
        label: loc.regularExpression,
        excludeSemantics: true,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: on ? colors.primaryContainer : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Rx',
              style: AppTypography.labelSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: on ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
