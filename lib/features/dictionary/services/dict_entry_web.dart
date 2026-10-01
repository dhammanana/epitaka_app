import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Helpers for rendering `dictionary`-table entries (the non-DPD books) with
/// the same WebView path the MDX dictionaries use.
///
/// Entries stored in the `dictionary` table are HTML fragments built from a
/// small set of classes:
///
/// ```html
/// <p class="word">အဗ္ဘုတဓမ္မ <span class="gender">(ပု)</span></p>
/// <div class="viggaha"><p>[အဗ္ဘုတ+ဓမ္မ]</p></div>
/// <div class="definition"><p>…</p><ul><li>…</li></ul></div>
/// <p class="reference">တိပိ၊၂၊၈၇၁</p>
/// ```
///
/// `flutter_html` only styles by tag name, so these classes rendered as
/// indistinguishable plain text. The WebView document below gives each class
/// a distinct treatment (headword, etymology box, definition body, source
/// reference, gender pill) with colours injected from the current
/// [ColorScheme], so every app theme (light/dark/sepia/…) renders correctly.
String buildDictEntryDocument({
  required List<String> bodies,
  required double fontSize,
  required String? fontFamily,
  String genericFamily = 'sans-serif',
  required Color primary,
  required Color onSurface,
  required Color onSurfaceVariant,
  required Color outlineVariant,
  required Color containerLow,
}) {
  final primaryHex = _hex(primary);
  final onSurfaceHex = _hex(onSurface);
  final variantHex = _hex(onSurfaceVariant);
  final outlineHex = _hex(outlineVariant);
  final containerHex = _hex(containerLow);
  final family = (fontFamily ?? '').trim().replaceAll("'", '');
  final familyCss =
      family.isEmpty ? genericFamily : "'$family', $genericFamily";

  final buf = StringBuffer(
    '<!DOCTYPE html><html><head>'
    '<meta charset="utf-8">'
    '<meta name="viewport" content="width=device-width, initial-scale=1">'
    '<meta name="color-scheme" content="light dark">'
    '<style>'
    'html,body{background:transparent;margin:0;padding:0}'
    'body{font-family:$familyCss;font-size:${fontSize.toStringAsFixed(1)}px;'
    'line-height:1.55;color:$onSurfaceHex;overflow-wrap:anywhere}'
    // One card per looked-up record; subsequent records are separated.
    '.dict-entry{padding:2px 0}'
    '.dict-entry+.dict-entry{border-top:1px solid $outlineHex;'
    'margin-top:10px;padding-top:10px}'
    // Headword: large, bold, in the theme accent colour.
    '.word{font-size:1.12em;font-weight:700;color:$primaryHex;'
    'margin:0 0 6px;line-height:1.4}'
    // Gender tag, e.g. (ပု) / (တိ): a small pill after the headword.
    '.gender{display:inline-block;font-size:.72em;font-weight:600;'
    'color:$variantHex;border:1px solid $outlineHex;border-radius:999px;'
    'padding:1px 9px;margin-left:8px;vertical-align:middle;white-space:nowrap}'
    // Etymology breakdown [a+b+c]: tinted box with an accent bar.
    '.viggaha{background:$containerHex;border-left:3px solid $primaryHex;'
    'border-radius:0 8px 8px 0;padding:7px 12px;margin:8px 0;'
    'font-size:.94em;color:$variantHex}'
    '.viggaha p{margin:0}'
    // Definition body and its sense lists.
    '.definition{margin:5px 0}'
    '.definition ul{margin:6px 0;padding-left:22px}'
    '.definition li{margin:0 0 4px}'
    '.definition li::marker{color:$primaryHex;font-weight:700}'
    // Source reference (တိပိ၊၂၊၈၇၁): small muted line, right aligned.
    'p.reference{display:block;font-size:.8em;font-style:italic;'
    'color:$variantHex;text-align:right;margin:8px 0 2px;opacity:.9}'
    'p.reference::before{content:"\\2014 "}'
    'b,strong{font-weight:700}'
    'i,em{font-style:italic}'
    'a{color:$primaryHex;text-decoration:none}'
    'img{max-width:100%;height:auto}'
    '</style>'
    '</head><body style="background:transparent">',
  );
  for (final body in bodies) {
    buf.write('<div class="dict-entry">');
    buf.write(body);
    buf.write('</div>');
  }
  return (buf..write('</body></html>')).toString();
}

/// No-op resource reader for dictionary entries: entry HTML references no
/// bundled resources, so the WebView asset handler always misses.
Future<Uint8List?> dictEntryNoResource(String _) async => null;

// ── flutter_html fallback (Linux / web, where WebView is unsupported) ───────

/// Injects inline styles for the dictionary-table classes so the
/// tag-based `flutter_html` renderer still distinguishes headword,
/// etymology, reference and gender. Applied only on platforms without
/// WebView support; the WebView path above uses real CSS instead.
String applyDictEntryFallbackStyles(
  String html, {
  required Color primary,
  required Color onSurfaceVariant,
  required Color containerLow,
}) {
  final primaryHex = _hex(primary);
  final variantHex = _hex(onSurfaceVariant);
  final containerHex = _hex(containerLow);
  var out = html;
  out = _injectInlineStyle(
    out,
    'word',
    'font-weight:700;color:$primaryHex;font-size:115%;margin:0 0 4px 0;',
  );
  out = _injectInlineStyle(
    out,
    'gender',
    'color:$variantHex;font-size:80%;font-style:italic;',
  );
  out = _injectInlineStyle(
    out,
    'viggaha',
    'background-color:$containerHex;color:$variantHex;font-style:italic;'
    'padding:6px 10px;margin:6px 0;',
  );
  out = _injectInlineStyle(
    out,
    'reference',
    'color:$variantHex;font-size:82%;font-style:italic;text-align:right;'
    'margin:6px 0 2px 0;',
  );
  return out;
}

/// Adds [css] as an inline `style` attribute on every tag whose `class`
/// attribute contains [cls]. Tags that already carry a `style` attribute are
/// left untouched.
String _injectInlineStyle(String html, String cls, String css) {
  // Match the whole opening tag so a pre-existing `style` attribute is seen
  // wherever it sits relative to `class`.
  final tagRe = RegExp(
    '<(p|div|span)((?:[^>"\']|"[^"]*"|\'[^\']*\')*)>',
    caseSensitive: false,
  );
  final classRe = RegExp('\\bclass=(["\'])(.*?)\\1');
  final clsRe = RegExp('\\b$cls\\b');
  final styleRe = RegExp(r'\bstyle\s*=');
  return html.replaceAllMapped(tagRe, (m) {
    final attrs = m.group(2)!;
    final classM = classRe.firstMatch(attrs);
    if (classM == null || !clsRe.hasMatch(classM.group(2)!)) {
      return m.group(0)!;
    }
    if (styleRe.hasMatch(attrs)) return m.group(0)!;
    return '<${m.group(1)} style="$css"$attrs>';
  });
}

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
