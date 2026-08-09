import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/utils/responsive_breakpoint.dart';
import '../../features/dictionary/widgets/dictionary_sheet.dart';
import '../../features/library/widgets/library_dialog.dart';
import '../../features/reader/providers/reader_tabs_provider.dart';
import '../../features/settings/widgets/settings_dialog.dart';
import '../../shared/providers/side_panel_provider.dart';

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

    return [
      AppAction(
        label: 'Find in Book',
        activators: const [
          SingleActivator(LogicalKeyboardKey.keyF, control: true),
          SingleActivator(LogicalKeyboardKey.keyF, meta: true),
        ],
        macActivator: const SingleActivator(
          LogicalKeyboardKey.keyF,
          meta: true,
        ),
        invoke: toggleInBookSearch,
      ),
      AppAction(
        label: 'Find Everywhere',
        activators: const [
          SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true),
          SingleActivator(LogicalKeyboardKey.keyF, meta: true, shift: true),
        ],
        macActivator: const SingleActivator(
          LogicalKeyboardKey.keyF,
          meta: true,
          shift: true,
        ),
        invoke: openGlobalSearch,
      ),
      AppAction(
        label: 'Close Tab',
        activators: const [
          SingleActivator(LogicalKeyboardKey.keyW, control: true),
          SingleActivator(LogicalKeyboardKey.keyW, meta: true),
        ],
        macActivator: const SingleActivator(
          LogicalKeyboardKey.keyW,
          meta: true,
        ),
        invoke: closeFocusTab,
      ),
      AppAction(
        label: 'Close All Tabs',
        activators: const [
          SingleActivator(LogicalKeyboardKey.keyW, control: true, shift: true),
          SingleActivator(LogicalKeyboardKey.keyW, meta: true, shift: true),
        ],
        macActivator: const SingleActivator(
          LogicalKeyboardKey.keyW,
          meta: true,
          shift: true,
        ),
        invoke: closeAllTabs,
      ),
      AppAction(
        label: 'Dictionary',
        activators: const [
          SingleActivator(LogicalKeyboardKey.keyD, control: true),
          SingleActivator(LogicalKeyboardKey.keyD, meta: true),
        ],
        macActivator: const SingleActivator(
          LogicalKeyboardKey.keyD,
          meta: true,
        ),
        invoke: openDictionary,
      ),
      AppAction(
        label: 'Library',
        activators: const [
          SingleActivator(LogicalKeyboardKey.keyN, control: true),
          SingleActivator(LogicalKeyboardKey.keyN, meta: true),
        ],
        macActivator: const SingleActivator(
          LogicalKeyboardKey.keyN,
          meta: true,
        ),
        invoke: openLibrary,
      ),
      AppAction(
        label: 'Settings…',
        activators: const [
          SingleActivator(LogicalKeyboardKey.comma, control: true),
          SingleActivator(LogicalKeyboardKey.comma, meta: true),
        ],
        macActivator: const SingleActivator(
          LogicalKeyboardKey.comma,
          meta: true,
        ),
        invoke: openSettings,
      ),
      AppAction(
        label: 'Increase Font Size',
        activators: const [
          SingleActivator(LogicalKeyboardKey.equal, control: true),
          SingleActivator(LogicalKeyboardKey.equal, meta: true),
          SingleActivator(LogicalKeyboardKey.add, control: true),
          SingleActivator(LogicalKeyboardKey.add, meta: true),
        ],
        macActivator: const SingleActivator(
          LogicalKeyboardKey.equal,
          meta: true,
        ),
        invoke: increaseFont,
      ),
      AppAction(
        label: 'Decrease Font Size',
        activators: const [
          SingleActivator(LogicalKeyboardKey.minus, control: true),
          SingleActivator(LogicalKeyboardKey.minus, meta: true),
        ],
        macActivator: const SingleActivator(
          LogicalKeyboardKey.minus,
          meta: true,
        ),
        invoke: decreaseFont,
      ),
      // Tab shortcuts — no macActivator needed since Tab/digits aren't
      // macOS system-menu keys, and we don't want them in the Edit menu.
      AppAction(
        label: 'Switch to Tab 1',
        activators: const [
          SingleActivator(LogicalKeyboardKey.digit1, control: true),
          SingleActivator(LogicalKeyboardKey.digit1, meta: true),
        ],
        invoke: () => switchToTab(0),
      ),
      AppAction(
        label: 'Switch to Tab 2',
        activators: const [
          SingleActivator(LogicalKeyboardKey.digit2, control: true),
          SingleActivator(LogicalKeyboardKey.digit2, meta: true),
        ],
        invoke: () => switchToTab(1),
      ),
      AppAction(
        label: 'Switch to Tab 3',
        activators: const [
          SingleActivator(LogicalKeyboardKey.digit3, control: true),
          SingleActivator(LogicalKeyboardKey.digit3, meta: true),
        ],
        invoke: () => switchToTab(2),
      ),
      AppAction(
        label: 'Switch to Tab 4',
        activators: const [
          SingleActivator(LogicalKeyboardKey.digit4, control: true),
          SingleActivator(LogicalKeyboardKey.digit4, meta: true),
        ],
        invoke: () => switchToTab(3),
      ),
      AppAction(
        label: 'Switch to Tab 5',
        activators: const [
          SingleActivator(LogicalKeyboardKey.digit5, control: true),
          SingleActivator(LogicalKeyboardKey.digit5, meta: true),
        ],
        invoke: () => switchToTab(4),
      ),
      AppAction(
        label: 'Switch to Tab 6',
        activators: const [
          SingleActivator(LogicalKeyboardKey.digit6, control: true),
          SingleActivator(LogicalKeyboardKey.digit6, meta: true),
        ],
        invoke: () => switchToTab(5),
      ),
      AppAction(
        label: 'Switch to Tab 7',
        activators: const [
          SingleActivator(LogicalKeyboardKey.digit7, control: true),
          SingleActivator(LogicalKeyboardKey.digit7, meta: true),
        ],
        invoke: () => switchToTab(6),
      ),
      AppAction(
        label: 'Switch to Tab 8',
        activators: const [
          SingleActivator(LogicalKeyboardKey.digit8, control: true),
          SingleActivator(LogicalKeyboardKey.digit8, meta: true),
        ],
        invoke: () => switchToTab(7),
      ),
      AppAction(
        label: 'Switch to Tab 9',
        activators: const [
          SingleActivator(LogicalKeyboardKey.digit9, control: true),
          SingleActivator(LogicalKeyboardKey.digit9, meta: true),
        ],
        invoke: () => switchToTab(8),
      ),
      AppAction(
        label: 'Next Tab',
        activators: const [
          SingleActivator(LogicalKeyboardKey.tab, control: true),
        ],
        invoke: nextTab,
      ),
      AppAction(
        label: 'Previous Tab',
        activators: const [
          SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true),
        ],
        invoke: previousTab,
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
