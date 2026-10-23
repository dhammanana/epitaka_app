import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/utils/app_localizations.dart';
import 'velthuis_help_icon.dart';

/// One row of the search box's "more" menu: what it shows and what tapping
/// it does. [checked] marks a switch that is on (the regex state).
class SearchBoxMoreItem {
  final String id;
  final String label;
  final IconData? icon;
  final bool checked;
  final VoidCallback onTap;

  const SearchBoxMoreItem({
    required this.id,
    required this.label,
    required this.onTap,
    this.icon,
    this.checked = false,
  });
}

/// The actions that end every search box: the clear (X) button while there
/// is text, then the "more" (⋮) menu. The menu holds what every Pāli box
/// shares — the Velthuis help card and the regex switch — then the box's
/// own [extraItems] (the dictionary adds its toolbar switch).
///
/// The regex hotkey (Alt+R, `app_shortcuts.dart` 'regex-toggle') finds this
/// widget inside the focused field and calls [onToggleRegex], so the
/// shortcut works without any visible Rx button.
class SearchBoxSuffixActions extends StatelessWidget {
  /// Whether the clear button shows. Callers hide it on an empty box.
  final bool showClear;
  final VoidCallback onClear;

  /// Regex state of the box: on when the box takes a pattern. Without
  /// [onToggleRegex] the menu lists no regex item at all.
  final bool regexOn;
  final VoidCallback? onToggleRegex;

  /// Whether the menu lists the Velthuis typing help, with its Sanskrit
  /// rows ([sanskrit]) or without.
  final bool velthuisHelp;
  final bool sanskrit;

  /// The box's own menu items, after the shared two.
  final List<SearchBoxMoreItem> extraItems;

  const SearchBoxSuffixActions({
    super.key,
    required this.onClear,
    this.showClear = false,
    this.regexOn = false,
    this.onToggleRegex,
    this.velthuisHelp = true,
    this.sanskrit = true,
    this.extraItems = const [],
  });

  bool get _hasMenu =>
      velthuisHelp || (onToggleRegex != null && !kIsWeb) || extraItems.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showClear)
          _clearButton(loc),
        if (_hasMenu)
          Padding(
            // A hair of stand-off from the box's rounded edge.
            padding: const EdgeInsets.only(right: 2),
            child: _menu(context, loc),
          ),
      ],
    );
  }

  /// The plain IconButton fills a 48 px-a-side slot in the suffix, which
  /// keyed the word out of the box on a phone. The clear and menu buttons
  /// run this close instead, so the field keeps the room.
  static final _compactStyle = IconButton.styleFrom(
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    minimumSize: const Size(32, 36),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  Widget _clearButton(AppLocalizations loc) => IconButton(
    icon: const Icon(Icons.clear, size: 18),
    tooltip: loc.clear,
    onPressed: onClear,
    style: _compactStyle,
  );

  Widget _menu(BuildContext context, AppLocalizations loc) {
    final items = [
      if (velthuisHelp)
        SearchBoxMoreItem(
          id: 'help',
          label: loc.velthuisTyping,
          icon: Icons.help_outline,
          onTap: () => showVelthuisHelp(context, sanskrit: sanskrit),
        ),
      if (onToggleRegex != null && !kIsWeb)
        SearchBoxMoreItem(
          id: 'regex',
          label: loc.regularExpression,
          checked: regexOn,
          onTap: onToggleRegex!,
        ),
      ...extraItems,
    ];
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      tooltip: loc.moreOptions,
      padding: EdgeInsets.zero,
      style: _compactStyle,
      itemBuilder: (_) => [
        for (final item in items)
          PopupMenuItem(
            value: item.id,
            child: _menuRow(item, context),
          ),
      ],
      onSelected: (id) => items.firstWhere((item) => item.id == id).onTap(),
    );
  }

  Widget _menuRow(SearchBoxMoreItem item, BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 200,
      child: Row(
        children: [
          SizedBox(
            width: AppDimensions.lg,
            child: item.checked
                ? Icon(Icons.check, size: 18, color: colors.primary)
                : item.icon != null
                ? Icon(item.icon, size: 18, color: colors.onSurfaceVariant)
                : null,
          ),
          Expanded(
            child: Text(
              item.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurface, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "regex-toggle" shortcut: press the more menu's regex item of the
/// search box that has the cursor. Every box puts the suffix inside its own
/// [TextField] decoration, so it is found from the focused field instead of
/// being wired into each box. Outside such a box the key does nothing.
void toggleRegexInFocusedBox() {
  // Web has no regex (isolates are absent, the item is hidden there).
  if (kIsWeb) return;
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return;
  Element? field;
  focused.visitAncestorElements((element) {
    if (element.widget is! TextField) return true;
    field = element;
    return false;
  });
  SearchBoxSuffixActions? actions;
  void search(Element element) {
    if (actions != null) return;
    final widget = element.widget;
    if (widget is SearchBoxSuffixActions) {
      actions = widget;
    } else {
      element.visitChildElements(search);
    }
  }

  field?.visitChildElements(search);
  actions?.onToggleRegex?.call();
}
