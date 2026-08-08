// lib/features/reader/services/reader_copy_service.dart
//
// Extracted copy/share logic from reader_screen.dart. All methods are static
// so they can be called from any widget without instantiating a service.
//
// Methods that need Flutter state (WidgetRef, BuildContext, selection state)
// receive those explicitly as parameters.

import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' hide ProcessTextService;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/context_menu_action.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/pali_script_converter.dart' show Script;
import '../../../core/utils/process_text_service.dart';
import '../../../core/utils/pali_text_utils.dart'
    show convertPaliToScriptPreservingHtml;
import '../../../shared/utils/reading_clipboard.dart';
import '../../dictionary/widgets/dictionary_open.dart';
import '../../dictionary/widgets/dictionary_sheet.dart' show showDictionarySheet;
import '../../reader/providers/reader_provider.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../utils/reader_quote_utils.dart' show buildCitationFromTemplate;
import '../widgets/reader_context_menu.dart' show ContextMenuButton;

/// One selectable unit of text (a Pāli line, or one enabled translation of
/// a line) used for selection-range matching and trimming.
class _Segment {
  final int paraId;
  final int lineId;
  final bool isPali;
  final String? langCode;
  final String taggedText; // display text with <b>/<i>/<br> tags intact
  final String strippedText; // taggedText with tags removed
  final List<int> strippedToTaggedMap; // strippedText[i] <- taggedText[map[i]]
  final String text; // current (possibly trimmed) tagged text

  _Segment({
    required this.paraId,
    required this.lineId,
    required this.isPali,
    required this.langCode,
    required this.taggedText,
    required this.strippedText,
    required this.strippedToTaggedMap,
    String? text,
  }) : text = text ?? taggedText;

  _Segment withText(String newText) => _Segment(
    paraId: paraId,
    lineId: lineId,
    isPali: isPali,
    langCode: langCode,
    taggedText: taggedText,
    strippedText: strippedText,
    strippedToTaggedMap: strippedToTaggedMap,
    text: newText,
  );
}

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
    required int? currentLineId,
    required String? selectedText,
    VoidCallback? onExplainTap,
    VoidCallback? onSummarizeChapterTap,
    void Function(String prompt)? onAiPrompt,
  }) {
    TextSelectionToolbarAnchors anchors;
    try {
      anchors = selectableRegionState.contextMenuAnchors;
    } catch (_) {
      // Flutter bug: SelectableRegionState.startGlyphHeight does a null check
      // on internal state that can be null when selecting very long content on
      // Android. Fall back to a zero anchor so the toolbar still shows up
      // instead of crashing the app.
      anchors = const TextSelectionToolbarAnchors(
        primaryAnchor: Offset.zero,
      );
    }
    final settings = ref.read(settingsProvider);
    final script = settings.paliScript;
    final loc = AppLocalizations.of(context);

    // Render the user's configured, enabled actions in their chosen order.
    // Never show an empty toolbar — fall back to Copy alone when every
    // action has been disabled.
    var actions = settings.contextMenuActions.where((a) => a.enabled).toList();
    if (actions.isEmpty) {
      actions = defaultContextMenuActions()
          .where((a) => a.builtinId == ContextMenuBuiltins.copy)
          .toList();
    }

    return AdaptiveTextSelectionToolbar(
      anchors: anchors,
      children: [
        for (final action in actions)
          switch (action.kind) {
            ContextMenuActionKind.builtin => _builtinButton(
                context: context,
                ref: ref,
                loc: loc,
                colors: colors,
                selectableRegionState: selectableRegionState,
                lastSelectedContent: lastSelectedContent,
                visibleStartIndex: visibleStartIndex,
                visibleEndIndex: visibleEndIndex,
                bookId: bookId,
                currentParaId: currentParaId,
                currentLineId: currentLineId,
                selectedText: selectedText,
                script: script,
                builtinId: action.builtinId,
                onExplainTap: onExplainTap,
                onSummarizeChapterTap: onSummarizeChapterTap,
              ),
            ContextMenuActionKind.externalApp => _externalAppButton(
                context: context,
                colors: colors,
                selectableRegionState: selectableRegionState,
                action: action,
                selectedText: selectedText,
              ),
            ContextMenuActionKind.aiPrompt => _aiPromptButton(
                context: context,
                colors: colors,
                selectableRegionState: selectableRegionState,
                action: action,
                selectedText: selectedText,
                onAiPrompt: onAiPrompt,
              ),
          },
      ],
    );
  }

  /// Build the toolbar button for one of the app's built-in actions.
  static Widget _builtinButton({
    required BuildContext context,
    required WidgetRef ref,
    required AppLocalizations loc,
    required ColorScheme colors,
    required SelectableRegionState selectableRegionState,
    required SelectedContent? lastSelectedContent,
    required int visibleStartIndex,
    required int visibleEndIndex,
    required String bookId,
    required int? currentParaId,
    required int? currentLineId,
    required String? selectedText,
    required Script script,
    required String? builtinId,
    VoidCallback? onExplainTap,
    VoidCallback? onSummarizeChapterTap,
  }) {
    switch (builtinId) {
      case ContextMenuBuiltins.copy:
        // ── Copy (same as Cmd+C) ────────────────────────────────────
        return ContextMenuButton(
          icon: Icons.copy,
          label: loc.copy,
          onTap: () async {
            try {
              await copySelectedContent(
                ref: ref,
                context: context,
                scope: CopyScope.both,
                addQuote: false,
                lastSelectedContent: lastSelectedContent,
                visibleStartIndex: visibleStartIndex,
                visibleEndIndex: visibleEndIndex,
                script: script,
              );
              _showSnackBar(context, 'Copied!');
            } catch (_) {
              // Fallback to system selection copy if rich copy fails
              if (lastSelectedContent != null &&
                  lastSelectedContent.plainText.trim().isNotEmpty) {
                Clipboard.setData(
                  ClipboardData(text: lastSelectedContent.plainText.trim()),
                );
                _showSnackBar(context, 'Copied!');
              }
            } finally {
              selectableRegionState.clearSelection();
            }
          },
          colors: colors,
        );
      case ContextMenuBuiltins.excerpt:
        // ── Excerpt (copy with citation) ────────────────────────────
        return ContextMenuButton(
          icon: Icons.format_quote,
          label: loc.excerpt,
          onTap: () async {
            try {
              await copySelectedContent(
                ref: ref,
                context: context,
                scope: CopyScope.both,
                addQuote: true,
                lastSelectedContent: lastSelectedContent,
                visibleStartIndex: visibleStartIndex,
                visibleEndIndex: visibleEndIndex,
                script: script,
              );
              _showSnackBar(context, 'Excerpt copied!');
            } catch (_) {
              if (lastSelectedContent != null &&
                  lastSelectedContent.plainText.trim().isNotEmpty) {
                Clipboard.setData(
                  ClipboardData(text: lastSelectedContent.plainText.trim()),
                );
                _showSnackBar(context, 'Excerpt copied!');
              }
            } finally {
              selectableRegionState.clearSelection();
            }
          },
          colors: colors,
        );
      case ContextMenuBuiltins.copyLink:
        // ── Copy Link (with lineId and selected text) ───────────────
        return ContextMenuButton(
          icon: Icons.link,
          label: loc.copyLink,
          onTap: () async {
            try {
              await copyLink(
                ref: ref,
                bookId: bookId,
                paraId: currentParaId,
                lineId: currentLineId,
                text: selectedText,
              );
              _showSnackBar(context, 'Link copied!');
            } catch (_) {
              // Fallback: copy just the URL
              final settings = ref.read(settingsProvider);
              final lang = settings.primaryTranslationLang;
              final url = currentParaId != null
                  ? 'https://epitaka.org/$lang/book/$bookId#$currentParaId'
                  : 'https://epitaka.org/$lang/book/$bookId';
              await Clipboard.setData(ClipboardData(text: url));
              _showSnackBar(context, 'Link copied!');
            } finally {
              selectableRegionState.clearSelection();
            }
          },
          colors: colors,
        );
      case ContextMenuBuiltins.dictionary:
        // ── Look up in Dictionary ──────────────────────────────────
        return ContextMenuButton(
          icon: Icons.menu_book,
          label: loc.dictionary,
          onTap: () async {
            final word = _extractLookupWord(lastSelectedContent);
            if (word != null) {
              _openDictionary(context, ref, word);
            }
            selectableRegionState.clearSelection();
          },
          colors: colors,
        );
      case ContextMenuBuiltins.explain:
        // ── Explain (send to Vimaṃsa AI) ────────────────────────────
        if (onExplainTap == null) return const SizedBox.shrink();
        return ContextMenuButton(
          icon: Icons.auto_awesome,
          label: loc.explain,
          onTap: () {
            onExplainTap();
            selectableRegionState.clearSelection();
          },
          colors: colors,
        );
      case ContextMenuBuiltins.summarizeChapter:
        // ── Summarize Chapter (send to Vimaṃsa AI) ──────────────────
        if (onSummarizeChapterTap == null) return const SizedBox.shrink();
        return ContextMenuButton(
          icon: Icons.notes,
          label: loc.summarizeChapter,
          onTap: () {
            onSummarizeChapterTap();
            selectableRegionState.clearSelection();
          },
          colors: colors,
        );
      case ContextMenuBuiltins.share:
        // ── Share (with quote like excerpt) ─────────────────────────
        return ContextMenuButton(
          icon: Icons.share,
          label: loc.share,
          onTap: () async {
            try {
              await shareText(
                ref: ref,
                context: context,
                lastSelectedContent: lastSelectedContent,
                visibleStartIndex: visibleStartIndex,
                visibleEndIndex: visibleEndIndex,
              );
            } catch (_) {
              // Fallback: share just the selected text
              if (lastSelectedContent != null &&
                  lastSelectedContent.plainText.trim().isNotEmpty) {
                await SharePlus.instance.share(
                  ShareParams(text: lastSelectedContent.plainText.trim()),
                );
              }
            } finally {
              selectableRegionState.clearSelection();
            }
          },
          colors: colors,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// Build the toolbar button that launches an installed external app
  /// (dictionary, translator, …) with the selected text.
  static Widget _externalAppButton({
    required BuildContext context,
    required ColorScheme colors,
    required SelectableRegionState selectableRegionState,
    required ContextMenuAction action,
    required String? selectedText,
  }) {
    final loc = AppLocalizations.of(context);
    return ContextMenuButton(
      icon: Icons.extension_outlined,
      label: action.appLabel ?? action.appPackage ?? loc.externalApp,
      onTap: () async {
        final text = selectedText ?? '';
        if (text.isNotEmpty) {
          final ok = await ProcessTextService.launch(
            ProcessTextApp(
              packageName: action.appPackage ?? '',
              label: action.appLabel ?? '',
            ),
            text,
          );
          if (!ok) _showSnackBar(context, 'Could not open the app.');
        }
        selectableRegionState.clearSelection();
      },
      colors: colors,
    );
  }

  /// Build the toolbar button that runs a saved AI prompt against the
  /// selected text. The `{selectedText}` placeholder (if present) is
  /// replaced with the actual selection before handing the prompt over.
  static Widget _aiPromptButton({
    required BuildContext context,
    required ColorScheme colors,
    required SelectableRegionState selectableRegionState,
    required ContextMenuAction action,
    required String? selectedText,
    void Function(String prompt)? onAiPrompt,
  }) {
    final loc = AppLocalizations.of(context);
    return ContextMenuButton(
      icon: Icons.smart_toy_outlined,
      label: action.promptName ?? loc.prompt,
      onTap: () {
        final text = selectedText ?? '';
        final prompt = (action.prompt ?? '').replaceAll('{selectedText}', text);
        if (prompt.isNotEmpty && onAiPrompt != null) {
          onAiPrompt(prompt);
        }
        selectableRegionState.clearSelection();
      },
      colors: colors,
    );
  }

  /// Show a brief snackbar to confirm the action.
  static void _showSnackBar(BuildContext context, String message) {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (_) {
      // Can't show snackbar, ignore silently
    }
  }

  /// Extract the first Pāli word from the selected text for dictionary lookup.
  /// Returns null if no suitable word is found.
  static String? _extractLookupWord(SelectedContent? lastSelectedContent) {
    if (lastSelectedContent == null) return null;
    final raw = lastSelectedContent.plainText.trim();
    if (raw.isEmpty) return null;
    // Take the first whitespace-delimited word
    final word = raw.split(RegExp(r'\s+')).firstWhere(
      (w) => w.isNotEmpty,
      orElse: () => '',
    );
    if (word.isEmpty || word.length < 2 || word.length > 50) return null;
    return word;
  }

  /// Open the dictionary for [word], routing to the side panel if pinned.
  static void _openDictionary(
    BuildContext context,
    WidgetRef ref,
    String word,
  ) {
    if (word.trim().isEmpty) return;

    // Desktop: route the lookup into the shell's dictionary panel (sidebar
    // dock or right column) instead of the bottom sheet.
    if (openDictionaryInPanel(context, ref, word)) return;

    // Show as a bottom sheet
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await showDictionarySheet(context, word.trim());
      } catch (_) {
        // Silently ignore — sheet errors are non-critical
      }
    });
  }

  /// Copy the selected text as plain text with proper newlines.
  ///
  /// When a selection exists:
  /// 1. Try paragraph matching — if matching succeeds, builds output from
  ///    paragraph data with explicit [writeln] between every Pāli and
  ///    translation line, and blank lines between paragraphs.
  /// 2. If matching fails, falls back to [SelectedContent.plainText]
  ///    directly (correct content, may lack newlines).
  ///
  /// When there is no selection, builds text from the visible paragraph
  /// range with the same per-line `writeln` approach.
  static Future<void> copyPlainText({
    required WidgetRef ref,
    required BuildContext context,
    required Script script,
    required SelectedContent? lastSelectedContent,
    required int visibleStartIndex,
    required int visibleEndIndex,
  }) async {
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;

    final readerState = ref.read(readerDataProvider(activeTab.bookId));
    if (readerState.paragraphs.isEmpty) return;

    final settings = ref.read(settingsProvider);
    final enabledLangs = settings.enabledTranslations.isNotEmpty
        ? settings.enabledTranslations.toList()
        : (settings.showTranslation
              ? [settings.primaryTranslationLang]
              : <String>[]);

    // ── When a selection exists ────────────────────────────────────
    if (lastSelectedContent != null &&
        lastSelectedContent.plainText.trim().isNotEmpty) {
      // Try paragraph matching first — this gives us exact line boundaries
      // so we can build text with writeln() for guaranteed newlines.
      final paragraphs = _getParagraphsForSelection(
        readerState.paragraphs,
        lastSelectedContent,
        visibleStartIndex,
        visibleEndIndex,
        script: script,
        enabledLangCodes:
            enabledLangs.isNotEmpty ? enabledLangs.toSet() : null,
      );

      if (paragraphs != null && paragraphs.isNotEmpty) {
        // Matching succeeded → build text from paragraphs with newlines
        final buf = StringBuffer();
        for (int pi = 0; pi < paragraphs.length; pi++) {
          final para = paragraphs[pi];
          for (final line in para.lines) {
            if (line.paliText != null && line.paliText!.trim().isNotEmpty) {
              final pali = convertPaliToScriptPreservingHtml(
                line.paliText!.trim(),
                script,
              );
              buf.writeln(stripTags(pali));
            }
            final translationEntries = enabledLangs.isNotEmpty
                ? line.translations.entries.where(
                    (e) => enabledLangs.contains(e.key),
                  )
                : line.translations.entries;
            for (final entry in translationEntries) {
              final text = entry.value.trim();
              if (text.isNotEmpty) {
                buf.writeln(stripTags(text));
              }
            }
          }
          if (pi < paragraphs.length - 1) buf.writeln();
        }
        final plainText = buf.toString().trim();
        if (plainText.isNotEmpty) {
          Clipboard.setData(ClipboardData(text: plainText));
          return;
        }
      }

      // Matching failed — fallback to exact selection plainText.
      // Content is correct even if newlines may be missing.
      Clipboard.setData(
        ClipboardData(text: lastSelectedContent.plainText.trim()),
      );
      return;
    }

    // ── No selection — build from visible paragraph range ───────────
    final start = visibleStartIndex.clamp(
      0,
      readerState.paragraphs.length - 1,
    );
    final end = visibleEndIndex.clamp(0, readerState.paragraphs.length - 1);

    final buf = StringBuffer();
    for (int pi = start; pi <= end; pi++) {
      final para = readerState.paragraphs[pi];
      for (final line in para.lines) {
        if (line.paliText != null && line.paliText!.trim().isNotEmpty) {
          final pali = convertPaliToScriptPreservingHtml(
            line.paliText!.trim(),
            script,
          );
          buf.writeln(stripTags(pali));
        }
        final translationEntries = enabledLangs.isNotEmpty
            ? line.translations.entries.where(
                (e) => enabledLangs.contains(e.key),
              )
            : line.translations.entries;
        for (final entry in translationEntries) {
          final text = entry.value.trim();
          if (text.isNotEmpty) {
            buf.writeln(stripTags(text));
          }
        }
      }
      if (pi < end) buf.writeln();
    }

    final plainText = buf.toString().trim();
    if (plainText.isEmpty) return;

    Clipboard.setData(ClipboardData(text: plainText));
  }

  /// Copy selected content (or plain text fallback) with formatting.
  /// Uses paragraph matching for formatted copy (bold, italic, newlines)
  /// when it can identify the selected paragraphs. When matching fails,
  /// falls back to [SelectedContent.plainText] — the exact text Flutter's
  /// SelectionArea provides, with newlines preserved — instead of the
  /// visible paragraph range (which caused "too much copied" bugs).
  ///
  /// Always guarantees at least a plain-text copy of the selected text if
  /// [lastSelectedContent] is non-null, regardless of paragraph matching
  /// success or failures.
  static Future<void> copySelectedContent({
    required WidgetRef ref,
    required BuildContext context,
    required CopyScope scope,
    required bool addQuote,
    required SelectedContent? lastSelectedContent,
    required int visibleStartIndex,
    required int visibleEndIndex,
    Script? script,
  }) async {
    // ── Guaranteed plain-text fallback (runs unless we succeed below) ──
    // Capture the selected text early so we always have it, even if the
    // provider/theme lookup throws below.
    final fallbackText = lastSelectedContent?.plainText.trim() ?? '';
    developer.log(
      '[COPY] entered lastSelectedContent=$lastSelectedContent '
      'fallbackText="${fallbackText.length > 100 ? fallbackText.substring(0, 100) : fallbackText}" '
      'len=${fallbackText.length}',
      name: 'epitaka.copy',
    );

    try {
      final activeTab = ref.read(readerTabsProvider).activeTab;
      if (activeTab == null) {
        developer.log(
          '[COPY] ABORT activeTab is null',
          name: 'epitaka.copy',
        );
        throw StateError('activeTab is null');
      }

      final readerState = ref.read(readerDataProvider(activeTab.bookId));
      if (readerState.paragraphs.isEmpty) {
        developer.log(
          '[COPY] ABORT paragraphs empty for bookId=$activeTab.bookId',
          name: 'epitaka.copy',
        );
        throw StateError('paragraphs empty');
      }

      final settings = ref.read(settingsProvider);

      // Theme.of(context) can throw if the context is no longer mounted.
      // Wrap in try/catch so we can still fall back to plain text.
      Color paliColor;
      Color transColor;
      try {
        final brightness = Theme.of(context).brightness;
        paliColor = settings.paliColorPair.resolve(brightness);
        transColor = settings.translationColorPair.resolve(brightness);
      } catch (e) {
        developer.log(
          '[COPY] Theme resolution failed: $e',
          name: 'epitaka.copy',
        );
        paliColor = const Color(0xFF7A2E1D);
        transColor = const Color(0xFF33312E);
      }

      final enabledLangs = settings.enabledTranslations.isNotEmpty
          ? settings.enabledTranslations.toList()
          : (settings.showTranslation
                ? [settings.primaryTranslationLang]
                : <String>[]);
      final effectiveScript = script ?? settings.paliScript;

      final paragraphs = _getParagraphsForSelection(
        readerState.paragraphs,
        lastSelectedContent,
        visibleStartIndex,
        visibleEndIndex,
        script: effectiveScript,
        enabledLangCodes:
            enabledLangs.isNotEmpty ? enabledLangs.toSet() : null,
      );

      if (paragraphs != null && paragraphs.isNotEmpty) {
        // Paragraph matching succeeded → do formatted copy
        developer.log(
          '[COPY] paragraph match OK, ${paragraphs.length} paragraphs, '
          'fallbackText="${fallbackText.length > 80 ? fallbackText.substring(0, 80) : fallbackText}"',
          name: 'epitaka.copy',
        );
        String citation = '';
        if (addQuote) {
          final notifier =
              ref.read(readerDataProvider(activeTab.bookId).notifier);
          final firstPara = paragraphs.first;
          final nearbyHeading = notifier.findNearbyHeading(firstPara.paraId);
          citation = buildCitationFromTemplate(
            settings.quoteTemplate,
            activeTab.bookId,
            readerState.bookName,
            nearbyHeading,
            firstPara.pageNumbers,
            paraId: firstPara.paraId,
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
          enabledLangCodes:
              enabledLangs.isNotEmpty ? enabledLangs.toSet() : null,
          script: effectiveScript,
        );

        // Rich copy succeeded — done.
        developer.log('[COPY] rich copy OK', name: 'epitaka.copy');
        return;
      }

      developer.log(
        '[COPY] paragraph match FAILED, will use fallback text',
        name: 'epitaka.copy',
      );
    } catch (e) {
      // Any error in the rich-copy path — log and fall through to plain
      // text below.
      developer.log(
        '[COPY] rich-copy exception: $e',
        name: 'epitaka.copy',
      );
    }

    // ── Guaranteed plain-text fallback ────────────────────────────────
    // Always write the selected text to clipboard, even if everything above
    // failed. This ensures tapping Copy always produces at least plain text.
    if (fallbackText.isNotEmpty) {
      developer.log(
        '[COPY] writing fallback plain text (len=${fallbackText.length})',
        name: 'epitaka.copy',
      );
      await Clipboard.setData(ClipboardData(text: fallbackText));
    } else {
      developer.log(
        '[COPY] fallback text is empty — nothing to copy',
        name: 'epitaka.copy',
      );
    }
  }

  /// Resolve the paragraph range to copy from the user's text selection.
  ///
  /// Uses a "displayed text" matching approach: builds the exact text a user
  /// sees on screen (with Pali script conversion applied) from each paragraph,
  /// mirrors how Flutter's [SelectionArea] concatenates [Selectable] children
  /// with `\n` separators, then locates the selected text within this combined
  /// string to determine which paragraphs are actually selected.
  ///
  /// Returns `null` when matching fails (callers should fall back to
  /// [SelectedContent.plainText] directly rather than guessing a paragraph
  /// range).
  static List<ParagraphData>? _getParagraphsForSelection(
    List<ParagraphData> allParagraphs,
    SelectedContent? selection,
    int visibleStartIndex,
    int visibleEndIndex, {
    Script script = Script.roman,
    Set<String>? enabledLangCodes,
  }) {
    if (selection == null || selection.plainText.trim().isEmpty) {
      return null;
    }

    final trimmed = _buildTrimmedSelectionParagraphs(
      allParagraphs,
      selection.plainText,
      script,
      visibleStartIndex: visibleStartIndex,
      visibleEndIndex: visibleEndIndex,
      enabledLangCodes: enabledLangCodes,
    );
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }

    // Matching failed — return null. Callers should fall back to
    // SelectedContent.plainText (the exact text from Flutter's
    // SelectionArea) rather than guessing from the visible range.
    return null;
  }

  /// Builds the exact selected sub-range of content as trimmed
  /// [ParagraphData]/[LineData] objects, using "displayed text" matching
  /// (required for non-Roman scripts) plus offset mapping back through
  /// tag-stripping and whitespace-normalization, so only the characters the
  /// user actually selected are returned — not whole paragraphs.
  ///
  /// Strips U+FFFC (Object Replacement Character) from the input selected
  /// text before matching. Flutter's SelectionArea inserts U+FFFC wherever
  /// a [WidgetSpan] appears in a [Text.rich] — our variant-annotation chips
  /// in [PaliTextWithVariants] produce these, so stripping them is necessary
  /// for reliable matching.
  ///
  /// Returns null if no match is found (caller should fall back).
  static List<ParagraphData>? _buildTrimmedSelectionParagraphs(
    List<ParagraphData> allParagraphs,
    String selectedText,
    Script script, {
    int visibleStartIndex = 0,
    int visibleEndIndex = 0,
    Set<String>? enabledLangCodes,
  }) {
    // Check for hidden characters (U+FFFC from WidgetSpan, zero-width chars)
    final hasFffc = selectedText.contains('\u{FFFC}');
    final rawLen = selectedText.length;
    // Strip U+FFFC (Object Replacement Character) which Flutter inserts
    // for WidgetSpan children (e.g., variant annotation chips). Without
    // this, matching fails when the selection includes variant annotations.
    final cleaned = selectedText.replaceAll('\u{FFFC}', '');
    final strippedCount = rawLen - cleaned.length;
    final needle = _normalizeText(cleaned);
    developer.log(
      '[COPY_MATCH] needle="${needle.length > 200 ? needle.substring(0, 200) : needle}" '
      'len=${needle.length} rawLen=$rawLen hasFFFC=$hasFffc stripped=$strippedCount',
      name: 'epitaka.copy',
    );
    if (needle.isEmpty || allParagraphs.isEmpty) {
      developer.log(
        '[COPY_MATCH] ABORT needleEmpty=${needle.isEmpty} paragraphsEmpty=${allParagraphs.isEmpty}',
        name: 'epitaka.copy',
      );
      return null;
    }

    // Constrain search to a window around the visible range
    final searchStart = (visibleStartIndex - 50).clamp(
      0,
      allParagraphs.length - 1,
    );
    final searchEnd = (visibleEndIndex + 50).clamp(0, allParagraphs.length - 1);
    final searchRange = allParagraphs.sublist(searchStart, searchEnd + 1);

    // Lookup so we can preserve pageNumber/heading/etc. when rebuilding.
    final paraLookup = <int, ParagraphData>{
      for (final p in searchRange) p.paraId: p,
    };

    // Build one segment per heading text + Pāli line + enabled
    // translation, in the same order Flutter's SelectionArea would
    // present them (headings rendered before lines).
    final segments = <_Segment>[];
    for (final para in searchRange) {
      // Paragraph headings are rendered as selectable PaliTextStatic
      // widgets — include them so the combined text matches Flutter's
      // plainText when the selection spans heading text.
      if (para.heading != null && para.heading!.title.trim().isNotEmpty) {
        final tagged = convertPaliToScriptPreservingHtml(
          para.heading!.title.trim(),
          script,
        );
        final (stripped, map) = _stripTagsWithMap(tagged);
        segments.add(
          _Segment(
            paraId: para.paraId,
            lineId: -1, // Not a real line — heading only
            isPali: true,
            langCode: null,
            taggedText: tagged,
            strippedText: stripped,
            strippedToTaggedMap: map,
          ),
        );
      }
      for (final line in para.lines) {
        if (line.paliText != null && line.paliText!.trim().isNotEmpty) {
          final tagged = convertPaliToScriptPreservingHtml(
            line.paliText!.trim(),
            script,
          );
          final (stripped, map) = _stripTagsWithMap(tagged);
          segments.add(
            _Segment(
              paraId: para.paraId,
              lineId: line.lineId,
              isPali: true,
              langCode: null,
              taggedText: tagged,
              strippedText: stripped,
              strippedToTaggedMap: map,
            ),
          );
        }
        final entries = enabledLangCodes != null && enabledLangCodes.isNotEmpty
            ? line.translations.entries.where(
                (e) => enabledLangCodes.contains(e.key),
              )
            : line.translations.entries;
        for (final entry in entries) {
          final tagged = entry.value.trim();
          if (tagged.isEmpty) continue;
          final (stripped, map) = _stripTagsWithMap(tagged);
          segments.add(
            _Segment(
              paraId: para.paraId,
              lineId: line.lineId,
              isPali: false,
              langCode: entry.key,
              taggedText: tagged,
              strippedText: stripped,
              strippedToTaggedMap: map,
            ),
          );
        }
      }
    }
    if (segments.isEmpty) return null;

    // Concatenate normalized segment text, tracking per-segment offset
    // ranges in the combined string and a normalized->tagged offset map
    // for each segment.
    final combinedBuf = StringBuffer();
    final segStart = <int>[];
    final segEnd = <int>[];
    final segNormMap = <List<int>>[];

    for (final seg in segments) {
      final (normText, normMap) = _normalizeWithMap(seg.strippedText);
      final finalMap = [
        for (final idx in normMap) seg.strippedToTaggedMap[idx],
      ];
      // NO separator between segments — Flutter's SelectionArea concatenates
      // selectable children's text without any separator (no \n, no space).
      segStart.add(combinedBuf.length);
      combinedBuf.write(normText);
      segEnd.add(combinedBuf.length);
      segNormMap.add(finalMap);
    }

    final combinedText = combinedBuf.toString();
    developer.log(
      '[COPY_MATCH] combinedText len=${combinedText.length} '
      'start="${combinedText.length > 100 ? combinedText.substring(0, 100) : combinedText}"',
      name: 'epitaka.copy',
    );
    final matchPos = combinedText.indexOf(needle);
    developer.log(
      '[COPY_MATCH] indexOf result=$matchPos (needleLen=${needle.length})',
      name: 'epitaka.copy',
    );
    if (matchPos < 0) {
      // Log a snippet for comparison
      developer.log(
        '[COPY_MATCH] MISMATCH! Needle="${needle.length > 80 ? needle.substring(0, 80) : needle}"',
        name: 'epitaka.copy',
      );
      developer.log(
        '[COPY_MATCH] MISMATCH! Combined="${combinedText.length > 80 ? combinedText.substring(0, 80) : combinedText}"',
        name: 'epitaka.copy',
      );
      return null;
    }
    final matchEnd = matchPos + needle.length;

    int startSegIdx = -1, endSegIdx = -1;
    int startOffsetInSeg = 0, endOffsetInSeg = 0;
    for (int i = 0; i < segments.length; i++) {
      if (matchPos >= segStart[i] && matchPos <= segEnd[i]) {
        startSegIdx = i;
        startOffsetInSeg = matchPos - segStart[i];
        break;
      }
    }
    for (int i = 0; i < segments.length; i++) {
      if (matchEnd >= segStart[i] && matchEnd <= segEnd[i]) {
        endSegIdx = i;
        endOffsetInSeg = matchEnd - segStart[i];
        break;
      }
    }
    if (startSegIdx < 0 || endSegIdx < 0 || startSegIdx > endSegIdx)
      return null;

    // Trim only the boundary segments' tagged text to the matched range.
    final trimmedSegments = <_Segment>[];
    for (int i = startSegIdx; i <= endSegIdx; i++) {
      final seg = segments[i];
      int cutStart = 0;
      int cutEnd = seg.taggedText.length;

      if (i == startSegIdx) {
        cutStart = startOffsetInSeg < segNormMap[i].length
            ? segNormMap[i][startOffsetInSeg]
            : seg.taggedText.length;
      }
      if (i == endSegIdx) {
        if (endOffsetInSeg <= 0) {
          cutEnd = 0;
        } else if (endOffsetInSeg - 1 < segNormMap[i].length) {
          cutEnd = segNormMap[i][endOffsetInSeg - 1] + 1;
        } else {
          cutEnd = seg.taggedText.length;
        }
      }
      if (cutStart > cutEnd) cutStart = cutEnd;

      trimmedSegments.add(
        seg.withText(seg.taggedText.substring(cutStart, cutEnd)),
      );
    }

    return _regroupSegmentsIntoParagraphs(trimmedSegments, paraLookup);
  }

  /// Rebuild [ParagraphData]/[LineData] objects from a flat, trimmed
  /// segment list, preserving each paragraph's original pageNumber/heading.
  static List<ParagraphData> _regroupSegmentsIntoParagraphs(
    List<_Segment> segs,
    Map<int, ParagraphData> paraLookup,
  ) {
    final result = <ParagraphData>[];

    int? curParaId;
    List<LineData> curLines = [];
    int? curLineId;
    String? curPali;
    Map<String, String> curTrans = {};

    void flushLine() {
      if (curLineId == null) return;
      if ((curPali != null && curPali!.isNotEmpty) || curTrans.isNotEmpty) {
        curLines.add(
          LineData(
            lineId: curLineId!,
            paliText: curPali,
            translations: Map.of(curTrans),
            normalizedText: '',
          ),
        );
      }
      curPali = null;
      curTrans = {};
      curLineId = null;
    }

    void flushPara() {
      flushLine();
      if (curParaId != null && curLines.isNotEmpty) {
        final orig = paraLookup[curParaId!];
        if (orig != null) {
          result.add(orig.copyWith(lines: List.of(curLines)));
        }
      }
      curLines = [];
      curParaId = null;
    }

    for (final seg in segs) {
      if (curParaId != seg.paraId) {
        flushPara();
        curParaId = seg.paraId;
      }
      if (curLineId != seg.lineId) {
        flushLine();
        curLineId = seg.lineId;
      }
      if (seg.text.isEmpty) continue;
      if (seg.isPali) {
        curPali = seg.text;
      } else {
        curTrans[seg.langCode!] = seg.text;
      }
    }
    flushPara();

    return result;
  }

  /// Strip HTML tags from [html], returning the stripped text plus a map
  /// where map[i] is the index in [html] that stripped-text char i came from.
  static (String, List<int>) _stripTagsWithMap(String html) {
    final buf = StringBuffer();
    final map = <int>[];
    bool inTag = false;
    for (int i = 0; i < html.length; i++) {
      final c = html[i];
      if (c == '<') {
        inTag = true;
        continue;
      }
      if (c == '>') {
        inTag = false;
        continue;
      }
      if (!inTag) {
        buf.write(c);
        map.add(i);
      }
    }
    return (buf.toString(), map);
  }

  /// Collapse whitespace runs to a single space (like [_normalizeText]) but
  /// also return a map from each output char index to the index in the
  /// input string it came from, so offsets found in normalized text can be
  /// mapped back to the pre-normalization (but still tag-stripped) text.
  static (String, List<int>) _normalizeWithMap(String s) {
    final buf = StringBuffer();
    final map = <int>[];
    bool inWhitespace = false;
    for (int i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == ' ' || c == '\n' || c == '\t' || c == '\r') {
        if (!inWhitespace) {
          buf.write(' ');
          map.add(i);
          inWhitespace = true;
        }
      } else {
        buf.write(c);
        map.add(i);
        inWhitespace = false;
      }
    }
    return (buf.toString(), map);
  }

  /// Normalize whitespace for reliable text matching:
  /// collapse runs of whitespace to a single space.
  static String _normalizeText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Share the selected text via the system share sheet,
  /// including a citation (like Excerpt) built from the quote template.
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

    final settings = ref.read(settingsProvider);

    // Build content with citation (like excerpt)
    String textToShare;

    if (lastSelectedContent != null &&
        lastSelectedContent.plainText.trim().isNotEmpty) {
      // Try paragraph matching to get citation
      final enabledLangs = settings.enabledTranslations.isNotEmpty
          ? settings.enabledTranslations.toList()
          : (settings.showTranslation
                ? [settings.primaryTranslationLang]
                : <String>[]);
      final paragraphs = _getParagraphsForSelection(
        readerState.paragraphs,
        lastSelectedContent,
        visibleStartIndex,
        visibleEndIndex,
        script: settings.paliScript,
        enabledLangCodes:
            enabledLangs.isNotEmpty ? enabledLangs.toSet() : null,
      );

      if (paragraphs != null && paragraphs.isNotEmpty) {
        // Build plain text from paragraphs first
        final buf = StringBuffer();
        for (int pi = 0; pi < paragraphs.length; pi++) {
          final para = paragraphs[pi];
          for (final line in para.lines) {
            if (line.paliText != null && line.paliText!.trim().isNotEmpty) {
              buf.writeln(stripTags(line.paliText!.trim()));
            }
            final translationEntries = enabledLangs.isNotEmpty
                ? line.translations.entries.where(
                    (e) => enabledLangs.contains(e.key),
                  )
                : line.translations.entries;
            for (final entry in translationEntries) {
              if (entry.value.trim().isNotEmpty) {
                buf.writeln(stripTags(entry.value.trim()));
              }
            }
          }
          if (pi < paragraphs.length - 1) buf.writeln();
        }
        textToShare = buf.toString().trim();

        // Only add citation/reference if text has >= 3 words.
        // For short selections (< 3 words), share text alone
        // so users can share single words for dictionary lookup.
        final wordCount = textToShare.split(RegExp(r'\s+')).length;
        if (wordCount >= 3) {
          final notifier = ref.read(readerDataProvider(activeTab.bookId).notifier);
          final firstPara = paragraphs.first;
          final nearbyHeading = notifier.findNearbyHeading(firstPara.paraId);
          final citation = buildCitationFromTemplate(
            settings.quoteTemplate,
            activeTab.bookId,
            readerState.bookName,
            nearbyHeading,
            firstPara.pageNumbers,
            paraId: firstPara.paraId,
          );
          if (citation.isNotEmpty) {
            textToShare = '$textToShare\n\n$citation';
          }
        }
      } else {
        // Fallback: just use the selected text without citation
        textToShare = lastSelectedContent.plainText.trim();
      }
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
            buf.writeln(stripTags(line.paliText!.trim()));
          }
          for (final entry in line.translations.entries) {
            if (entry.value.trim().isNotEmpty) {
              buf.writeln(stripTags(entry.value.trim()));
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

  /// Copy a share link to the current position (paragraph + optional line)
  /// to the clipboard, optionally including the selected text.
  ///
  /// Generates a URL matching the website's canonical format:
  ///   https://epitaka.org/{lang}/book/{bookId}/{heading-slug}#{paraId}-{lineId}
  ///
  /// The heading slug is built from the nearest section heading's lowercased
  /// title (spaces → hyphens) plus its para_id, e.g. "the-net-of-views-123".
  static Future<void> copyLink({
    required WidgetRef ref,
    required String bookId,
    required int? paraId,
    int? lineId,
    String? text,
  }) async {
    final settings = ref.read(settingsProvider);
    final lang = settings.primaryTranslationLang;

    // Build the heading slug from the nearest section heading
    String slug = '';
    if (paraId != null) {
      try {
        final db = await ref.read(epitakaDbProvider.future);
        final headingInfo = await db.getHeadingAtPara(bookId, paraId);
        if (headingInfo != null &&
            headingInfo.title != null &&
            headingInfo.title!.isNotEmpty &&
            headingInfo.paraId != null) {
          slug =
              '${headingInfo.title!.toLowerCase().replaceAll(' ', '-')}-${headingInfo.paraId}';
        }
      } catch (e) {
        developer.log(
          '[COPY_LINK] Heading query failed: $e',
          name: 'epitaka.copy',
        );
      }
    }

    // Build URL: https://epitaka.org/{lang}/book/{bookId}/{slug}#{paraId}-{lineId}
    final baseUri = 'https://epitaka.org/$lang/book/$bookId';
    final path = slug.isNotEmpty ? '$baseUri/$slug' : baseUri;
    final fragment =
        paraId != null ? '#$paraId${lineId != null ? '-$lineId' : ''}' : '';
    final url = '$path$fragment';

    final String shareText;
    if (text != null && text.trim().isNotEmpty) {
      shareText = '$text\n\n$url';
    } else {
      shareText = url;
    }

    await Clipboard.setData(ClipboardData(text: shareText));
  }

  // ── Public helpers ───────────────────────────────────────────────

  /// Strip HTML tags from a string.
  static String stripTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  // ── Private helpers ──────────────────────────────────────────────
}
