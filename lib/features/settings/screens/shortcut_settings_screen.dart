import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../shared/utils/app_shortcuts.dart';
import '../../../shared/widgets/search_box_decoration.dart';
import '../widgets/settings_app_bar.dart';

/// Full-page Keyboard Shortcuts for the phone Settings screen, shown on
/// tablets only.
class ShortcutSettingsScreen extends StatelessWidget {
  const ShortcutSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: SettingsAppBar(colors: colors),
      body: const ShortcutSettingsBody(),
    );
  }
}

/// Settings → Keyboard Shortcuts (the desktop settings window, and tablets
/// through [ShortcutSettingsScreen]): every shortcut in
/// [AppShortcuts.shortcutCatalog], grouped by section, with a button to
/// record a new combination and one to restore the default.
class ShortcutSettingsBody extends ConsumerStatefulWidget {
  const ShortcutSettingsBody({super.key});

  @override
  ConsumerState<ShortcutSettingsBody> createState() =>
      _ShortcutSettingsBodyState();
}

class _ShortcutSettingsBodyState extends ConsumerState<ShortcutSettingsBody> {
  /// The row that is waiting for a new combination, if any.
  String? _recordingId;

  final _search = TextEditingController();

  /// The row whose [_messages] are shown: why its last combination was
  /// refused, or which rows lost their keys to it or share it.
  String? _messageId;
  List<_Message> _messages = const [];

  // Pressed on their own these never make a shortcut, so recording waits.
  static final _modifierKeys = {
    ...LogicalKeyboardKey.expandSynonyms({
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.shift,
      LogicalKeyboardKey.alt,
      LogicalKeyboardKey.meta,
    }),
    LogicalKeyboardKey.capsLock,
    LogicalKeyboardKey.numLock,
    LogicalKeyboardKey.scrollLock,
    LogicalKeyboardKey.fn,
    LogicalKeyboardKey.fnLock,
    LogicalKeyboardKey.altGraph,
  };

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _startRecording(String id) {
    // The recorder only autofocuses when nothing holds focus, e.g. not while
    // the search box is being typed in.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _recordingId = id;
      _messageId = null;
      _messages = const [];
    });
  }

  void _stopRecording() => setState(() => _recordingId = null);

  void _showMessages(String id, List<_Message> messages) => setState(() {
    _messageId = id;
    _messages = messages;
  });

  // Returns handled for every key while recording, so the app's own
  // shortcuts (bound above this widget) never see the keys being recorded.
  KeyEventResult _onRecordKey(FocusNode node, KeyEvent event) {
    final id = _recordingId;
    if (id == null) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (_modifierKeys.contains(key)) return KeyEventResult.handled;
    final keyboard = HardwareKeyboard.instance;
    final candidate = SingleActivator(
      key,
      control: keyboard.isControlPressed,
      shift: keyboard.isShiftPressed,
      alt: keyboard.isAltPressed,
      meta: keyboard.isMetaPressed,
    );
    final noModifier =
        !candidate.control &&
        !candidate.shift &&
        !candidate.alt &&
        !candidate.meta;
    if (key == LogicalKeyboardKey.escape && noModifier) {
      _stopRecording();
      _showMessages(id, const []);
      return KeyEventResult.handled;
    }
    final loc = AppLocalizations.of(context);
    final refusal = AppShortcuts.refusalFor(id, candidate);
    if (refusal != null) {
      _showMessages(id, [(text: _refusalText(loc, refusal), warn: true)]);
      return KeyEventResult.handled;
    }
    final binding = _byId(id);
    // Pressing a default again means "no custom shortcut": both the Ctrl and
    // the Cmd twin come back, and later default changes still apply.
    final isDefault = binding.activators.any((a) => _sameCombo(a, candidate));
    _stopRecording();
    // A restore brings back every default (the Ctrl and the Cmd twin), so all
    // of them are checked for clashes, as the Restore button does.
    _assign(
      id,
      isDefault ? binding.activators : [candidate],
      restore: isDefault,
    );
    return KeyEventResult.handled;
  }

  /// Gives [keys] to [id] (its defaults when [restore]). Every row that would
  /// see the same key at the same time is left with no keys, because
  /// CallbackShortcuts would otherwise run both actions.
  Future<void> _assign(
    String id,
    List<ShortcutActivator> keys, {
    required bool restore,
  }) async {
    final loc = AppLocalizations.of(context);
    final notifier = ref.read(settingsProvider.notifier);
    final keyCombos = keys.whereType<SingleActivator>();
    final clashes = {
      for (final k in keyCombos) ...AppShortcuts.clashesWith(id, k),
    };
    final overlaps = {
      for (final k in keyCombos) ...AppShortcuts.overlapsWith(id, k),
    }..removeAll(clashes);
    final section = _byId(id).section;
    _showMessages(id, [
      for (final other in clashes)
        (text: loc.shortcutReplaced(loc.t(_byId(other).label)), warn: true),
      for (final other in overlaps)
        (
          text: _overlapText(loc, _byId(id), _byId(other), section),
          warn: false,
        ),
    ]);
    for (final other in clashes) {
      await notifier.setShortcutOverride(other, null);
    }
    if (restore) {
      await notifier.clearShortcutOverride(id);
    } else {
      await notifier.setShortcutOverride(id, keyCombos.single);
    }
  }

  String _overlapText(
    AppLocalizations loc,
    ShortcutBinding self,
    ShortcutBinding other,
    ShortcutSection section,
  ) {
    final inPlace = section.isAppWide ? other : self;
    return loc.shortcutSharedWith(
      loc.t(other.label),
      _sectionWhere(loc, inPlace.section),
      loc.t(inPlace.label),
    );
  }

  static ShortcutBinding _byId(String id) =>
      AppShortcuts.shortcutCatalog.firstWhere((b) => b.id == id);

  static bool _sameCombo(ShortcutActivator a, SingleActivator b) =>
      a is SingleActivator &&
      a.trigger == b.trigger &&
      a.control == b.control &&
      a.shift == b.shift &&
      a.alt == b.alt &&
      a.meta == b.meta;

  String _refusalText(AppLocalizations loc, String refusal) {
    if (refusal == AppShortcuts.refusalUiKey) return loc.shortcutUiKey;
    if (refusal == AppShortcuts.refusalNeedsModifier) {
      return loc.shortcutNeedsModifier;
    }
    return loc.shortcutReserved;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final overrides = ref.watch(
      settingsProvider.select((s) => s.shortcutOverrides),
    );
    final notifier = ref.read(settingsProvider.notifier);

    // Per section: a hit on the section's title keeps all its rows, otherwise
    // only the rows whose name matches. Sections left empty are dropped.
    final query = _fold(_search.text.trim());
    final visible = <ShortcutSection, List<ShortcutBinding>>{};
    for (final section in ShortcutSection.values) {
      final titleHit =
          query.isEmpty || _fold(_sectionTitle(loc, section)).contains(query);
      final rows = [
        for (final b in AppShortcuts.shortcutCatalog)
          if (b.section == section &&
              (titleHit || _fold(loc.t(b.label)).contains(query)))
            b,
      ];
      if (rows.isNotEmpty) visible[section] = rows;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.md,
        AppDimensions.marginMobile,
        120,
      ),
      children: [
        Text(
          loc.keyboardShortcuts,
          style: AppTypography.headlineLarge.copyWith(color: colors.onSurface),
        ),
        const SizedBox(height: AppDimensions.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                loc.keyboardShortcutsDesc,
                style: AppTypography.labelMedium.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.restart_alt, size: 18),
              label: Text(loc.restoreAllDefaults),
              onPressed: overrides.isEmpty
                  ? null
                  : notifier.resetShortcutOverrides,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.sm),
          child: TextField(
            key: const ValueKey('shortcut-search'),
            controller: _search,
            style: searchBoxTextStyle(context),
            decoration: searchBoxDecoration(
              context,
              hintText: loc.searchShortcuts,
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: _search.clear,
                    ),
            ),
          ),
        ),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.lg),
            child: Center(
              child: Text(
                loc.noResults,
                style: AppTypography.labelMedium.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        for (final entry in visible.entries) ...[
          const SizedBox(height: AppDimensions.lg),
          _SectionHeader(
            section: entry.key,
            loc: loc,
            colors: colors,
            query: query,
          ),
          const SizedBox(height: AppDimensions.sm),
          _SectionCard(
            colors: colors,
            children: [
              for (final binding in entry.value)
                _ShortcutRow(
                  binding: binding,
                  loc: loc,
                  colors: colors,
                  query: query,
                  isCustom: overrides.containsKey(binding.id),
                  recording: _recordingId == binding.id
                      ? _Recorder(
                          prompt: loc.pressNewShortcut,
                          colors: colors,
                          onKeyEvent: _onRecordKey,
                          onCancel: _stopRecording,
                        )
                      : null,
                  messages: _messageId == binding.id ? _messages : const [],
                  onChange: () => _startRecording(binding.id),
                  onRestore: () =>
                      _assign(binding.id, binding.activators, restore: true),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One line under a row: a refusal or a replaced row ([warn]), or a note
/// about a key it shares.
typedef _Message = ({String text, bool warn});

/// Where a section's keys work, e.g. "When the results list has focus".
String _sectionWhere(AppLocalizations loc, ShortcutSection section) =>
    switch (section) {
      ShortcutSection.reader => loc.shortcutsReaderWhere,
      ShortcutSection.searchResults => loc.shortcutsSearchResultsWhere,
      ShortcutSection.chat => loc.shortcutsChatWhere,
      _ => loc.shortcutsAnywhere,
    };

String _sectionTitle(AppLocalizations loc, ShortcutSection section) =>
    switch (section) {
      ShortcutSection.sidebar => loc.shortcutsSidebar,
      ShortcutSection.reading => loc.shortcutsReading,
      ShortcutSection.tabs => loc.shortcutsTabs,
      ShortcutSection.textDisplay => loc.shortcutsTextDisplay,
      ShortcutSection.dictionary => loc.shortcutsDictionary,
      ShortcutSection.app => loc.shortcutsApp,
      ShortcutSection.reader => loc.shortcutsReader,
      ShortcutSection.searchResults => loc.shortcutsSearchResults,
      ShortcutSection.chat => loc.shortcutsChat,
    };

const _plainLetters = {
  'ā': 'a', 'ī': 'i', 'ū': 'u', 'ṃ': 'm', 'ṁ': 'm', 'ṅ': 'n', 'ñ': 'n',
  'ṭ': 't', 'ḍ': 'd', 'ṇ': 'n', 'ḷ': 'l',
};

/// Lower-cases [text] and drops Pāli marks, one character for one character,
/// so a match position in the folded text is the same in the original.
String _fold(String text) {
  final out = StringBuffer();
  for (final unit in text.split('')) {
    final lower = unit.toLowerCase();
    out.write(lower.length == 1 ? (_plainLetters[lower] ?? lower) : unit);
  }
  return out.toString();
}

/// [text] with the first match of the already-folded [query] marked.
Widget _highlighted(
  String text,
  String query,
  TextStyle style,
  ColorScheme colors,
) {
  final at = query.isEmpty ? -1 : _fold(text).indexOf(query);
  if (at < 0) return Text(text, style: style);
  final end = at + query.length;
  return Text.rich(
    TextSpan(
      style: style,
      children: [
        TextSpan(text: text.substring(0, at)),
        TextSpan(
          text: text.substring(at, end),
          style: TextStyle(
            backgroundColor: colors.primaryContainer,
            color: colors.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextSpan(text: text.substring(end)),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final ShortcutSection section;
  final AppLocalizations loc;
  final ColorScheme colors;
  final String query;

  const _SectionHeader({
    required this.section,
    required this.loc,
    required this.colors,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final where = _sectionWhere(loc, section);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _highlighted(
          _sectionTitle(loc, section),
          query,
          AppTypography.labelMedium.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w600,
          ),
          colors,
        ),
        Text(
          where,
          style: AppTypography.labelSmall.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final ColorScheme colors;
  final List<Widget> children;

  const _SectionCard({required this.colors, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: colors.outlineVariant,
                indent: AppDimensions.md,
                endIndent: AppDimensions.md,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final ShortcutBinding binding;
  final AppLocalizations loc;
  final ColorScheme colors;
  final String query;
  final bool isCustom;

  /// Shown in place of the key cap while this row records.
  final Widget? recording;

  /// Lines shown under the row (see [_Message]).
  final List<_Message> messages;
  final VoidCallback onChange;
  final VoidCallback onRestore;

  const _ShortcutRow({
    required this.binding,
    required this.loc,
    required this.colors,
    required this.query,
    required this.isCustom,
    required this.recording,
    required this.messages,
    required this.onChange,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final fixedHint = binding.fixedHint;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(fixedHint),
          for (final message in messages) _messageLine(message),
        ],
      ),
    );
  }

  Widget _messageLine(_Message message) {
    final color = message.warn ? colors.error : colors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              message.warn ? Icons.warning_amber_rounded : Icons.info_outline,
              size: 14,
              color: color,
            ),
          ),
          const SizedBox(width: AppDimensions.xs),
          Expanded(
            child: Text(
              message.text,
              style: AppTypography.labelSmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  String _hint() {
    final hint = AppShortcuts.hintFor(binding.id) ?? '';
    return hint.isEmpty ? loc.shortcutNone : hint;
  }

  Widget _row(String? fixedHint) {
    return Row(
      children: [
        Expanded(
          child: _highlighted(
            loc.t(binding.label),
            query,
            AppTypography.labelMedium.copyWith(color: colors.onSurface),
            colors,
          ),
        ),
        if (fixedHint != null)
          Padding(
            padding: const EdgeInsets.only(right: AppDimensions.sm),
            child: Text(
              loc.shortcutAlso(fixedHint),
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        if (recording != null)
          Flexible(child: recording!)
        else
          InkWell(
            key: ValueKey('keycap-${binding.id}'),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            onTap: onChange,
            child: _Kbd(_hint(), colors),
          ),
        const SizedBox(width: AppDimensions.xs),
        IconButton(
          key: ValueKey('change-${binding.id}'),
          tooltip: loc.changeShortcut,
          icon: const Icon(Icons.edit_outlined, size: 18),
          onPressed: onChange,
        ),
        if (isCustom)
          IconButton(
            key: ValueKey('restore-${binding.id}'),
            tooltip: loc.restoreDefault,
            icon: const Icon(Icons.restart_alt, size: 18),
            onPressed: onRestore,
          ),
      ],
    );
  }
}

/// The key cell of the row that is recording. It holds the keyboard focus
/// and swallows every key until a combination is accepted or cancelled.
class _Recorder extends StatelessWidget {
  final String prompt;
  final ColorScheme colors;
  final FocusOnKeyEventCallback onKeyEvent;
  final VoidCallback onCancel;

  const _Recorder({
    required this.prompt,
    required this.colors,
    required this.onKeyEvent,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) => onCancel(),
      child: Focus(
        autofocus: true,
        onKeyEvent: onKeyEvent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(color: colors.primary),
          ),
          child: Text(
            prompt,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// The key-cap look of a shortcut's keys.
class _Kbd extends StatelessWidget {
  final String text;
  final ColorScheme colors;

  const _Kbd(this.text, this.colors);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall.copyWith(
          color: colors.onSurfaceVariant,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
