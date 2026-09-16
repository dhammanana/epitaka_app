/// Share a Vīmaṃsā answer as a PDF document file.
///
/// The `pdf` package's built-in Helvetica only covers Latin-1, which drops
/// Pāli diacritics (ā ī ū ṅ ñ …), so the bundled DejaVuSans (full
/// Latin-Extended coverage) is embedded instead.
library;

import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class AiResponseShareService {
  /// Build a PDF from the answer [text] and open the system share sheet
  /// with the file. Falls back to plain-text share, then does nothing.
  static Future<void> shareResponseAsPdf({
    required String text,
    String subject = 'Vīmaṃsā answer',
  }) async {
    if (kIsWeb) {
      await SharePlus.instance.share(ShareParams(text: text, subject: subject));
      return;
    }
    try {
      final regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
      );
      final bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
      );

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            pw.Text(subject, style: pw.TextStyle(font: bold, fontSize: 16)),
            pw.SizedBox(height: 4),
            pw.Text(
              'Exported from ePitaka Vīmaṃsā',
              style: pw.TextStyle(font: regular, fontSize: 9),
            ),
            pw.SizedBox(height: 16),
            ..._blocks(text, regular, bold),
          ],
        ),
      );

      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(p.join(dir.path, 'vimamsa_answer_$stamp.pdf'));
      await file.writeAsBytes(await doc.save());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: subject,
          text: '$subject — exported from ePitaka',
        ),
      );
      return;
    } catch (_) {}
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: subject));
    } catch (_) {}
  }

  /// Split markdown [text] into PDF blocks: `#` headings, `>` excerpts
  /// (blockquotes), fenced code blocks, `---` rules, `|` tables, `- `/`1. `
  /// lists, and paragraphs (soft-wrapped lines joined). Inline `**bold**`,
  /// `*italic*`, `` `code` `` and `~~strike~~` are rendered, not printed raw.
  static List<pw.Widget> _blocks(String text, pw.Font regular, pw.Font bold) {
    final style = _MdStyle(regular, bold);
    final widgets = <pw.Widget>[];
    final lines = text.split('\n');
    final bullet = RegExp(r'^(\s*([-*•]|\d+[.)])\s+)');
    final hr = RegExp(r'^\s*(-{3,}|\*{3,}|_{3,})\s*$');
    var i = 0;
    while (i < lines.length) {
      final trimmed = lines[i].trimLeft();
      if (trimmed.trim().isEmpty) {
        widgets.add(pw.SizedBox(height: 8));
        i++;
        continue;
      }
      // Fenced code block.
      if (trimmed.startsWith('```')) {
        final buf = <String>[];
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
          buf.add(lines[i]);
          i++;
        }
        i++; // Skip closing fence.
        widgets.add(style.codeBlock(buf.join('\n')));
        continue;
      }
      // Heading.
      final heading = RegExp(r'^(#{1,4})\s+(.*)').firstMatch(trimmed);
      if (heading != null) {
        widgets.add(style.heading(heading.group(2)!, heading.group(1)!.length));
        i++;
        continue;
      }
      // Excerpt (blockquote): gather consecutive `>` lines.
      if (trimmed.startsWith('>')) {
        final buf = <String>[];
        while (i < lines.length && lines[i].trimLeft().startsWith('>')) {
          buf.add(lines[i].trimLeft().replaceFirst(RegExp(r'^>\s?'), ''));
          i++;
        }
        widgets.add(style.blockquote(buf.join('\n')));
        continue;
      }
      // Table: gather consecutive `|` lines.
      if (trimmed.startsWith('|')) {
        final rows = <List<String>>[];
        while (i < lines.length && lines[i].trimLeft().startsWith('|')) {
          rows.add(_tableCells(lines[i]));
          i++;
        }
        widgets.add(style.table(rows));
        continue;
      }
      // Horizontal rule.
      if (hr.hasMatch(lines[i])) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          ),
        );
        i++;
        continue;
      }
      // List item.
      if (bullet.hasMatch(trimmed)) {
        widgets.add(style.bullet(trimmed.replaceFirst(bullet, '')));
        i++;
        continue;
      }
      // Paragraph: join consecutive plain lines (soft wraps).
      final buf = <String>[trimmed];
      i++;
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          !_startsBlock(lines[i])) {
        buf.add(lines[i].trim());
        i++;
      }
      widgets.add(style.paragraph(buf.join(' ')));
    }
    return widgets;
  }

  /// True when [line] opens a block handled above (used to end paragraphs).
  static bool _startsBlock(String line) {
    final t = line.trimLeft();
    if (t.isEmpty) return true;
    if (t.startsWith('```') || t.startsWith('>') || t.startsWith('|')) {
      return true;
    }
    if (RegExp(r'^#{1,4}\s').hasMatch(t)) return true;
    if (RegExp(r'^\s*(-{3,}|\*{3,}|_{3,})\s*$').hasMatch(line)) return true;
    if (RegExp(r'^(\s*([-*•]|\d+[.)])\s+)').hasMatch(t)) return true;
    return false;
  }

  /// Split a `| a | b |` row into cells, dropping the outer pipes.
  static List<String> _tableCells(String line) {
    var cells = line.trim().split('|').map((c) => c.trim()).toList();
    if (cells.isNotEmpty && cells.first.isEmpty) {
      cells = cells.sublist(1);
    }
    if (cells.isNotEmpty && cells.last.isEmpty) {
      cells = cells.sublist(0, cells.length - 1);
    }
    return cells;
  }
}

/// Markdown-aware PDF styles sharing the embedded fonts.
class _MdStyle {
  final pw.Font regular;
  final pw.Font bold;

  static const double _body = 11;

  _MdStyle(this.regular, this.bold);

  pw.TextStyle _base({
    double size = _body,
    bool bold = false,
    bool italic = false,
  }) => pw.TextStyle(
    font: bold ? this.bold : regular,
    fontSize: size,
    fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
  );

  /// Inline `**bold**`, `*italic*`, `` `code` ``, `~~strike~~` as spans.
  List<pw.TextSpan> inline(String s, {double size = _body}) {
    final spans = <pw.TextSpan>[];
    final token = RegExp(r'`[^`\n]+`|\*\*[^*\n]+\*\*|\*[^*\n]+\*|~~[^~\n]+~~');
    var last = 0;
    void push(
      String chunk, {
      bool b = false,
      bool i = false,
      bool code = false,
      bool strike = false,
    }) {
      if (chunk.isEmpty) return;
      spans.add(
        pw.TextSpan(
          text: chunk,
          style: pw.TextStyle(
            font: b ? bold : regular,
            fontSize: code ? size - 1 : size,
            fontStyle: i ? pw.FontStyle.italic : pw.FontStyle.normal,
            background: code
                ? pw.BoxDecoration(color: PdfColors.grey200)
                : null,
            decoration: strike ? pw.TextDecoration.lineThrough : null,
          ),
        ),
      );
    }

    for (final m in token.allMatches(s)) {
      if (m.start > last) {
        push(s.substring(last, m.start));
      }
      final tok = m.group(0)!;
      if (tok.startsWith('`')) {
        push(tok.substring(1, tok.length - 1), code: true);
      } else if (tok.startsWith('**')) {
        push(tok.substring(2, tok.length - 2), b: true);
      } else if (tok.startsWith('~~')) {
        push(tok.substring(2, tok.length - 2), strike: true);
      } else {
        push(tok.substring(1, tok.length - 1), i: true);
      }
      last = m.end;
    }
    if (last < s.length) push(s.substring(last));
    return spans;
  }

  pw.Widget rich(
    String s, {
    double size = _body,
    bool bold = false,
    bool italic = false,
  }) {
    final spans = inline(s, size: size);
    if (bold || italic) {
      return pw.RichText(
        text: pw.TextSpan(
          children: spans,
          style: _base(size: size, bold: bold, italic: italic),
        ),
      );
    }
    return pw.RichText(
      text: pw.TextSpan(
        children: spans,
        style: _base(size: size),
      ),
    );
  }

  pw.Widget heading(String s, int level) => pw.Padding(
    padding: pw.EdgeInsets.only(top: level == 1 ? 12 : 8, bottom: 4),
    child: pw.RichText(
      text: pw.TextSpan(
        children: inline(s, size: level == 1 ? 14 : 12),
        style: _base(size: level == 1 ? 14 : 12, bold: true),
      ),
    ),
  );

  pw.Widget paragraph(String s) =>
      pw.Padding(padding: const pw.EdgeInsets.only(bottom: 6), child: rich(s));

  pw.Widget bullet(String s) => pw.Padding(
    padding: const pw.EdgeInsets.only(left: 12, bottom: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('•  ', style: _base()),
        pw.Expanded(child: rich(s)),
      ],
    ),
  );

  /// Excerpt: tinted block with an accent bar, content in italic.
  pw.Widget blockquote(String s) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border(
          left: pw.BorderSide(color: PdfColors.blue700, width: 2.5),
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: pw.RichText(
        text: pw.TextSpan(children: inline(s), style: _base(italic: true)),
      ),
    ),
  );

  pw.Widget codeBlock(String code) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Container(
      color: PdfColors.grey100,
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(code, style: _base(size: 10)),
    ),
  );

  /// Simple grid table; the `|---|---|` separator row is dropped and the
  /// first row becomes the shaded bold header.
  pw.Widget table(List<List<String>> rows) {
    final data = rows.where((r) => !_isSeparatorRow(r)).toList();
    if (data.isEmpty) return pw.SizedBox();
    final widths = List<int>.generate(data[0].length, (c) {
      var max = 0;
      for (final r in data) {
        if (c < r.length && r[c].length > max) max = r[c].length;
      }
      return max;
    });
    final total = widths.fold<int>(0, (a, b) => a + b);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        columnWidths: {
          for (var c = 0; c < widths.length; c++)
            c: pw.FlexColumnWidth(
              total == 0 ? 1 : (widths[c] / total * widths.length),
            ),
        },
        children: [
          for (var r = 0; r < data.length; r++)
            pw.TableRow(
              decoration: r == 0
                  ? const pw.BoxDecoration(color: PdfColors.grey200)
                  : null,
              children: [
                for (var c = 0; c < data[0].length; c++)
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.RichText(
                      text: pw.TextSpan(
                        children: inline(
                          c < data[r].length ? data[r][c] : '',
                          size: 10,
                        ),
                        style: _base(size: 10, bold: r == 0),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static bool _isSeparatorRow(List<String> cells) {
    if (cells.isEmpty) return false;
    return cells.every((c) => RegExp(r'^:?-{2,}:?$').hasMatch(c));
  }
}
