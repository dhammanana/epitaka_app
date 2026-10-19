import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/utils/app_localizations.dart';
import '../../core/theme/app_typography.dart';
import '../utils/app_shortcuts.dart';

/// The "regex-toggle" shortcut: press the Rx button of the search box that
/// has the cursor. Every box puts its button inside its own [TextField]
/// decoration, so the button is found from the focused field instead of
/// being wired into each box. Outside such a box the key does nothing.
void toggleRegexInFocusedBox() {
  // The button is hidden on web, so its box takes no regex there.
  if (kIsWeb) return;
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return;
  Element? field;
  focused.visitAncestorElements((element) {
    if (element.widget is! TextField) return true;
    field = element;
    return false;
  });
  RegexToggleButton? button;
  void search(Element element) {
    if (button != null) return;
    final widget = element.widget;
    if (widget is RegexToggleButton) {
      button = widget;
    } else {
      element.visitChildElements(search);
    }
  }

  field?.visitChildElements(search);
  button?.onToggle();
}

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
    // A text box gives its suffix at least 48 px. Without this floor, Rx alone
    // is narrower, sits at the left of that slot and shifts when the help
    // icon beside it hides.
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: kMinInteractiveDimension),
      child: Align(
        alignment: Alignment.centerRight,
        child: Tooltip(
          message: AppShortcuts.tooltip(loc.regularExpression, 'regex-toggle'),
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
                // The button is last in the box, so the right margin matches the
                // help icon's 8 px padding that used to sit after it.
                margin: const EdgeInsets.only(left: 2, right: 8),
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
        ),
      ),
    );
  }
}
