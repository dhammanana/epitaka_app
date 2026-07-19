import 'dart:collection';
import 'dart:developer' as developer;

import 'pali_script_converter.dart';

/// Returns the best font family name for displaying text in [script].
///
/// Uses the script-specific fonts bundled in `assets/fonts/` when available,
/// falling back to a general-purpose font otherwise.
///
/// For scripts that don't yet have a dedicated bundled font (Thai, Khmer,
/// Tibetan, Bengali, etc.) this returns `null` so Flutter falls back to the
/// platform's default font — which includes proper rendering (and correct
/// combining-mark shaping) for those scripts. Returning a Latin font such as
/// `NotoSerif` here would drop the script's vowel signs / tone marks, since
/// that font has no glyphs for them.
String? scriptFontFamily(Script script) {
  switch (script) {
    case Script.sinhala:
      return 'NotoSansSinhala';
    case Script.devanagari:
      return 'NotoSansDevanagari';
    case Script.roman:
      return 'NotoSerif';
    case Script.taitham:
      return 'NotoSansTaiTham';
    case Script.myanmar:
      return 'Pyidaungsu';
    case Script.laos:
      // Use LaoPaliRegular (not NotoSansLao) because NotoSansLao lacks
      // the Pali-specific Lao characters (e.g. ຆ LAO LETTER PALI GH,
      // ຉ LAO LETTER PALI CH, etc.) which are needed for Pali text.
      return 'LaoPaliRegular';
    case Script.brahmi:
      return 'NotoSansBrahmi';
    case Script.cyrillic:
      return 'DejaVuSans';
    case Script.bengali:
    case Script.gurmukhi:
    case Script.gujarati:
    case Script.telugu:
    case Script.kannada:
    case Script.malayalam:
    case Script.thai:
    case Script.khmer:
    case Script.tibetan:
      // No dedicated font bundled yet — let the platform font handle these
      // scripts (it has the required glyphs and OpenType shaping).
      return null;
  }
}

/// Memoizes [convertPaliToScript] results, keyed by "scriptIndex\u0000text".
///
/// Conversion runs inside widget `build()` (via [PaliText]/[PaliHtmlText]), so
/// the same paragraph text is re-converted on every rebuild. Caching the
/// result avoids repeating the (now map-backed) conversion work for identical
/// text. Bounded to avoid unbounded memory growth across books/sessions.
const int _kConvertCacheCap = 8000;
final Map<String, String> _convertCache = LinkedHashMap<String, String>();

String _cacheConvert(
  String text,
  Script? targetScript,
  String Function() compute,
) {
  final key = '${targetScript?.index ?? -1}\u0000$text';
  final cached = _convertCache[key];
  if (cached != null) return cached;
  final result = compute();
  if (_convertCache.length >= _kConvertCacheCap) {
    // Evict the oldest quarter (FIFO via LinkedHashMap insertion order) to
    // bound memory without dropping every entry at once.
    final removeCount = _kConvertCacheCap ~/ 4;
    final keys = _convertCache.keys.toList();
    for (var i = 0; i < removeCount; i++) {
      _convertCache.remove(keys[i]);
    }
  }
  _convertCache[key] = result;
  return result;
}

/// Converts Roman-script Pāli text (with diacritics) to the target script.
///
/// The database stores Pāli in romanised form (e.g. "ā", "ṭ", "ñ"). When the
/// user chooses a non-Roman script (Sinhala, Thai, Burmese, etc.), this
/// first converts Roman → Sinhala (the internal intermediate format) and
/// then Sinhala → the requested script.
///
/// When [targetScript] is `null` or [Script.roman], the original text is
/// returned unchanged (only beautifyCommon is applied).
String convertPaliToScript(String text, Script? targetScript) {
  if (text.isEmpty) return text;
  if (targetScript == null || targetScript == Script.roman) {
    // For Roman, only apply common beautification (cleanup)
    return TextProcessor.beautify(text, Script.roman);
  }

  // Step 1: Roman → Sinhala (internal intermediate). This intermediate is
  // independent of the target script, so cache it under Script.roman.
  final sinhalaText = _cacheConvert(text, Script.roman, () {
    final out = TextProcessor.convertFrom(text, Script.roman);
    return out;
  });

  if (sinhalaText.isEmpty) return text;

  // Step 2: Sinhala → target script
  return _cacheConvert(sinhalaText, targetScript, () {
    final out = TextProcessor.convert(sinhalaText, targetScript!);
    return out;
  });
}

/// Like [convertPaliToScript] but preserves HTML tags.
///
/// Extracts HTML tags (e.g. `<b>`, `</b>`, `<i>...</i>`) before conversion
/// and re-inserts them after, so only the Pāli text between tags is
/// converted. This prevents corruption of HTML markup during script
/// conversion.
String convertPaliToScriptPreservingHtml(String text, Script? targetScript) {
  if (text.isEmpty) return text;
  if (targetScript == null || targetScript == Script.roman) {
    // Apply standard beautification for Roman (same as convertPaliToScript)
    return convertPaliToScript(text, targetScript);
  }

  // Split into segments alternating between: text, <tag ...>, text, </tag>, ...
  // We preserve all tag content (including attributes) as-is.
  final segments = <String>[];
  int lastEnd = 0;
  final tagPattern = RegExp(r'<[^>]*>');

  for (final match in tagPattern.allMatches(text)) {
    // Add text before this tag
    if (match.start > lastEnd) {
      final segment = text.substring(lastEnd, match.start);
      if (segment.isNotEmpty) {
        segments.add(segment);
      }
    }
    // Add the tag itself (preserved as-is)
    segments.add(match.group(0)!);
    lastEnd = match.end;
  }

  // Add remaining text after the last tag
  if (lastEnd < text.length) {
    final remaining = text.substring(lastEnd);
    if (remaining.isNotEmpty) {
      segments.add(remaining);
    }
  }

  // If no HTML tags, fall through to standard conversion
  if (segments.length == 1 && !segments[0].startsWith('<')) {
    final sw = Stopwatch()..start();
    final out = convertPaliToScript(text, targetScript);
    sw.stop();
    if (sw.elapsedMicroseconds > 1500) {
      developer.log(
        '[SCRIPT] convert (no-html) ${sw.elapsedMicroseconds}µs len=${text.length}',
        name: 'epitaka.perf',
      );
    }
    return out;
  }

  // Convert only non-tag segments (even-indexed segments are tags)
  final sw = Stopwatch()..start();
  final result = segments
      .map((segment) {
        if (segment.startsWith('<') && segment.endsWith('>')) {
          return segment; // preserve HTML tag as-is
        }
        return convertPaliToScript(segment, targetScript);
      })
      .join('');
  sw.stop();
  if (sw.elapsedMicroseconds > 1500) {
    developer.log(
      '[SCRIPT] convert (html) ${sw.elapsedMicroseconds}µs len=${text.length} '
      'segments=${segments.length}',
      name: 'epitaka.perf',
    );
  }

  return result;
}

/// Converts a search [query] (in Roman Pali) to [script] so that the
/// converted terms can be matched against Pāli text that was also converted
/// to the same [script].
///
/// Example: searching for "dhamma" in Sinhala script will convert each
/// Roman word to its Sinhala equivalent before highlighting, so "dhamma"
/// matches "ධම්ම" in the converted Pali text.
///
/// When [script] is Roman, the query is returned unchanged.
String convertSearchQueryForScript(String query, Script script) {
  if (query.isEmpty || script == Script.roman) return query;

  // Convert each word individually to preserve word boundaries
  final words = query.split(RegExp(r'\s+'));
  final converted = words
      .map((w) {
        if (w.trim().isEmpty) return w;
        return convertPaliToScript(w.trim(), script);
      })
      .join(' ');

  return converted;
}
