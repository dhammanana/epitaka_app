// lib/features/reader/widgets/reader_context_menu_builder.dart
//
// Context-menu wiring for the reader, extracted from reader_screen.dart:
// the SelectionArea contextMenuBuilder (which suppresses the menu while a
// modal sheet is open and routes the AI actions) and the Ctrl/Cmd+C copy
// shortcut handler.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../shared/utils/reading_clipboard.dart' show CopyScope;
import '../../dictionary/providers/dictionary_sheet_open_provider.dart';
import '../providers/reader_provider.dart';
import '../providers/reader_selection_notifier.dart';
import '../providers/reader_tabs_provider.dart';
import '../services/reader_ai_service.dart';
import '../services/reader_copy_service.dart';

/// Builds the reader's text-selection context menu and the copy shortcut.
///
/// Stateless: everything is passed in or read from providers at call time.
class ReaderContextMenuBuilder {
  ReaderContextMenuBuilder._();

  /// The [SelectionArea.contextMenuBuilder] for the reader content.
  ///
  /// Reads selection/tab state from providers at build time (never watches,
  /// so the menu does not rebuild the reader). AI actions route through
  /// [ReaderAiService].
  static Widget build({
    required BuildContext context,
    required WidgetRef ref,
    required SelectableRegionState selectableRegionState,
    required GlobalKey contentHitTestKey,
  }) {
    // While a modal dictionary/book-link sheet is open, SelectionArea builds
    // this menu on the double-tap's pointer-up — a leftover of the tap that
    // already pushed the sheet on the pointer-down. Never render it: it would
    // pop up over the sheet. The leftover selection itself is cleared by the
    // guard in the reader's selection-change handler. Desktop is unaffected
    // (the sheet counter stays 0 there, and double-click menus are not shown
    // anyway).
    if (ref.read(dictionarySheetOpenProvider) > 0) {
      return const SizedBox.shrink();
    }

    final activeTab = ref.read(readerTabsProvider).activeTab;
    final selectionState = ref.read(readerSelectionProvider);
    final colors = Theme.of(context).colorScheme;

    final selectedText = selectionState.lastSelectedContent?.plainText.trim();

    return ReaderCopyService.buildContextMenu(
      context: context,
      selectableRegionState: selectableRegionState,
      colors: colors,
      lastSelectedContent: selectionState.lastSelectedContent,
      ref: ref,
      visibleStartIndex: selectionState.visibleStartIndex,
      visibleEndIndex: selectionState.visibleEndIndex,
      bookId: activeTab?.bookId ?? '',
      currentParaId: activeTab?.currentParaId,
      currentLineId: activeTab?.currentLineId,
      selectedText: selectedText,
      // Let the Dictionary context-menu item hit-test the render tree at
      // the toolbar anchor — the same word lookup the double-tap performs.
      contentHitTestKey: contentHitTestKey,
      onExplainTap: selectedText != null && selectedText.isNotEmpty
          ? () {
              final tab = ref.read(readerTabsProvider).activeTab;
              if (tab == null) return;
              final text =
                  ref
                      .read(readerSelectionProvider)
                      .lastSelectedContent
                      ?.plainText
                      .trim() ??
                  '';
              if (text.isEmpty) return;
              final readerState = ref.read(readerDataProvider(tab.bookId));
              ReaderAiService.stageExplainPrompt(
                context: context,
                ref: ref,
                activeTab: tab,
                selectedText: text,
                bookName: readerState.bookName ?? tab.bookId,
                currentParaId: tab.currentParaId,
              );
            }
          : null,
      onSummarizeChapterTap: () {
        final tab = ref.read(readerTabsProvider).activeTab;
        if (tab == null) return;
        final readerState = ref.read(readerDataProvider(tab.bookId));
        ReaderAiService.stageChapterSummaryPrompt(
          context: context,
          ref: ref,
          activeTab: tab,
          readerState: readerState,
        );
      },
      // Custom AI prompts run against the selected text (see the Context
      // Menu settings screen). {selectedText} is already substituted in
      // by ReaderCopyService — just stage the prompt and open Vimaṃsa AI.
      onAiPrompt: (prompt) =>
          ReaderAiService.stageCustomPrompt(context, ref, prompt),
    );
  }

  /// Ctrl/Cmd+C shortcut handler: copy the current selection.
  static void copyShortcut({
    required BuildContext context,
    required WidgetRef ref,
  }) {
    final selectionState = ref.read(readerSelectionProvider);
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;

    final readerState = ref.read(readerDataProvider(activeTab.bookId));
    if (readerState.paragraphs.isEmpty) return;

    final settings = ref.read(settingsProvider);
    ReaderCopyService.copySelectedContent(
      ref: ref,
      context: context,
      scope: CopyScope.both,
      addQuote: false,
      lastSelectedContent: selectionState.lastSelectedContent,
      visibleStartIndex: selectionState.visibleStartIndex,
      visibleEndIndex: selectionState.visibleEndIndex,
      script: settings.paliScript,
    );
  }
}
