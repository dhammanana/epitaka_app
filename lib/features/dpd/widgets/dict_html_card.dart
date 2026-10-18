import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:url_launcher/url_launcher.dart';

import '../../dictionary/providers/dictionary_font_scale_provider.dart';
import '../../dictionary/widgets/dictionary_search_shared.dart'
    show DictHtmlContent;
import '../database/dpd_database.dart';
import '../theme/dpd_colors.dart';
import '../theme/dpd_palette.dart';
import '../utils/text_filters.dart';

final _hTagRe = RegExp(r'<strong>\((?:H\d[A-Z]?|C\d)\)</strong>\s*');
final _docWrapRe = RegExp(
  r'<!DOCTYPE[^>]*>.*?<body>|</body>.*?</html>',
  dotAll: true,
  caseSensitive: false,
);

final _tooltipSpanRe = RegExp(
  r'''<span([^>]*?\bclass="[^"]*\bls\b[^"]*"[^>]*?)\btitle=["']([^"']+)["']([^>]*)>(.*?)</span>''',
  dotAll: true,
);

final _cpdH2OpenRe = RegExp(r'<h2\b[^>]*>', caseSensitive: false);
final _cpdH2CloseRe = RegExp(r'</h2>', caseSensitive: false);

String _prepareConeHtml(String html) {
  final doc = parse(html);
  doc.querySelector('div.lemma')?.remove();
  final highlights = doc.querySelectorAll('.subsense.highlight');
  if (highlights.isNotEmpty) {
    final buffer = StringBuffer();
    for (final el in highlights) {
      el.classes.remove('highlight');
      buffer.write(el.outerHtml);
    }
    return buffer.toString();
  }
  return doc.body?.innerHtml ?? html;
}

String _cleanMwHtml(String html) {
  html = html.replaceAll(_docWrapRe, '');
  html = html.replaceAll(_hTagRe, '');
  html = html.replaceAllMapped(_tooltipSpanRe, (m) {
    final before = m[1]!;
    final title = m[2]!;
    final after = m[3]!;
    final content = m[4]!;
    final encoded = Uri.encodeComponent(title);
    return '<a href="tooltip:$encoded"><span$before$after>$content</span></a>';
  });
  return html;
}

final _dppnHeadRe = RegExp(r'<span class="Head">(.*?)</span>', dotAll: true);
final _tagRe = RegExp(r'<[^>]+>');
final _wsRe = RegExp(r'\s+');
final _leadingPunctRe = RegExp(r'^[,.;:]');

/// DPPN keeps alternative names, variant readings and reference numbers on the
/// head line beside the headword. They belong with the title, not stranded at
/// the start of the definition, so [prepareDictHtml] drops that span from the
/// body and this rebuilds the title from it.
String dppnDisplayTitle(String word, String html) {
  final match = _dppnHeadRe.firstMatch(html);
  if (match == null) return word;

  var extra = match[1]!
      .replaceAll(_tagRe, '')
      .replaceAll(_wsRe, ' ')
      .trim()
      .replaceAll('..', '.');
  if (extra.isEmpty || extra == '.') return word;

  return _leadingPunctRe.hasMatch(extra) ? '$word$extra' : '$word $extra';
}

String prepareDictHtml(String dictId, String html) {
  if (dictId == 'cone') return _prepareConeHtml(html);
  if (dictId == 'mw' || dictId == 'apte') return _cleanMwHtml(html);
  if (dictId == 'dppn') return html.replaceFirst(_dppnHeadRe, '');
  if (dictId == 'cpd') {
    html = html.replaceAll(_cpdH2OpenRe, '<strong>');
    html = html.replaceAll(_cpdH2CloseRe, '</strong>');
  }
  return html;
}

/// Writes the DPD style rules into [html] as inline `style` attributes.
///
/// The DPD app hands its rules to `flutter_widget_from_html` as a callback.
/// ePitaka renders with `flutter_html`, which does not take one, so each rule
/// is applied to its element here before rendering. A `px` or `pt` size in a
/// rule is multiplied by [scale], so small print follows the dictionary text
/// size. A rule the renderer cannot read is dropped by it (`font-variant`,
/// `font-size: smaller`).
String applyDictStyles(
  String html,
  Map<String, String>? Function(dom.Element) stylesBuilder, {
  double scale = 1.0,
}) {
  final doc = parse(html);
  for (final element in doc.querySelectorAll('*')) {
    final rules = stylesBuilder(element);
    if (rules == null) continue;
    final css = [
      for (final e in rules.entries) '${e.key}:${_scaleLength(e.value, scale)}',
    ].join(';');
    final existing = element.attributes['style'];
    element.attributes['style'] = existing == null || existing.isEmpty
        ? css
        : '$css;$existing';
  }
  return doc.body?.innerHtml ?? html;
}

final _absoluteLengthRe = RegExp(r'^(\d+(?:\.\d+)?)(px|pt)$');

String _scaleLength(String value, double scale) {
  if (scale == 1.0) return value;
  final m = _absoluteLengthRe.firstMatch(value);
  if (m == null) return value;
  return '${(double.parse(m[1]!) * scale).toStringAsFixed(2)}${m[2]}';
}

/// The entries of one external dictionary for one word: each headword, then
/// its HTML. The dictionary's own title is on the collapsible card around it,
/// so unlike the DPD app's card there is no title block here.
class DictHtmlCard extends ConsumerStatefulWidget {
  const DictHtmlCard({
    super.key,
    required this.dictId,
    required this.entries,
    required this.baseStyle,
  });

  final String dictId;
  final List<DictEntry> entries;

  /// Size, line height, colour and font family of the entry text.
  final TextStyle baseStyle;

  @override
  ConsumerState<DictHtmlCard> createState() => _DictHtmlCardState();
}

class _DictHtmlCardState extends ConsumerState<DictHtmlCard> {
  String get dictId => widget.dictId;
  List<DictEntry> get entries => widget.entries;
  TextStyle get baseStyle => widget.baseStyle;

  /// Where the pointer last went down, so a tooltip can open beside the link
  /// that was tapped.
  Offset? _lastDown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scale = ref.watch(dictionaryFontScaleProvider);
    final stylesBuilder = _buildStylesBuilder(isDark, context.palette);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _lastDown = e.position,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in entries) ...[
            ..._buildEntryWidgets(context, entry, stylesBuilder, scale),
            if (entry != entries.last) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildEntryWidgets(
    BuildContext context,
    DictEntry entry,
    Map<String, String>? Function(dom.Element) stylesBuilder,
    double scale,
  ) {
    final raw = entry.definitionHtml ?? '';
    final html = applyDictStyles(
      context.nigg(prepareDictHtml(dictId, raw)),
      stylesBuilder,
      scale: scale,
    );
    final title = dictId == 'dppn'
        ? dppnDisplayTitle(entry.word, raw)
        : entry.word;

    return [
      Text(
        context.nigg(title),
        style: baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 14) * 1.25,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      DictHtmlContent(
        html: html,
        baseStyle: baseStyle,
        onLinkTap: (url) {
          if (url.startsWith('tooltip:')) {
            final text = context.nigg(Uri.decodeComponent(url.substring(8)));
            _showTooltip(
              context,
              text,
              at: _lastDown,
              fontSize: (baseStyle.fontSize ?? 14) * 0.8,
            );
            return;
          }
          final uri = Uri.tryParse(url);
          if (uri != null && uri.hasScheme) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ),
    ];
  }
}

Map<String, String>? Function(dom.Element) _buildStylesBuilder(bool isDark, DpdPalette palette) {
  final lemmaColor = _colorToCSS(
    isDark ? palette.primaryTextDark : palette.primaryText,
  );
  final highlightBg = _colorToCSS(
    palette.primaryAlt.withValues(alpha: 0.4),
  );
  final highlightText = isDark ? 'black' : 'white';

  final blueColor = _colorToCSS(
    isDark ? palette.primaryTextDark : palette.primaryText,
  );
  final redColor = _colorToCSS(
    isDark ? palette.accentRedDark : palette.accentRed,
  );
  final greenColor = _colorToCSS(
    isDark ? palette.accentGreenDark : palette.accentGreen,
  );
  final orangeColor = _colorToCSS(
    isDark ? palette.accentOrangeDark : palette.accentOrange,
  );
  final purpleColor = _colorToCSS(
    isDark ? palette.accentPurpleDark : palette.accentPurple,
  );
  final brownColor = _colorToCSS(
    isDark ? palette.accentBrownDark : palette.accentBrown,
  );
  final grayColor = _colorToCSS(isDark ? palette.grayLight : palette.gray);

  return (dom.Element element) {
    final classes = element.classes;
    final tag = element.localName;

    if (tag == 'a') {
      final href = element.attributes['href'] ?? '';
      if (href.startsWith('tooltip:')) {
        return {'text-decoration': 'none', 'color': 'inherit'};
      }
    }

    if (tag == 'div' && classes.contains('lemma')) {
      return {
        'font-size': '15pt',
        'line-height': '17pt',
        'font-weight': '600',
        'color': lemmaColor,
      };
    }
    if (classes.contains('lemma') && tag == 'span') {
      return {'color': lemmaColor, 'font-weight': '600'};
    }
    if (classes.contains('lemsuper')) {
      return {'font-size': '10px', 'vertical-align': 'super'};
    }
    if (classes.contains('morph')) {
      return {'font-style': 'italic'};
    }
    if (classes.contains('super') || classes.contains('qsuper')) {
      return {'font-size': '8px', 'vertical-align': 'super'};
    }
    if (classes.contains('subscript')) {
      return {'font-size': '8px', 'vertical-align': 'sub'};
    }
    if (classes.contains('subsense') && classes.contains('highlight')) {
      return {
        'display': 'inline',
        'background-color': highlightBg,
        'color': highlightText,
      };
    }
    if (classes.contains('subsense')) {
      return {'display': 'inline'};
    }
    if (classes.contains('highlight')) {
      return {'background-color': highlightBg, 'color': highlightText};
    }
    if (classes.contains('bold') ||
        classes.contains('sb') ||
        classes.contains('attestedform') ||
        classes.contains('cref')) {
      return {'font-weight': 'bold'};
    }
    if (classes.contains('italic') ||
        classes.contains('s') ||
        classes.contains('cognate')) {
      return {'font-style': 'italic'};
    }
    if (classes.contains('smallcaps') ||
        classes.contains('scaps') ||
        classes.contains('txtabbrev') ||
        classes.contains('easian')) {
      return {'font-variant': 'small-caps'};
    }
    if (classes.contains('blue')) {
      return {'color': blueColor};
    }
    if (classes.contains('orange')) {
      return {'color': orangeColor};
    }
    if (classes.contains('green')) {
      return {'color': greenColor};
    }
    if (classes.contains('red')) {
      return {'color': redColor};
    }
    if (classes.contains('purple')) {
      return {'color': purpleColor};
    }
    if (classes.contains('dim')) {
      return {'color': blueColor};
    }
    if (classes.contains('kharHide')) {
      return {'display': 'none'};
    }
    if (classes.contains('id')) {
      return {'font-size': '10px'};
    }
    if (classes.contains('more')) {
      return {'color': grayColor, 'font-style': 'italic', 'font-size': '12px'};
    }

    // MW (Monier-Williams) — themed from mw.css
    if (classes.contains('sdata')) {
      return {'color': blueColor, 'font-style': 'italic'};
    }
    if (classes.contains('hom')) {
      return {'color': redColor};
    }
    if (classes.contains('ls')) {
      return {'color': blueColor, 'font-size': '10pt'};
    }
    if (classes.contains('gram') ||
        classes.contains('divm') ||
        classes.contains('fn-label')) {
      return {'font-weight': 'bold'};
    }
    if (classes.contains('greek')) {
      return {'font-style': 'italic'};
    }
    if (classes.contains('dotunder')) {
      return null;
    }
    if (classes.contains('lnum')) {
      return {
        'font-size': 'smaller',
        'background-color': _colorToCSS(
          isDark ? palette.darkShade : palette.lightShade,
        ),
      };
    }
    if (classes.contains('g') || classes.contains('lang')) {
      return {'font-size': 'smaller', 'font-style': 'italic'};
    }
    if (classes.contains('pb') ||
        classes.contains('footnote') ||
        classes.contains('alt-hw')) {
      return {'font-size': 'smaller'};
    }
    if (classes.contains('foreign')) {
      return {'color': brownColor};
    }
    if (classes.contains('div-sep')) {
      return {'margin-top': '0.6em'};
    }
    if (classes.contains('in1')) {
      return {'margin-left': '1em'};
    }
    if (classes.contains('pcol-ref')) {
      return {'color': grayColor, 'font-size': 'smaller'};
    }
    if (classes.contains('record-id')) {
      return {'color': grayColor};
    }

    return null;
  };
}

/// Opens the full name of an abbreviation beside the tap at [at] (below it,
/// or above it near the bottom of the screen), kept on screen. With no point it
/// opens in the middle.
void _showTooltip(
  BuildContext context,
  String text, {
  Offset? at,
  required double fontSize,
}) {
  final overlay = Overlay.of(context);
  final overlayBox = overlay.context.findRenderObject() as RenderBox?;
  if (overlayBox == null) return;
  final local = at == null ? null : overlayBox.globalToLocal(at);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      final overlayPalette = ctx.palette;
      return GestureDetector(
        onTap: () => entry.remove(),
        behavior: HitTestBehavior.translucent,
        child: CustomSingleChildLayout(
          delegate: _TooltipLayout(local),
          child: Material(
            elevation: 4,
            borderRadius: DpdColors.borderRadius,
            color: overlayPalette.primaryAlt,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  text,
                  style: TextStyle(color: overlayPalette.light, fontSize: fontSize),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 3), () {
    if (entry.mounted) entry.remove();
  });
}

/// Puts a tooltip centred on the tap, 18 px below it, flipped above it when
/// there is no room below, and always inside the overlay.
class _TooltipLayout extends SingleChildLayoutDelegate {
  _TooltipLayout(this.tap);

  final Offset? tap;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final at = tap ?? Offset(size.width / 2, size.height / 3);
    final maxX = size.width - childSize.width - 8;
    final x = (at.dx - childSize.width / 2).clamp(8.0, maxX < 8 ? 8.0 : maxX);
    var y = at.dy + 18;
    if (y + childSize.height > size.height - 8) {
      y = at.dy - childSize.height - 18;
    }
    return Offset(x, y.clamp(8.0, double.infinity));
  }

  @override
  bool shouldRelayout(_TooltipLayout old) => old.tap != tap;
}

String _colorToCSS(Color c) {
  return 'rgb(${(c.r * 255).round()}, ${(c.g * 255).round()}, ${(c.b * 255).round()})';
}
