// lib/shared/utils/reading_clipboard.dart
//
// Formats selected reading content for the clipboard so it pastes into
// Word/Google Docs with bold/italic/colors/newlines preserved, and
// falls back to plain text (with real newlines) for apps that don't
// accept rich formats.

import 'package:flutter/material.dart';
import 'package:super_clipboard/super_clipboard.dart';

import 'copy_types.dart';
import '../../features/reader/providers/reader_provider.dart';
export 'copy_types.dart';

class ReadingClipboard {
  ReadingClipboard._();

  /// Copies [paragraphs] to the clipboard as rich HTML + plain text fallback.
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

    final plain = StringBuffer();
    final html = StringBuffer('<div style="color:${_toCss(htmlColor)};font-family:Georgia,serif;font-size:16px;line-height:1.6;">');

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
            final formatted = _htmlFromTaggedText(pali);
            plain.writeln(_stripTags(pali));
            html.writeln(
                '<p style="${paliStyle}margin:0 0 4px 0;"><i>$formatted</i></p>');
          }
        }

        // Translation line
        if (scope != CopyScope.pali) {
          // Copy only enabled translations (or all if none specified)
          final translationEntries = enabledLangCodes != null && enabledLangCodes.isNotEmpty
              ? line.translations.entries.where((e) => enabledLangCodes.contains(e.key))
              : line.translations.entries;
          for (final entry in translationEntries) {
            final text = entry.value.trim();
            if (text.isEmpty) continue;

            final formatted = _htmlFromTaggedText(text);
            plain.writeln(_stripTags(text));
            html.writeln(
                '<p style="margin:0 0 2px 0;padding-left:16px;">$formatted</p>');
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
      html.writeln('<p style="margin-top:12px;color:#888;font-style:italic;font-size:13px;">${_escape(citation)}</p>');
    }

    html.writeln('</div>');

    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return;

    final item = DataWriterItem();
    item.add(Formats.plainText(plain.toString().trim()));
    item.add(Formats.htmlText(_wrapHtmlDocument(html.toString())));
    await clipboard.write([item]);
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
    result = result.replaceAllMapped(
      RegExp(r'[^<>]+'),
      (m) => _escape(m[0]!),
    );

    return result;
  }

  /// Build a range string like "12–14" or just "12" for the citation.
  static String _pageRange(ParagraphData first, ParagraphData last) {
    final fp = first.pageNumber;
    final lp = last.pageNumber;
    if (fp == null && lp == null) return '';
    if (fp == lp || fp == null) return lp ?? fp ?? '';
    return '$fp–$lp';
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
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  /// Strip all HTML tags from a string.
  static String _stripTags(String s) =>
      s.replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
}
