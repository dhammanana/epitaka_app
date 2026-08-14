// lib/core/models/context_menu_action.dart
//
// A configurable entry in the reader's text-selection context menu.
//
// The reader used to hard-code a fixed set of buttons (Copy, Excerpt, Copy
// Link, Dictionary, Explain, Summarize Ch., Share). Users can now choose
// which of those appear, in what order, plus:
//   • external apps that handle ACTION_PROCESS_TEXT (dictionaries,
//     translators, …) — discovered via [ProcessTextService],
//   • custom AI prompts: run a saved prompt against the selected text.

/// What kind of action a context-menu entry performs.
enum ContextMenuActionKind {
  /// One of the app's built-in actions (copy, excerpt, …). See [builtinId].
  builtin,

  /// An external installed app launched with the selected text.
  externalApp,

  /// A user-defined AI prompt run against the selected text.
  aiPrompt,
}

/// Stable ids for the app's built-in context menu actions.
class ContextMenuBuiltins {
  ContextMenuBuiltins._();

  static const highlight = 'highlight'; // text highlight with color
  static const note = 'note'; // markdown note
  static const copy = 'copy';
  static const excerpt = 'excerpt'; // copy with citation
  static const copyLink = 'copyLink';
  static const dictionary = 'dictionary';
  static const lookUp = 'lookUp'; // device dictionary (iOS/macOS native Look Up)
  static const explain = 'explain'; // AI
  static const summarizeChapter = 'summarizeChapter'; // AI
  static const share = 'share';

  /// The built-ins in their default display order.
  static const List<String> defaults = [
    highlight,
    note,
    copy,
    excerpt,
    copyLink,
    dictionary,
    lookUp,
    explain,
    summarizeChapter,
    share,
  ];
}

/// One entry in the customizable reader context menu.
class ContextMenuAction {
  final String id;

  final ContextMenuActionKind kind;
  final bool enabled;

  /// For [ContextMenuActionKind.builtin] — one of [ContextMenuBuiltins].
  final String? builtinId;

  /// For [ContextMenuActionKind.externalApp].
  final String? appPackage;
  final String? appLabel;

  /// For [ContextMenuActionKind.aiPrompt].
  final String? promptName;
  final String? prompt;

  const ContextMenuAction({
    required this.id,
    required this.kind,
    this.enabled = true,
    this.builtinId,
    this.appPackage,
    this.appLabel,
    this.promptName,
    this.prompt,
  });

  /// A human-readable label for settings UIs (not necessarily the label
  /// shown in the context menu itself, which may be localized).
  String get label =>
      appLabel ?? promptName ?? builtinId ?? id;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'enabled': enabled,
    if (builtinId != null) 'builtinId': builtinId,
    if (appPackage != null) 'appPackage': appPackage,
    if (appLabel != null) 'appLabel': appLabel,
    if (promptName != null) 'promptName': promptName,
    if (prompt != null) 'prompt': prompt,
  };

  factory ContextMenuAction.fromJson(Map<String, dynamic> json) {
    return ContextMenuAction(
      id: json['id'] as String? ?? '',
      kind: ContextMenuActionKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => ContextMenuActionKind.builtin,
      ),
      enabled: json['enabled'] as bool? ?? true,
      builtinId: json['builtinId'] as String?,
      appPackage: json['appPackage'] as String?,
      appLabel: json['appLabel'] as String?,
      promptName: json['promptName'] as String?,
      prompt: json['prompt'] as String?,
    );
  }

  ContextMenuAction copyWith({
    bool? enabled,
    String? appLabel,
    String? promptName,
    String? prompt,
  }) {
    return ContextMenuAction(
      id: id,
      kind: kind,
      enabled: enabled ?? this.enabled,
      builtinId: builtinId,
      appPackage: appPackage,
      appLabel: appLabel ?? this.appLabel,
      promptName: promptName ?? this.promptName,
      prompt: prompt ?? this.prompt,
    );
  }
}

/// The default context menu configuration: every built-in action, enabled,
/// in its natural order.
List<ContextMenuAction> defaultContextMenuActions() {
  return [
    for (final builtinId in ContextMenuBuiltins.defaults)
      ContextMenuAction(
        id: 'builtin:$builtinId',
        kind: ContextMenuActionKind.builtin,
        builtinId: builtinId,
      ),
  ];
}
