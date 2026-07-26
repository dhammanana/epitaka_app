// lib/features/reader/services/reader_copy_service.dart
//
// Extracted copy/share logic from reader_screen.dart. All methods are static
// so they can be called from any widget without instantiating a service.
//
// Methods that need Flutter state (WidgetRef, BuildContext, selection state)
// receive those explicitly as parameters.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../shared/utils/reading_clipboard.dart';
import '../../reader/providers/reader_provider.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../utils/reader_quote_utils.dart' show buildCitationFromTemplate;
import '../widgets/reader_context_menu.dart' show ContextMenuButton;

/// Service with static methods for copy and share operations.
class ReaderCopyService {
  ReaderCopyService._();

  /// Build the context menu toolbar shown when text is selected.
  static Widget buildContextMenu({
    required BuildContext context,
    required SelectableRegionState selectableRegionState,
    required ColorScheme colors,
    required SelectedContent? lastSelectedContent,
    required WidgetRef ref,
    required int visibleStartIndex,
    required int visibleEndIndex,
    required String bookId,
    required int? currentParaId,
  }) {
    final anchors = selectableRegionState.contextMenuAnchors;

    return AdaptiveTextSelectionToolbar(
      anchors: anchors,
      children: [
        ContextMenuButton(
          icon: Icons.copy,
          label: 'Copy Plain Text',
          onTap: () {
            copyPlainText(lastSelectedContent);
            selectableRegionState.clearSelection();
          },
          colors: colors,
        ),
        ContextMenuButton(
          icon: Icons.copy_all,
          label: 'Copy with Style',
          onTap: () {
            copySelectedContent(
              ref: ref,
              context: context,
              scope: CopyScope.both,
              addQuote: false,
              lastSelectedContent: lastSelectedContent,
              visibleStartIndex: visibleStartIndex,
              visibleEndIndex: visibleEndIndex,
            );
            selectableRegionState.clearSelection();
          },
          colors: colors,
        ),
        ContextMenuButton(
          icon: Icons.text_fields,
          label: 'Pāli Only',
          onTap: () {
            copySelectedContent(
              ref: ref,
              context: context,
              scope: CopyScope.pali,
              addQuote: false,
              lastSelectedContent: lastSelectedContent,
              visibleStartIndex: visibleStartIndex,
              visibleEndIndex: visibleEndIndex,
            );
            selectableRegionState.clearSelection();
          },
          colors: colors,
        ),
        ContextMenuButton(
          icon: Icons.translate,
          label: 'Translation Only',
          onTap: () {
            copySelectedContent(
              ref: ref,
              context: context,
              scope: CopyScope.translation,
              addQuote: false,
              lastSelectedContent: lastSelectedContent,
              visibleStartIndex: visibleStartIndex,
              visibleEndIndex: visibleEndIndex,
            );
            selectableRegionState.clearSelection();
          },
          colors: colors,
        ),
        ContextMenuButton(
          icon: Icons.format_quote,
          label: 'Copy with Quote',
          onTap: () {
            copySelectedContent(
              ref: ref,
              context: context,
              scope: CopyScope.both,
              addQuote: true,
              lastSelectedContent: lastSelectedContent,
              visibleStartIndex: visibleStartIndex,
              visibleEndIndex: visibleEndIndex,
            );
            selectableRegionState.clearSelection();
          },
          colors: colors,
        ),
        ContextMenuButton(
          icon: Icons.share,
          label: 'Share',
          onTap: () {
            shareText(
              ref: ref,
              context: context,
              lastSelectedContent: lastSelectedContent,
              visibleStartIndex: visibleStartIndex,
              visibleEndIndex: visibleEndIndex,
            );
            selectableRegionState.clearSelection();
          },
          colors: colors,
        ),
        ContextMenuButton(
          icon: Icons.link,
          label: 'Share Link',
          onTap: () {
            shareLink(bookId: bookId, paraId: currentParaId);
            selectableRegionState.clearSelection();
          },
          colors: colors,
        ),
        ContextMenuButton(
          icon: Icons.select_all,
          label: 'Select All',
          onTap: () => selectableRegionState.selectAll(),
          colors: colors,
        ),
      ],
    );
  }

  /// Copy the selected text as plain text using Flutter's clipboard.
  static void copyPlainText(SelectedContent? selectedContent) {
    if (selectedContent == null || selectedContent.plainText.trim().isEmpty) {
      return;
    }
    Clipboard.setData(ClipboardData(text: selectedContent.plainText));
  }

  /// Called by Ctrl/Cmd+C shortcut.
  static Future<void> onCopyShortcut({
    required WidgetRef ref,
    required BuildContext context,
    required SelectedContent? lastSelectedContent,
    required int visibleStartIndex,
    required int visibleEndIndex,
  }) async {
    await copySelectedContent(
      ref: ref,
      context: context,
      scope: CopyScope.both,
      addQuote: false,
      lastSelectedContent: lastSelectedContent,
      visibleStartIndex: visibleStartIndex,
      visibleEndIndex: visibleEndIndex,
    );
  }

  /// Copy selected content (or visible content as fallback) with formatting.
  static Future<void> copySelectedContent({
    required WidgetRef ref,
    required BuildContext context,
    required CopyScope scope,
    required bool addQuote,
    required SelectedContent? lastSelectedContent,
    required int visibleStartIndex,
    required int visibleEndIndex,
  }) async {
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;

    final readerState = ref.read(readerDataProvider(activeTab.bookId));
    if (readerState.paragraphs.isEmpty) return;

    if (lastSelectedContent == null ||
        lastSelectedContent.plainText.trim().isEmpty) {
      await _copyVisibleContent(
        ref: ref,
        context: context,
        scope: scope,
        addQuote: addQuote,
        visibleStartIndex: visibleStartIndex,
        visibleEndIndex: visibleEndIndex,
      );
      return;
    }

    // Fallback: copy visible content since paragraph-level selection is removed
    await _copyVisibleContent(
      ref: ref,
      context: context,
      scope: scope,
      addQuote: addQuote,
      visibleStartIndex: visibleStartIndex,
      visibleEndIndex: visibleEndIndex,
    );
    return;
  }

  /// Share the selected or visible text via the system share sheet.
  static Future<void> shareText({
    required WidgetRef ref,
    required BuildContext context,
    required SelectedContent? lastSelectedContent,
    required int visibleStartIndex,
    required int visibleEndIndex,
  }) async {
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;

    final readerState = ref.read(readerDataProvider(activeTab.bookId));
    if (readerState.paragraphs.isEmpty) return;

    String textToShare;

    if (lastSelectedContent != null &&
        lastSelectedContent.plainText.trim().isNotEmpty) {
      textToShare = lastSelectedContent.plainText.trim();
    } else {
      // Fallback: build text from visible paragraphs
      final start = (visibleStartIndex - 5).clamp(
        0,
        readerState.paragraphs.length - 1,
      );
      final end = (visibleEndIndex + 5).clamp(
        0,
        readerState.paragraphs.length - 1,
      );
      final buf = StringBuffer();
      for (int i = start; i <= end; i++) {
        final para = readerState.paragraphs[i];
        for (final line in para.lines) {
          if (line.paliText != null && line.paliText!.trim().isNotEmpty) {
            buf.writeln(_stripTags(line.paliText!.trim()));
          }
          for (final entry in line.translations.entries) {
            if (entry.value.trim().isNotEmpty) {
              buf.writeln(entry.value.trim());
            }
          }
        }
        if (i < end) buf.writeln();
      }
      textToShare = buf.toString().trim();
    }

    if (textToShare.isEmpty) return;

    await SharePlus.instance.share(ShareParams(text: textToShare));
  }

  /// Share a deep link to the current paragraph position.
  static Future<void> shareLink({
    required String bookId,
    required int? paraId,
  }) async {
    final paraFragment = paraId != null ? '/$paraId' : '';
    final url = 'https://epitaka.org/app/$bookId$paraFragment';
    await SharePlus.instance.share(ShareParams(text: url));
  }

  // ── Private helpers ──────────────────────────────────────────────

  /// Copy the visible range of paragraphs to the clipboard with formatting.
  static Future<void> _copyVisibleContent({
    required WidgetRef ref,
    required BuildContext context,
    required CopyScope scope,
    required bool addQuote,
    required int visibleStartIndex,
    required int visibleEndIndex,
  }) async {
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;

    final readerState = ref.read(readerDataProvider(activeTab.bookId));
    if (readerState.paragraphs.isEmpty) return;

    final start = visibleStartIndex.clamp(0, readerState.paragraphs.length - 1);
    final end = visibleEndIndex.clamp(0, readerState.paragraphs.length - 1);
    final paragraphs = readerState.paragraphs.sublist(start, end + 1);

    if (paragraphs.isEmpty) return;

    final settings = ref.read(settingsProvider);
    final brightness = Theme.of(context).brightness;
    final paliColor = settings.paliColorPair.resolve(brightness);
    final transColor = settings.translationColorPair.resolve(brightness);
    final enabledLangs = settings.enabledTranslations.isNotEmpty
        ? settings.enabledTranslations.toList()
        : (settings.showTranslation
              ? [settings.primaryTranslationLang]
              : <String>[]);

    // Build citation from template if addQuote is true
    String citation = '';
    if (addQuote) {
      final notifier = ref.read(readerDataProvider(activeTab.bookId).notifier);
      final firstPara = paragraphs.first;
      final nearbyHeading = notifier.findNearbyHeading(firstPara.paraId);
      citation = buildCitationFromTemplate(
        settings.quoteTemplate,
        activeTab.bookId,
        readerState.bookName,
        nearbyHeading,
        firstPara.pageNumbers,
      );
    }

    await ReadingClipboard.copyWithTemplate(
      paragraphs,
      scope: scope,
      template: settings.quoteTemplate,
      citation: citation,
      bookId: activeTab.bookId,
      bookName: readerState.bookName,
      htmlColor: transColor,
      paliCssColor: paliColor,
      enabledLangCodes: enabledLangs.isNotEmpty ? enabledLangs.toSet() : null,
    );
  }

  /// Strip HTML tags from a string.
  static String _stripTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }
}
