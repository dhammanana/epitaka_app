String mdxNorm(String s) => s.trim().toLowerCase();

String mdxStripHtml(String html) {
  return html
      .replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '')
      .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'&nbsp;'), ' ')
      .replaceAll(RegExp(r'&amp;'), '&')
      .replaceAll(RegExp(r'&lt;'), '<')
      .replaceAll(RegExp(r'&gt;'), '>')
      .replaceAll(RegExp(r'&quot;'), '"')
      .replaceAll(RegExp(r'&#39;'), "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String mdxSanitize(String html) {
  var out = html.replaceAll(
    RegExp(r'<script[^>]*>.*?</script>', dotAll: true),
    '',
  );
  out = out.replaceAll(RegExp(r'\son\w+\s*=\s*"[^"]*"'), '');
  out = out.replaceAll(RegExp(r"\son\w+\s*=\s*'[^']*'"), '');
  return out.trim();
}

String mdxPreview(String html, [int max = 120]) {
  final plain = mdxStripHtml(html);
  if (plain.length <= max) return plain;
  return '${plain.substring(0, max).trim()}…';
}

/// Caps a definition body at [maxChars]. `null` means uncapped: callers
/// rendering full WebView documents must pass null so long entries (large
/// inlined stylesheets + HTML) are never cut mid-tag, which would leave an
/// unclosed `<style>`/`<script>` and render the card blank.
String mdxApplyMaxChars(String html, int? maxChars) {
  if (maxChars == null || html.length <= maxChars) return html;
  return html.substring(0, maxChars);
}

const String mdxLinkPrefix = '@@@LINK=';

List<String> mdxLinkTargets(String html) {
  final trimmed = html.replaceAll('\uFEFF', '').replaceAll('\u0000', '').trim();
  if (!trimmed.startsWith(mdxLinkPrefix)) return const [];
  return trimmed
      .split(mdxLinkPrefix)
      .skip(1)
      .map((w) => w.trim().split(RegExp(r'[\r\n]')).first.trim())
      .where((w) => w.isNotEmpty)
      .toList(growable: false);
}

List<String> mdxResourceKeys(String key) {
  final slash = key.replaceAll('\\', '/');
  final back = key.replaceAll('/', '\\');
  return <String>{
    key,
    slash,
    back,
    if (key.startsWith('/') || key.startsWith('\\')) key.substring(1),
    if (slash.startsWith('/')) slash.substring(1),
    if (back.startsWith('\\')) back.substring(1),
    if (!key.startsWith('/') && !key.startsWith('\\')) '/$key',
    if (!slash.startsWith('/')) '/$slash',
    if (!back.startsWith('\\')) '\\$back',
  }.toList();
}

final _linkTagRe = RegExp(r'<link\b[^>]*>', caseSensitive: false);
final _linkAttrRe = RegExp(
  '\\b(rel|href)\\s*=\\s*("([^"]*)"|\'([^\']*)\'|([^\\s\'">]+))',
  caseSensitive: false,
);

bool _isStylesheetLink(String tag) {
  String? rel;
  for (final a in _linkAttrRe.allMatches(tag)) {
    if (a.group(1)!.toLowerCase() == 'rel') {
      rel = a.group(3) ?? a.group(4) ?? a.group(5);
    }
  }
  return rel == null || rel.toLowerCase().contains('stylesheet');
}

String? _linkHref(String tag) {
  for (final a in _linkAttrRe.allMatches(tag)) {
    if (a.group(1)!.toLowerCase() == 'href') {
      return a.group(3) ?? a.group(4) ?? a.group(5);
    }
  }
  return null;
}

List<String> mdxStylesheetHrefs(String html) {
  final out = <String>[];
  final seen = <String>{};
  for (final m in _linkTagRe.allMatches(html)) {
    final tag = m.group(0)!;
    if (!_isStylesheetLink(tag)) continue;
    final href = _linkHref(tag)?.trim();
    if (href == null || href.isEmpty) continue;
    if (seen.add(href.toLowerCase())) out.add(href);
  }
  return out;
}

String mdxStripStylesheetLinks(String html) {
  return html
      .replaceAllMapped(
        _linkTagRe,
        (m) => _isStylesheetLink(m.group(0)!) ? '' : m.group(0)!,
      )
      .trim();
}

String mdxSanitizeCss(String css) {
  var out = css.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  out = _balanceCssBraces(out);
  out = _stripCssAtRules(out);
  out = out.replaceAllMapped(
    RegExp(
      r'([{\s;}])[a-z-]+\s*:(?:\s*!important)?\s*(?:;|(?=\s*}))',
      caseSensitive: false,
    ),
    (m) => m.group(1)!,
  );
  out = _dropInvalidSelectorRules(out);
  out = out.replaceAllMapped(
    RegExp(
      r'([{\s;}])display\s*:\s*none-?\s*(!important)?\s*(?:;|(?=\s*}))',
      caseSensitive: false,
    ),
    (m) => m.group(1)!,
  );
  out = out.replaceAllMapped(
    RegExp(
      r'([{\s;}])visibility\s*:\s*hidden-?\s*(!important)?\s*(?:;|(?=\s*}))',
      caseSensitive: false,
    ),
    (m) => m.group(1)!,
  );
  return out;
}

final _atRuleRe = RegExp(r'@(-[a-z]+-)?[a-z]+\b', caseSensitive: false);

String _balanceCssBraces(String css) {
  final buf = StringBuffer();
  var depth = 0;
  var i = 0;
  String? quote;
  var quoteStart = 0;
  while (i < css.length) {
    final c = css[i];
    if (quote != null) {
      buf.write(c);
      if (c == quote && css[i - 1] != '\\') quote = null;
      i++;
      continue;
    }
    if (c == '"' || c == "'") {
      quote = c;
      quoteStart = buf.length;
      buf.write(c);
      i++;
      continue;
    }
    if (c == '{') {
      depth++;
    } else if (c == '}') {
      if (depth == 0) {
        i++;
        continue;
      }
      depth--;
    }
    buf.write(c);
    i++;
  }
  var out = buf.toString();
  if (quote != null) out = out.substring(0, quoteStart);
  final missing = '{'.allMatches(out).length - '}'.allMatches(out).length;
  if (missing > 0) out += '}' * missing;
  return out;
}

final _leadingDigitSelectorRe = RegExp(r'^[.#]?[0-9]');

bool _hasInvalidSelector(String selector) {
  return selector.split(',').any((part) {
    final t = part.trim().split(RegExp(r'\s+')).last;
    final base = t.split(':').first;
    return _leadingDigitSelectorRe.hasMatch(base);
  });
}

String _cleanSelectorDebris(String debris) {
  final lines = debris.split('\n');
  final kept = <String>[];
  for (var i = lines.length - 1; i >= 0; i--) {
    final t = lines[i].trim();
    if (t.isEmpty) continue;
    if (t.contains(';') || t.contains('{') || t.contains('}')) break;
    if (t.startsWith(':') || t.startsWith('@')) break;
    kept.insert(0, t);
    if (!t.endsWith(',')) {
      var j = i - 1;
      while (j >= 0) {
        final prev = lines[j].trim();
        if (prev.isEmpty) {
          j--;
          continue;
        }
        if (!prev.endsWith(',')) break;
        kept.insert(0, prev);
        j--;
      }
      break;
    }
  }
  var selector = kept.join(' ').trim();
  if (selector.endsWith(',')) {
    selector = selector.substring(0, selector.length - 1).trim();
  }
  return selector;
}

String _dropInvalidSelectorRules(String css) {
  final buf = StringBuffer();
  var i = 0;
  while (i < css.length) {
    final open = css.indexOf('{', i);
    if (open < 0) {
      buf.write(css.substring(i));
      break;
    }
    var depth = 0;
    var k = open;
    String? quote;
    while (k < css.length) {
      final c = css[k];
      if (quote != null) {
        if (c == quote && css[k - 1] != '\\') quote = null;
      } else if (c == '"' || c == "'") {
        quote = c;
      } else if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) break;
      }
      k++;
    }
    final rawSelector = css.substring(i, open);
    final selector = _cleanSelectorDebris(rawSelector);
    final end = k >= css.length ? css.length : k + 1;
    if (selector.isEmpty || _hasInvalidSelector(selector)) {
      i = end;
      continue;
    }
    buf.write('$selector${css.substring(open, end)}');
    i = end;
  }
  return buf.toString();
}

bool _isAtRuleBoundary(String css, int at) {
  if (at == 0) return true;
  final prev = css[at - 1];
  return prev == '{' || prev == '}' || prev == ';' || prev.trim().isEmpty;
}

String _stripCssAtRules(String css) {
  final buf = StringBuffer();
  var i = 0;
  while (i < css.length) {
    final at = css.indexOf('@', i);
    if (at < 0) {
      buf.write(css.substring(i));
      break;
    }
    final m = _atRuleRe.matchAsPrefix(css, at);
    if (m == null || !_isAtRuleBoundary(css, at)) {
      buf.write(css.substring(i, at + 1));
      i = at + 1;
      continue;
    }
    final name = m.group(0)!.toLowerCase();
    buf.write(css.substring(i, at));
    var j = m.end;
    while (j < css.length && css[j] != ';' && css[j] != '{') {
      j++;
    }
    if (j >= css.length) break;
    if (css[j] == ';') {
      i = j + 1;
      continue;
    }
    var depth = 0;
    var k = j;
    String? quote;
    while (k < css.length) {
      final c = css[k];
      if (quote != null) {
        if (c == quote && css[k - 1] != '\\') quote = null;
      } else if (c == '"' || c == "'") {
        quote = c;
      } else if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) break;
      }
      k++;
    }
    if (name == '@media' || name == '@supports') {
      buf.write(css.substring(j + 1, k >= css.length ? css.length : k));
    }
    i = k >= css.length ? css.length : k + 1;
  }
  return buf.toString();
}
