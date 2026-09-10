// lib/core/models/toolbar_item.dart
//
// A configurable entry in the reader's bottom toolbar.
//
// The reader toolbar used to be a fixed, hard-coded row of buttons. Users
// can now choose which of those actions appear and in what order
// (Settings → Toolbar).

/// Stable ids for the reader toolbar's built-in actions.
class ToolbarBuiltins {
  ToolbarBuiltins._();

  static const contents = 'contents';
  static const outline = 'outline';
  static const search = 'search';
  static const dictionary = 'dictionary';
  static const jump = 'jump';
  static const displayLayout = 'displayLayout';
  static const listen = 'listen';
  static const bookmark = 'bookmark';
  static const annotations = 'annotations';
  static const summarize = 'summarize';

  /// The built-ins in their default display order.
  static const List<String> defaults = [
    contents,
    outline,
    search,
    dictionary,
    jump,
    displayLayout,
    listen,
    bookmark,
    annotations,
    summarize,
  ];

  /// Built-ins that are off by default (user can enable in Settings → Toolbar).
  static const Set<String> disabledByDefault = {bookmark, summarize};

  /// Default enabled state for [id].
  static bool defaultEnabledFor(String id) => !disabledByDefault.contains(id);
}

/// One configurable entry in the reader toolbar.
class ToolbarItem {
  final String id;

  /// Whether the action is shown in the toolbar. Disabled items keep their
  /// place in the order so re-enabling restores them where they were.
  final bool enabled;

  const ToolbarItem({required this.id, this.enabled = true});

  Map<String, dynamic> toJson() => {'id': id, 'enabled': enabled};

  factory ToolbarItem.fromJson(Map<String, dynamic> json) {
    return ToolbarItem(
      id: json['id'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  ToolbarItem copyWith({bool? enabled}) {
    return ToolbarItem(id: id, enabled: enabled ?? this.enabled);
  }
}

/// The default toolbar configuration: built-ins in natural order;
/// [ToolbarBuiltins.disabledByDefault] start off.
List<ToolbarItem> defaultToolbarItems() {
  return [
    for (final id in ToolbarBuiltins.defaults)
      ToolbarItem(id: id, enabled: ToolbarBuiltins.defaultEnabledFor(id)),
  ];
}
