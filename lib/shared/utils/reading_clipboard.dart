// lib/shared/utils/reading_clipboard.dart
//
// Formats selected reading content for the clipboard so it pastes into
// Word/Google Docs with bold/italic/colors/newlines preserved, and
// falls back to plain text (with real newlines) for apps that don't
// accept rich formats.

import 'package:clipboard/clipboard.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

import 'copy_types.dart';
import '../../features/reader/providers/reader_provider.dart';
import '../../core/utils/pali_script_converter.dart' show Script;
import '../../core/utils/pali_text_utils.dart' show convertPaliToScriptPreservingHtml;
export 'copy_types.dart';

class ReadingClipboard {
  ReadingClipboard._();

  /// Copies [paragraphs] to the clipboard as rich HTML + plain text fallback
  /// using the legacy [CopyQuoteFormat] enum.
  ///
  /// [htmlColor] is the CSS colour used for the main body text (translation).
  /// [paliCssColor] is the CSS colour used for Pāli text.
  /// [pageNumberingSystem] is the label shown in the quote (e.g. "VRI" or "Thai").
  static Future<void> copy(
    List<ParagraphData> paragraphs, {
    required CopyScope scope,
    required CopyQuoteFormat quoteFormat,
    required String bookId,
    String? bookName,
    Color htmlColor = const Color(0xFF33312E),
    Color paliCssColor = const Color(0xFF7A2E1D),
    String pageNumberingSystem = 'VRI',
    Set<String>? enabledLangCodes,
    Script script = Script.roman,
  }) async {
    if (paragraphs.isEmpty) return;

    // Resolve page numbers for quote
    final firstPara = paragraphs.first;
    final lastPara = paragraphs.last;
    final pageRange = _pageRange(firstPara, lastPara);

    // Build citation line
    String citation = '';
    if (quoteFormat != CopyQuoteFormat.none) {
      final buf = StringBuffer('— from ');
      switch (quoteFormat) {
        case CopyQuoteFormat.bookId:
          buf.write(bookId);
        case CopyQuoteFormat.bookName:
          buf.write(bookName ?? bookId);
        case CopyQuoteFormat.full:
          buf.write(bookId);
          if (bookName != null && bookName != bookId) {
            buf.write(' ($bookName)');
          }
          if (pageRange.isNotEmpty) {
            buf.write(', $pageNumberingSystem p. $pageRange');
          }
          break;
        case CopyQuoteFormat.none:
          break;
      }
      citation = buf.toString();
    }

    await _copyWithContent(
      paragraphs: paragraphs,
      scope: scope,
      citation: citation,
      htmlColor: htmlColor,
      paliCssColor: paliCssColor,
      enabledLangCodes: enabledLangCodes,
      script: script,
    );
  }

  /// Copies [paragraphs] to the clipboard using a custom template string.
  /// The [citation] parameter should be the pre-built citation string
  /// with all placeholders resolved.
  static Future<void> copyWithTemplate(
    List<ParagraphData> paragraphs, {
    required CopyScope scope,
    required String template,
    required String citation,
    required String bookId,
    String? bookName,
    Color htmlColor = const Color(0xFF33312E),
    Color paliCssColor = const Color(0xFF7A2E1D),
    Set<String>? enabledLangCodes,
    Script script = Script.roman,
  }) async {
    if (paragraphs.isEmpty) return;

    await _copyWithContent(
      paragraphs: paragraphs,
      scope: scope,
      citation: citation,
      htmlColor: htmlColor,
      paliCssColor: paliCssColor,
      enabledLangCodes: enabledLangCodes,
      script: script,
    );
  }

  /// Internal method to copy with resolved citation
  static Future<void> _copyWithContent({
    required List<ParagraphData> paragraphs,
    required CopyScope scope,
    required String citation,
    required Color htmlColor,
    required Color paliCssColor,
    Set<String>? enabledLangCodes,
    Script script = Script.roman,
  }) async {
    final plain = StringBuffer();
    final html = StringBuffer(
      '<div style="color:${_toCss(htmlColor)};font-family:Georgia,serif;font-size:16px;line-height:1.6;">',
    );

    final paliStyle =
        'color:${_toCss(paliCssColor)};font-family:Georgia,serif;font-size:16px;font-weight:400;';

    for (int pi = 0; pi < paragraphs.length; pi++) {
      final para = paragraphs[pi];
      final lines = para.lines;

      for (int li = 0; li < lines.length; li++) {
        final line = lines[li];

        // Pāli line
        if (scope != CopyScope.translation) {
          final pali = line.paliText?.trim() ?? '';
          if (pali.isNotEmpty) {
            // Convert Pāli text to the user's selected script
            final convertedPali = convertPaliToScriptPreservingHtml(pali, script);
            final formatted = _htmlFromTaggedText(convertedPali);
            plain.writeln(_stripTags(convertedPali));
            html.writeln(
              '<p style="${paliStyle}margin:0 0 4px 0;"><i>$formatted</i></p>',
            );
          }
        }

        // Translation line
        if (scope != CopyScope.pali) {
          // Copy only enabled translations (or all if none specified)
          final translationEntries =
              enabledLangCodes != null && enabledLangCodes.isNotEmpty
              ? line.translations.entries.where(
                  (e) => enabledLangCodes.contains(e.key),
                )
              : line.translations.entries;
          for (final entry in translationEntries) {
            final text = entry.value.trim();
            if (text.isEmpty) continue;

            final formatted = _htmlFromTaggedText(text);
            plain.writeln(_stripTags(text));
            html.writeln(
              '<p style="margin:0 0 2px 0;padding-left:16px;">$formatted</p>',
            );
          }
        }
      }

      // Paragraph separator
      if (pi < paragraphs.length - 1) {
        plain.writeln();
        html.writeln('<br/>');
      }
    }

    // Append citation
    if (citation.isNotEmpty) {
      plain.writeln();
      plain.writeln(citation);
      html.writeln(
        '<p style="margin-top:12px;color:#888;font-style:italic;font-size:13px;">${_escape(citation)}</p>',
      );
    }

    html.writeln('</div>');

    final plainText = plain.toString().trim();
    final htmlDoc = _wrapHtmlDocument(html.toString());

    // The `clipboard` package has no Linux implementation, so on Linux write
    // plain text only (real newlines preserved) via the Flutter system
    // clipboard instead of going through the channel-error fallback.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
      await _writePlainText(plainText);
      return;
    }

    try {
      // Rich copy: writes both the native HTML format (colors/italics for
      // Word/Google Docs) and plain text (real newlines for plain editors).
      await FlutterClipboard.copyRichText(text: plainText, html: htmlDoc);
    } catch (e) {
      // Fallback: plugin unavailable on this platform — plain text only.
      debugPrint(
        'ReadingClipboard: rich copy failed (${e.runtimeType}), '
        'falling back to plain text',
      );
      await _writePlainText(plainText);
    }
  }

  /// Writes [plainText] via the Flutter system clipboard, preserving newlines.
  static Future<void> _writePlainText(String plainText) async {
    if (plainText.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: plainText));
    }
  }

  /// Convert tagged text (with <b>, <i>, <u>, <br>) to clipboard-safe HTML.
  ///
  /// Preserves valid HTML tags (keeping only <b>, <i>, <u> as valid elements,
  /// converting them to <strong>, <em>, <u>) and escapes everything else.
  static String _htmlFromTaggedText(String text) {
    // Normalise <br> variants, then wrap valid tags so we can distinguish
    // them from raw text that needs escaping.
    String result = text
        .replaceAll('<br>', '<br/>')
        .replaceAll('<br/>', '<br/>')
        .replaceAllMapped(
          RegExp(r'<b>(.*?)</b>', caseSensitive: false, dotAll: true),
          (m) => '<strong>${m[1]}</strong>',
        )
        .replaceAllMapped(
          RegExp(r'<i>(.*?)</i>', caseSensitive: false, dotAll: true),
          (m) => '<em>${m[1]}</em>',
        )
        .replaceAllMapped(
          RegExp(r'<u>(.*?)</u>', caseSensitive: false, dotAll: true),
          (m) => '<u>${m[1]}</u>',
        )
        .replaceAllMapped(
          RegExp(r'<h([1-6])>(.*?)</h\d>', caseSensitive: false, dotAll: true),
          (m) => '<strong>${m[2]}</strong>',
        );

    // Escape every run of non-markup characters
    result = result.replaceAllMapped(RegExp(r'[^<>]+'), (m) => _escape(m[0]!));

    return result;
  }

  /// Wrap HTML fragment in a full HTML document for clipboard compatibility.
  static String _wrapHtmlDocument(String body) {
    return '<!DOCTYPE html>\n<html>\n<head>'
        '<meta charset="utf-8">'
        '<meta name="generator" content="ePitaka">'
        '</head>\n<body>\n$body\n</body>\n</html>';
  }

  /// Convert a Flutter Color to a CSS hex string.
  static String _toCss(Color c) {
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  /// Escape HTML special characters.
  static String _escape(String s) =>
      s.replaceAll('&', '&').replaceAll('<', '<').replaceAll('>', '>');

  /// Strip all HTML tags from a string while preserving newlines.
  /// First replaces <br> with \n, then removes remaining tags, and
  /// collapses inline whitespace without eating line breaks.
  static String _stripTags(String s) => s
      .replaceAll('<br>', '\n')
      .replaceAll('<br/>', '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n');

  /// Build a range string like "12–14" or just "12" for the citation.
  static String _pageRange(ParagraphData first, ParagraphData last) {
    final fp = first.pageNumber;
    final lp = last.pageNumber;
    if (fp == null && lp == null) return '';
    if (fp == lp || fp == null) return lp ?? fp ?? '';
    return '$fp–$lp';
  }
}
