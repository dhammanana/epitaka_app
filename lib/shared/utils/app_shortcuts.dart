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

/// Centralized keyboard shortcuts for ePitaka.
///
/// These are wired at the app level via [AppShortcuts] so they work from
/// anywhere (reader, library, dialogs). Each binding is a [SingleActivator]
/// that matches Ctrl (Linux/Windows) or Cmd (macOS).
class AppShortcuts {
  AppShortcuts._();

  /// Build the [CallbackShortcuts] bindings map for the given [context].
  ///
  /// [context] is needed for router navigation and dialog helpers. The
  /// returned map can be spread into a [CallbackShortcuts.bindings].
  static Map<ShortcutActivator, VoidCallback> bindings(
    BuildContext context,
    WidgetRef ref,
  ) {
    final isDesktop = ResponsiveBreakpoint.isDesktop(context);

    void openLibrary() {
      if (isDesktop) {
        showLibraryDialog(context);
      } else {
        context.go('/');
      }
    }

    void openSettings() {
      if (isDesktop) {
        showSettingsDialog(context);
      } else {
        context.push('/settings');
      }
    }

    void openGlobalSearch() {
      if (isDesktop) {
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
      // Toggle: if the dictionary panel/sheet is already open, close it;
      // otherwise open it and focus its search field.
      if (isDesktop) {
        final sidePanels = ref.read(sidePanelProvider);
        if (sidePanels.right.openPanel == SidePanelType.dictionary) {
          ref.read(sidePanelProvider.notifier).close(SidePanelType.dictionary);
        } else {
          ref
              .read(sidePanelProvider.notifier)
              .open(SidePanelType.dictionary, data: '', autoFocus: true);
        }
      } else {
        // On mobile the dictionary is a bottom sheet; re-opening the same
        // word is a no-op, so just open it.
        showDictionarySheet(context, '');
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

    return {
      // In-book search (only meaningful when a book is open).
      SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
        // Delegate to the reader's in-book search toggle if a book is open.
        final tabs = ref.read(readerTabsProvider);
        if (tabs.isNotEmpty) {
          // Flip the provider the reader screen watches and reacts to.
          ref.read(inBookSearchToggleProvider.notifier).toggle();
        }
      },
      SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
        final tabs = ref.read(readerTabsProvider);
        if (tabs.isNotEmpty) {
          ref.read(inBookSearchToggleProvider.notifier).toggle();
        }
      },
      // Global search.
      SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true):
          openGlobalSearch,
      SingleActivator(LogicalKeyboardKey.keyF, meta: true, shift: true):
          openGlobalSearch,
      // Close focus tab.
      SingleActivator(LogicalKeyboardKey.keyW, control: true): closeFocusTab,
      SingleActivator(LogicalKeyboardKey.keyW, meta: true): closeFocusTab,
      // Close all tabs.
      SingleActivator(LogicalKeyboardKey.keyW, control: true, shift: true):
          closeAllTabs,
      SingleActivator(LogicalKeyboardKey.keyW, meta: true, shift: true):
          closeAllTabs,
      // Open dictionary (and focus search).
      SingleActivator(LogicalKeyboardKey.keyD, control: true): openDictionary,
      SingleActivator(LogicalKeyboardKey.keyD, meta: true): openDictionary,
      // Open library.
      SingleActivator(LogicalKeyboardKey.keyN, control: true): openLibrary,
      SingleActivator(LogicalKeyboardKey.keyN, meta: true): openLibrary,
      // Open settings.
      SingleActivator(LogicalKeyboardKey.comma, control: true): openSettings,
      SingleActivator(LogicalKeyboardKey.comma, meta: true): openSettings,
      // Increase / decrease font size.
      SingleActivator(LogicalKeyboardKey.equal, control: true): increaseFont,
      SingleActivator(LogicalKeyboardKey.equal, meta: true): increaseFont,
      SingleActivator(LogicalKeyboardKey.add, control: true): increaseFont,
      SingleActivator(LogicalKeyboardKey.add, meta: true): increaseFont,
      SingleActivator(LogicalKeyboardKey.minus, control: true): decreaseFont,
      SingleActivator(LogicalKeyboardKey.minus, meta: true): decreaseFont,
    };
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
