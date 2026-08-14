import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/utils/responsive_breakpoint.dart';
import '../../router/app_router.dart' show AppRoutes;
import '../../features/dictionary/widgets/dictionary_sheet.dart';
import '../../features/library/widgets/library_dialog.dart';
import '../../features/reader/providers/reader_action_controller.dart';
import '../../features/reader/providers/reader_keyboard_bridge.dart';
import '../../features/reader/providers/reader_provider.dart';
import '../../features/reader/providers/reader_tabs_provider.dart';
import '../../features/settings/widgets/settings_dialog.dart';
import '../../shared/providers/side_panel_provider.dart';
import '../../shared/providers/vimamsa_panel_provider.dart';

/// True on a native macOS build (never true on web or other platforms).
bool get _isMacOS => !kIsWeb && Platform.isMacOS;

/// One logical shortcut: an action plus every [ShortcutActivator] that
/// should trigger it (usually a Ctrl and a Cmd variant), a label for menus,
/// and the single activator macOS should display in its native menu bar.
class AppAction {
  const AppAction({
    required this.label,
    required this.activators,
    required this.invoke,
    this.macActivator,
  });

  /// Human-readable label, e.g. "Find in Book". Shown in the menu bar.
  final String label;

  /// All activators that should trigger this action via [CallbackShortcuts].
  final List<ShortcutActivator> activators;

  /// The action itself.
  final VoidCallback invoke;

  /// The activator to display against [label] in the native macOS menu.
  /// If non-null, this activator is deliberately *excluded* from the
  /// [CallbackShortcuts] bindings on macOS (see [AppShortcuts.bindings]),
  /// because the native menu bar already delivers it — registering it in
  /// both places causes the action to fire twice on macOS.
  final SingleActivator? macActivator;
}

/// A global shortcut described as pure data — the keys that trigger it and
/// the label shown for it. The catalog ([AppShortcuts.shortcutCatalog]) is
/// the single source of truth for both the live key bindings (registered
/// via [AppShortcuts.bindings] and the macOS menu bar) and the hints
/// appended to tooltips ([AppShortcuts.hintFor] / [AppShortcuts.tooltip]).
class ShortcutBinding {
  const ShortcutBinding({
    required this.id,
    required this.label,
    required this.activators,
    this.macActivator,
  });

  /// Stable, unique identifier used to look the shortcut up from tooltips
  /// (e.g. `'library-sidebar'`). Two shortcuts may share a display [label]
  /// (both the `N` and `L` bindings are called "Library"), but ids never
  /// collide.
  final String id;

  /// Human-readable label, e.g. "Find in Book". Shown in the macOS menu
  /// bar and used as the base of tooltip hints.
  final String label;

  /// Every activator that triggers this shortcut via [CallbackShortcuts].
  final List<ShortcutActivator> activators;

  /// The activator to display in the native macOS menu (see
  /// [AppAction.macActivator]).
  final SingleActivator? macActivator;
}

/// Centralized keyboard shortcuts for ePitaka.
///
/// These are wired at the app level so they work from anywhere (reader,
/// library, dialogs), via two complementary mechanisms:
///
/// - [bindings] feeds a [CallbackShortcuts] widget and handles the key
///   press directly on every platform (and, on macOS, still handles the
///   Ctrl-variants and any action with no [AppAction.macActivator]).
/// - [menuBar] wraps the app in a native [PlatformMenuBar] on macOS only,
///   so shortcuts are visible in the system menu bar and macOS's own
///   default bindings (e.g. Cmd+F for "Find…") no longer swallow ours.
///   On other platforms it's a no-op passthrough.
///
/// Actions that navigate or show dialogs need a [BuildContext] that sits
/// *under* [MaterialApp] (for `Localizations`) and under the [GoRouter]
/// (for `context.go`/`context.push`). The context available where this
/// class is wired up (in `app.dart`, above `MaterialApp.router`) does not
/// satisfy that. So instead of capturing a context up front, every action
/// resolves a fresh context from [navigatorKey] at the moment it runs, via
/// [_ctx]. Always pass the same [GlobalKey<NavigatorState>] that's attached
/// to your `GoRouter`/`MaterialApp.router` (see `app.dart`).
class AppShortcuts {
  AppShortcuts._();

  static BuildContext _ctx(GlobalKey<NavigatorState> navigatorKey) {
    final context = navigatorKey.currentContext;
    assert(
      context != null,
      'AppShortcuts: navigatorKey has no attached context yet. '
      'Make sure the key is passed to GoRouter/MaterialApp.router.',
    );
    return context!;
  }

  /// Every global shortcut as pure data. This is the single source of
  /// truth used both by [_actions] (which attaches each entry to its action
  /// for [bindings] and the macOS [menuBar]) and by [hintFor] / [tooltip]
  /// (which render the shortcut next to tooltips). Keep key assignments in
  /// here — never hardcode them elsewhere.
  static const List<ShortcutBinding> shortcutCatalog = [
    ShortcutBinding(
      id: 'find-in-book',
      label: 'Find in Book',
      activators: [
        SingleActivator(LogicalKeyboardKey.keyF, control: true),
        SingleActivator(LogicalKeyboardKey.keyF, meta: true),
      ],
      macActivator: SingleActivator(LogicalKeyboardKey.keyF, meta: true),
    ),
    ShortcutBinding(
      id: 'find-everywhere',
      label: 'Find Everywhere',
      activators: [
        SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true),
        SingleActivator(LogicalKeyboardKey.keyF, meta: true, shift: true),
      ],
      macActivator: SingleActivator(
        LogicalKeyboardKey.keyF,
        meta: true,
        shift: true,
      ),
    ),
    ShortcutBinding(
      id: 'close-tab',
      label: 'Close Tab',
      activators: [
        SingleActivator(LogicalKeyboardKey.keyW, control: true),
        SingleActivator(LogicalKeyboardKey.keyW, meta: true),
      ],
      macActivator: SingleActivator(LogicalKeyboardKey.keyW, meta: true),
    ),
    ShortcutBinding(
      id: 'close-all-tabs',
      label: 'Close All Tabs',
      activators: [
        SingleActivator(LogicalKeyboardKey.keyW, control: true, shift: true),
        SingleActivator(LogicalKeyboardKey.keyW, meta: true, shift: true),
      ],
      macActivator: SingleActivator(
        LogicalKeyboardKey.keyW,
        meta: true,
        shift: true,
      ),
    ),
    ShortcutBinding(
      id: 'dictionary',
      label: 'Dictionary',
      activators: [
        SingleActivator(LogicalKeyboardKey.keyD, control: true),
        SingleActivator(LogicalKeyboardKey.keyD, meta: true),
      ],
      macActivator: SingleActivator(LogicalKeyboardKey.keyD, meta: true),
    ),
    ShortcutBinding(
      id: 'library-open',
      label: 'Library',
      activators: [
        SingleActivator(LogicalKeyboardKey.keyN, control: true),
        SingleActivator(LogicalKeyboardKey.keyN, meta: true),
      ],
      macActivator: SingleActivator(LogicalKeyboardKey.keyN, meta: true),
    ),
    ShortcutBinding(
      id: 'settings',
      label: 'Settings…',
      activators: [
        SingleActivator(LogicalKeyboardKey.comma, control: true),
        SingleActivator(LogicalKeyboardKey.comma, meta: true),
      ],
      macActivator: SingleActivator(LogicalKeyboardKey.comma, meta: true),
    ),
    ShortcutBinding(
      id: 'font-increase',
      label: 'Increase Font Size',
      activators: [
        SingleActivator(LogicalKeyboardKey.equal, control: true),
        SingleActivator(LogicalKeyboardKey.equal, meta: true),
        SingleActivator(LogicalKeyboardKey.add, control: true),
        SingleActivator(LogicalKeyboardKey.add, meta: true),
      ],
      macActivator: SingleActivator(LogicalKeyboardKey.equal, meta: true),
    ),
    ShortcutBinding(
      id: 'font-decrease',
      label: 'Decrease Font Size',
      activators: [
        SingleActivator(LogicalKeyboardKey.minus, control: true),
        SingleActivator(LogicalKeyboardKey.minus, meta: true),
      ],
      macActivator: SingleActivator(LogicalKeyboardKey.minus, meta: true),
    ),
    // Tab shortcuts — no macActivator needed since Tab/digits aren't
    // macOS system-menu keys, and we don't want them in the Edit menu.
    ShortcutBinding(
      id: 'tab-1',
      label: 'Switch to Tab 1',
      activators: [
        SingleActivator(LogicalKeyboardKey.digit1, control: true),
        SingleActivator(LogicalKeyboardKey.digit1, meta: true),
      ],
    ),
    ShortcutBinding(
      id: 'tab-2',
      label: 'Switch to Tab 2',
      activators: [
        SingleActivator(LogicalKeyboardKey.digit2, control: true),
        SingleActivator(LogicalKeyboardKey.digit2, meta: true),
      ],
    ),
    ShortcutBinding(
      id: 'tab-3',
      label: 'Switch to Tab 3',
      activators: [
        SingleActivator(LogicalKeyboardKey.digit3, control: true),
        SingleActivator(LogicalKeyboardKey.digit3, meta: true),
      ],
    ),
    ShortcutBinding(
      id: 'tab-4',
      label: 'Switch to Tab 4',
      activators: [
        SingleActivator(LogicalKeyboardKey.digit4, control: true),
        SingleActivator(LogicalKeyboardKey.digit4, meta: true),
      ],
    ),
    ShortcutBinding(
      id: 'tab-5',
      label: 'Switch to Tab 5',
      activators: [
        SingleActivator(LogicalKeyboardKey.digit5, control: true),
        SingleActivator(LogicalKeyboardKey.digit5, meta: true),
      ],
    ),
    ShortcutBinding(
      id: 'tab-6',
      label: 'Switch to Tab 6',
      activators: [
        SingleActivator(LogicalKeyboardKey.digit6, control: true),
        SingleActivator(LogicalKeyboardKey.digit6, meta: true),
      ],
    ),
    ShortcutBinding(
      id: 'tab-7',
      label: 'Switch to Tab 7',
      activators: [
        SingleActivator(LogicalKeyboardKey.digit7, control: true),
        SingleActivator(LogicalKeyboardKey.digit7, meta: true),
      ],
    ),
    ShortcutBinding(
      id: 'tab-8',
      label: 'Switch to Tab 8',
      activators: [
        SingleActivator(LogicalKeyboardKey.digit8, control: true),
        SingleActivator(LogicalKeyboardKey.digit8, meta: true),
      ],
    ),
    ShortcutBinding(
      id: 'tab-9',
      label: 'Switch to Tab 9',
      activators: [
        SingleActivator(LogicalKeyboardKey.digit9, control: true),
        SingleActivator(LogicalKeyboardKey.digit9, meta: true),
      ],
    ),
    ShortcutBinding(
      id: 'tab-next',
      label: 'Next Tab',
      activators: [
        SingleActivator(LogicalKeyboardKey.tab, control: true),
      ],
    ),
    ShortcutBinding(
      id: 'tab-prev',
      label: 'Previous Tab',
      activators: [
        SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true),
      ],
    ),
    // ── Library / panels ─────────────────────────────────────────
    ShortcutBinding(
      id: 'library-sidebar',
      label: 'Library',
      activators: [
        SingleActivator(LogicalKeyboardKey.keyL, control: true),
        SingleActivator(LogicalKeyboardKey.keyL, meta: true),
      ],
      macActivator: SingleActivator(LogicalKeyboardKey.keyL, meta: true),
    ),
    ShortcutBinding(
      id: 'annotations',
      label: 'Annotations',
      activators: [
        SingleActivator(LogicalKeyboardKey.keyB, control: true),
        SingleActivator(LogicalKeyboardKey.keyB, meta: true),
      ],
      macActivator: SingleActivator(LogicalKeyboardKey.keyB, meta: true),
    ),
    ShortcutBinding(
      id: 'history',
      label: 'History',
      activators: [
        SingleActivator(LogicalKeyboardKey.keyY, control: true),
        SingleActivator(LogicalKeyboardKey.keyY, meta: true),
      ],
      macActivator: SingleActivator(LogicalKeyboardKey.keyY, meta: true),
    ),
    ShortcutBinding(
      id: 'contents',
      label: 'Contents',
      activators: [
        SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true),
        SingleActivator(LogicalKeyboardKey.keyC, meta: true, shift: true),
      ],
      macActivator: SingleActivator(
        LogicalKeyboardKey.keyC,
        meta: true,
        shift: true,
      ),
    ),
    ShortcutBinding(
      id: 'vimamsa',
      label: 'Vimaṃsa',
      activators: [
        SingleActivator(LogicalKeyboardKey.keyV, control: true, shift: true),
        SingleActivator(LogicalKeyboardKey.keyV, meta: true, shift: true),
      ],
      macActivator: SingleActivator(
        LogicalKeyboardKey.keyV,
        meta: true,
        shift: true,
      ),
    ),
    ShortcutBinding(
      id: 'jump',
      label: 'Jump to Page…',
      activators: [
        SingleActivator(LogicalKeyboardKey.keyJ, control: true),
        SingleActivator(LogicalKeyboardKey.keyJ, meta: true),
      ],
      macActivator: SingleActivator(LogicalKeyboardKey.keyJ, meta: true),
    ),
    // ── Display modes (⌥⌘/Ctrl+Alt — not in the macOS Edit menu) ─
    ShortcutBinding(
      id: 'display-hide',
      label: 'Hide Translation',
      activators: [
        SingleActivator(LogicalKeyboardKey.digit1, control: true, alt: true),
        SingleActivator(LogicalKeyboardKey.digit1, meta: true, alt: true),
      ],
    ),
    ShortcutBinding(
      id: 'display-line',
      label: 'View Line by Line',
      activators: [
        SingleActivator(LogicalKeyboardKey.digit2, control: true, alt: true),
        SingleActivator(LogicalKeyboardKey.digit2, meta: true, alt: true),
      ],
    ),
    ShortcutBinding(
      id: 'display-side',
      label: 'View Side by Side',
      activators: [
        SingleActivator(LogicalKeyboardKey.digit3, control: true, alt: true),
        SingleActivator(LogicalKeyboardKey.digit3, meta: true, alt: true),
      ],
    ),
  ];

  /// True on a native macOS build — tooltips render ⌘-style hints there
  /// and Ctrl-style elsewhere.
  static bool get isMacOS => _isMacOS;

  /// Render a single [SingleActivator] as a short platform hint, e.g.
  /// "⌘⇧C" on macOS or "Ctrl+Shift+C" elsewhere.
  static String renderShortcut(SingleActivator activator) =>
      _renderActivator(activator);

  /// The platform-appropriate shortcut hint for the catalog entry with
  /// [id] — e.g. `'library-sidebar'` → "⌘L" on macOS, "Ctrl+L" elsewhere.
  /// Returns null when no entry has that id.
  static String? hintFor(String id) {
    for (final binding in shortcutCatalog) {
      if (binding.id == id) return _renderBinding(binding);
    }
    return null;
  }

  /// [label] with the shortcut hint for [id] appended, e.g.
  /// "Contents ⌘⇧C". Returns [label] unchanged when no global shortcut has
  /// that [id] (the action is then reachable by mouse only).
  static String tooltip(String label, String id) {
    final hint = hintFor(id);
    return (hint == null || hint.isEmpty) ? label : '$label $hint';
  }

  static String _renderBinding(ShortcutBinding binding) {
    final activator = _displayActivator(binding);
    if (activator == null) return '';
    return _renderActivator(activator);
  }

  /// The single activator to *display* for [binding] on this platform: the
  /// native-menu activator on macOS, otherwise the first non-⌘ variant (so
  /// hints read "Ctrl+L", never "Ctrl+L or ⌘L").
  static SingleActivator? _displayActivator(ShortcutBinding binding) {
    if (_isMacOS) {
      if (binding.macActivator != null) return binding.macActivator;
      for (final activator in binding.activators) {
        if (activator is SingleActivator && activator.meta) return activator;
      }
      return binding.activators.whereType<SingleActivator>().firstOrNull;
    }
    for (final activator in binding.activators) {
      if (activator is SingleActivator && !activator.meta) return activator;
    }
    return binding.activators.whereType<SingleActivator>().firstOrNull;
  }

  static String _renderActivator(SingleActivator activator) {
    final key = _keyDisplay(activator.trigger);
    if (_isMacOS) {
      return '${activator.control ? '⌃' : ''}'
          '${activator.alt ? '⌥' : ''}'
          '${activator.shift ? '⇧' : ''}'
          '${activator.meta ? '⌘' : ''}'
          '$key';
    }
    final parts = <String>[
      if (activator.control) 'Ctrl',
      if (activator.alt) 'Alt',
      if (activator.shift) 'Shift',
      if (activator.meta) 'Win',
      key,
    ];
    return parts.join('+');
  }

  static String _keyDisplay(LogicalKeyboardKey key) {
    final label = key.keyLabel;
    // Letter keys read better uppercase ("L" not "l").
    if (label.length == 1) {
      final code = label.codeUnitAt(0);
      if (code >= 0x61 && code <= 0x7a) return label.toUpperCase();
    }
    return label;
  }

  /// Build the list of [AppAction]s. Shared source of truth for both
  /// [bindings] and [menuBar]. [navigatorKey] must be the same key attached
  /// to the app's router, so a valid context can be resolved lazily inside
  /// each action (see class doc).
  static List<AppAction> _actions(
    GlobalKey<NavigatorState> navigatorKey,
    WidgetRef ref,
  ) {
    void openLibrary() {
      final context = _ctx(navigatorKey);
      if (ResponsiveBreakpoint.isDesktop(context)) {
        showLibraryDialog(context);
      } else {
        context.go('/');
      }
    }

    void openSettings() {
      final context = _ctx(navigatorKey);
      if (ResponsiveBreakpoint.isDesktop(context)) {
        showSettingsDialog(context);
      } else {
        context.push('/settings');
      }
    }

    void openGlobalSearch() {
      final context = _ctx(navigatorKey);
      if (ResponsiveBreakpoint.isDesktop(context)) {
        // Toggle: if the search panel is already open, close it; otherwise
        // open it and focus the search field.
        final sidePanels = ref.read(sidePanelProvider);
        if (sidePanels.left.openPanel == SidePanelType.search) {
          ref.read(sidePanelProvider.notifier).close(SidePanelType.search);
        } else {
          ref
              .read(sidePanelProvider.notifier)
              .open(SidePanelType.search, autoFocus: true);
        }
      } else {
        context.push('/search');
      }
    }

    void openDictionary() {
      final context = _ctx(navigatorKey);
      if (ResponsiveBreakpoint.isDesktop(context)) {
        // Desktop: toggle the docked sidebar panel / right column.
        final sidePanels = ref.read(sidePanelProvider);
        if (sidePanels.right.openPanel == SidePanelType.dictionary) {
          ref.read(sidePanelProvider.notifier).close(SidePanelType.dictionary);
        } else {
          ref
              .read(sidePanelProvider.notifier)
              .open(SidePanelType.dictionary, data: '', autoFocus: true);
        }
      } else {
        // Mobile: the dictionary is a modal bottom sheet — easy to close
        // with the back button, by pulling it down, or by tapping outside.
        showDictionarySheet(context, '');
      }
    }

    void toggleInBookSearch() {
      debugPrint('[AppShortcuts] toggleInBookSearch invoked');
      final tabs = ref.read(readerTabsProvider);
      debugPrint('[AppShortcuts] readerTabs.isNotEmpty = ${tabs.isNotEmpty}');
      if (tabs.isNotEmpty) {
        ref.read(inBookSearchToggleProvider.notifier).toggle();
        debugPrint('[AppShortcuts] inBookSearchToggleProvider toggled');
      }
    }

    void closeFocusTab() {
      final tabs = ref.read(readerTabsProvider);
      if (tabs.isNotEmpty) {
        ref.read(readerTabsProvider.notifier).closeTab(tabs.activeIndex);
      }
    }

    void closeAllTabs() {
      ref.read(readerTabsProvider.notifier).closeAll();
    }

    void increaseFont() {
      ref.read(settingsProvider.notifier).increaseFontSize();
    }

    void decreaseFont() {
      ref.read(settingsProvider.notifier).decreaseFontSize();
    }

    void switchToTab(int index) {
      ref.read(readerTabsProvider.notifier).switchTo(index);
    }

    void nextTab() {
      ref.read(readerTabsProvider.notifier).nextTab();
    }

    void previousTab() {
      ref.read(readerTabsProvider.notifier).previousTab();
    }

    /// Toggle a sidebar panel (desktop), optionally focusing its input.
    void toggleSidebarPanel(SidePanelType panel, {bool autoFocus = false}) {
      final sidePanels = ref.read(sidePanelProvider);
      if (sidePanels.left.openPanel == panel) {
        ref.read(sidePanelProvider.notifier).close(panel);
      } else {
        ref.read(sidePanelProvider.notifier).open(
          panel,
          autoFocus: autoFocus,
        );
      }
    }

    void toggleLibrary() {
      final context = _ctx(navigatorKey);
      if (ResponsiveBreakpoint.isDesktop(context)) {
        // Open the docked library sidebar and focus its type-to-filter
        // field so the user can type a book name immediately.
        toggleSidebarPanel(SidePanelType.library, autoFocus: true);
      } else {
        context.go(AppRoutes.library);
      }
    }

    void toggleAnnotations() {
      final context = _ctx(navigatorKey);
      if (ResponsiveBreakpoint.isDesktop(context)) {
        toggleSidebarPanel(SidePanelType.annotations);
      } else {
        context.push(AppRoutes.annotations);
      }
    }

    void toggleHistory() {
      final context = _ctx(navigatorKey);
      if (ResponsiveBreakpoint.isDesktop(context)) {
        toggleSidebarPanel(SidePanelType.history);
      } else {
        // History lives inside the library (Reading tab) on mobile.
        context.go(AppRoutes.library);
      }
    }

    void toggleContents() {
      final context = _ctx(navigatorKey);
      if (ResponsiveBreakpoint.isDesktop(context)) {
        toggleSidebarPanel(SidePanelType.contents);
        return;
      }
      // Mobile: open the full-page contents screen for the active book.
      final activeTab = ref.read(readerTabsProvider).activeTab;
      if (activeTab == null) return;
      context.push(
        '/contents/${activeTab.bookId}'
        '?bookName=${Uri.encodeComponent(activeTab.bookName)}'
        '&currentParaId=${activeTab.currentParaId ?? ''}',
      );
    }

    void toggleVimamsa() {
      final context = _ctx(navigatorKey);
      if (ResponsiveBreakpoint.isDesktop(context)) {
        ref.read(vimamsaOpenProvider.notifier).toggle();
      } else {
        context.push(AppRoutes.aiQa);
      }
    }

    void jumpToPage() {
      final activeTab = ref.read(readerTabsProvider).activeTab;
      if (activeTab == null) return;
      final readerState = ref.read(readerDataProvider(activeTab.bookId));
      if (readerState.paragraphs.isEmpty) return;
      final positions = ref
          .read(readerKeyboardBridgeProvider)
          .positionsListenerFor(activeTab.bookId)
          ?.itemPositions
          .value;
      final context = _ctx(navigatorKey);
      ref.read(readerActionControllerProvider).onJumpTap(
            context,
            ref,
            positions,
            activeTab,
            readerState,
          );
    }

    void hideTranslation() {
      ref.read(settingsProvider.notifier).setShowTranslation(false);
    }

    void viewLineByLine() {
      ref.read(settingsProvider.notifier).setShowTranslation(true);
      ref
          .read(settingsProvider.notifier)
          .setTranslationDisplayMode(TranslationDisplayMode.lineByLine);
    }

    void viewSideBySide() {
      ref.read(settingsProvider.notifier).setShowTranslation(true);
      ref
          .read(settingsProvider.notifier)
          .setTranslationDisplayMode(TranslationDisplayMode.sideBySide);
    }

    // Attach each catalog entry to its action. The invokes are keyed by the
    // entry's unique [ShortcutBinding.id], so two entries can share a label
    // (e.g. the N and L library shortcuts).
    final invokes = <String, VoidCallback>{
      'find-in-book': toggleInBookSearch,
      'find-everywhere': openGlobalSearch,
      'close-tab': closeFocusTab,
      'close-all-tabs': closeAllTabs,
      'dictionary': openDictionary,
      'library-open': openLibrary,
      'settings': openSettings,
      'font-increase': increaseFont,
      'font-decrease': decreaseFont,
      'tab-1': () => switchToTab(0),
      'tab-2': () => switchToTab(1),
      'tab-3': () => switchToTab(2),
      'tab-4': () => switchToTab(3),
      'tab-5': () => switchToTab(4),
      'tab-6': () => switchToTab(5),
      'tab-7': () => switchToTab(6),
      'tab-8': () => switchToTab(7),
      'tab-9': () => switchToTab(8),
      'tab-next': nextTab,
      'tab-prev': previousTab,
      'library-sidebar': toggleLibrary,
      'annotations': toggleAnnotations,
      'history': toggleHistory,
      'contents': toggleContents,
      'vimamsa': toggleVimamsa,
      'jump': jumpToPage,
      'display-hide': hideTranslation,
      'display-line': viewLineByLine,
      'display-side': viewSideBySide,
    };
    return [
      for (final binding in shortcutCatalog)
        AppAction(
          label: binding.label,
          activators: binding.activators,
          macActivator: binding.macActivator,
          invoke: invokes[binding.id]!,
        ),
    ];
  }

  /// Build the [CallbackShortcuts] bindings map. [navigatorKey] must be the
  /// same key attached to the app's router (see class doc / [app.dart]).
  ///
  /// On macOS, any activator that equals an action's [AppAction.macActivator]
  /// is deliberately left out here — [menuBar] already delivers it via the
  /// native menu, and registering it in both places makes the action fire
  /// twice for a single key press.
  static Map<ShortcutActivator, VoidCallback> bindings(
    GlobalKey<NavigatorState> navigatorKey,
    WidgetRef ref,
  ) {
    final bindings = <ShortcutActivator, VoidCallback>{};
    for (final action in _actions(navigatorKey, ref)) {
      for (final activator in action.activators) {
        if (_isMacOS && activator == action.macActivator) {
          debugPrint(
            '[AppShortcuts] bindings: skipping ${action.label} '
            '$activator on macOS (handled by menuBar instead)',
          );
          continue;
        }
        bindings[activator] = action.invoke;
      }
    }
    debugPrint(
      '[AppShortcuts] bindings: registered ${bindings.length} activators: '
      '${bindings.keys.toList()}',
    );
    return bindings;
  }

  /// Wrap [child] in a native [PlatformMenuBar] on macOS, listing every
  /// action under an "Edit" menu with its shortcut shown next to it. This
  /// replaces macOS's default menu (the one that owns Cmd+F for "Find…"
  /// via MainMenu.xib / NSTextFinder), so our shortcuts stop getting
  /// swallowed before they reach [CallbackShortcuts].
  ///
  /// On non-macOS platforms this simply returns [child] unchanged —
  /// [PlatformMenuBar] has no native rendering there, and [bindings] alone
  /// already handles the keyboard shortcuts.
  static Widget menuBar({
    required GlobalKey<NavigatorState> navigatorKey,
    required WidgetRef ref,
    required Widget child,
  }) {
    if (!_isMacOS) return child;

    final actions = _actions(navigatorKey, ref);
    debugPrint(
      '[AppShortcuts] menuBar: building Edit menu with '
      '${actions.where((a) => a.macActivator != null).length} items',
    );

    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'Edit',
          menus: [
            for (final action in actions)
              if (action.macActivator != null)
                PlatformMenuItem(
                  label: action.label,
                  shortcut: action.macActivator,
                  onSelected: () {
                    debugPrint(
                      '[AppShortcuts] menuBar: "${action.label}" selected '
                      '(shortcut ${action.macActivator})',
                    );
                    action.invoke();
                  },
                ),
          ],
        ),
      ],
      child: child,
    );
  }
}

/// Helper to toggle the in-book search from a global shortcut.
///
/// The reader screen owns the actual in-book search state, so we expose a
/// lightweight notifier that the reader subscribes to. Toggling here flips a
/// boolean the reader watches and reacts to by calling its own
/// [_toggleInBookSearch].
class InBookSearchNotifier extends StateNotifier<bool> {
  InBookSearchNotifier() : super(false);

  void toggle() => state = !state;
}

/// Provider the reader screen watches to react to the global in-book search
/// shortcut. The reader resets it back to false after handling.
final inBookSearchToggleProvider =
    StateNotifierProvider<InBookSearchNotifier, bool>(
      (ref) => InBookSearchNotifier(),
    );
