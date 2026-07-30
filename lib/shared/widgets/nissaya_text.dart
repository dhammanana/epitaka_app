import 'package:flutter/material.dart';

/// A parsed pair: Pāli word and its meaning translation.
class NissayaPair {
  final String pali;
  final String meaning;
  const NissayaPair({required this.pali, required this.meaning});
}

/// A utility for detecting and rendering nissaya-formatted text.
///
/// Nissaya content follows the pattern:
///   `pali_word: meaning_word | pali_word2: meaning_word2 | ...`
///
/// This parser extracts the pairs for styled rendering where each
/// Pāli word is emphasized (italic) and the meaning is in normal style.
class NissayaTextParser {
  /// The separator between word pairs.
  static const String pairSeparator = ' | ';

  /// The separator within a pair between pali and meaning.
  static const String wordSeparator = ': ';

  /// Detect whether [text] is nissaya-formatted (contains " | " pattern).
  static bool isNissayaFormat(String text) {
    return text.contains(pairSeparator) && text.contains(wordSeparator);
  }

  /// LRU cache for parsed nissaya text to avoid re-parsing on rebuilds.
  static final Map<String, List<NissayaPair>> _parseCache = {};
  static const int _parseCacheLimit = 1000;

  /// Parse nissaya-formatted [text] into a list of [NissayaPair]s.
  ///
  /// Returns an empty list if the text doesn't match nissaya format.
  static List<NissayaPair> parse(String text) {
    if (text.isEmpty || !isNissayaFormat(text)) return [];

    final cached = _parseCache[text];
    if (cached != null) return cached;

    final pairs = <NissayaPair>[];
    final parts = text.split(pairSeparator);

    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      // Find the first ": " to split pali from meaning
      final colonIdx = trimmed.indexOf(': ');
      if (colonIdx > 0) {
        final pali = trimmed.substring(0, colonIdx).trim();
        final meaning = trimmed.substring(colonIdx + 2).trim();
        if (pali.isNotEmpty) {
          pairs.add(NissayaPair(pali: pali, meaning: meaning));
        }
      } else if (trimmed.isNotEmpty) {
        // No colon found — treat as meaning-only
        pairs.add(NissayaPair(pali: '', meaning: trimmed));
      }
    }

    if (_parseCache.length >= _parseCacheLimit) {
      _parseCache.remove(_parseCache.keys.first);
    }
    _parseCache[text] = pairs;
    return pairs;
  }
}

/// Renders nissaya-formatted text (e.g. "pali: meaning | pali: meaning")
/// with Pāli words styled with emphasis (italic, slightly bolder) and
/// meanings in normal style, separated by thin dividers.
///
/// If the text doesn't match nissaya format, renders it as plain text
/// using the provided [plainStyle].
class NissayaText extends StatelessWidget {
  /// The nissaya-formatted text to render.
  final String text;

  /// Base style applied to the entire text. The Pāli parts inherit
  /// [baseStyle] with italic and slightly heavier weight added.
  final TextStyle baseStyle;

  /// Fallback style used when [text] does not match nissaya format.
  final TextStyle plainStyle;

  /// Color for the " | " separator pipes.
  final Color? separatorColor;

  const NissayaText({
    super.key,
    required this.text,
    this.baseStyle = const TextStyle(fontSize: 17),
    this.plainStyle = const TextStyle(fontSize: 17),
    this.separatorColor,
  });

  @override
  Widget build(BuildContext context) {
    final pairs = NissayaTextParser.parse(text);

    if (pairs.isEmpty) {
      // Not nissaya format — render as plain text
      return Text(text, style: plainStyle);
    }

    final effectiveSepColor =
        separatorColor ??
        baseStyle.color?.withValues(alpha: 0.4) ??
        Colors.grey.withValues(alpha: 0.4);

    final paliStyle = baseStyle.copyWith(
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w600,
    );
    final meaningStyle = baseStyle;
    final separatorStyle = baseStyle.copyWith(color: effectiveSepColor);

    final spans = <InlineSpan>[];
    for (int i = 0; i < pairs.length; i++) {
      final pair = pairs[i];

      if (pair.pali.isNotEmpty) {
        spans.add(TextSpan(text: pair.pali, style: paliStyle));
        if (pair.meaning.isNotEmpty) {
          spans.add(TextSpan(text: ': ', style: meaningStyle));
          spans.add(TextSpan(text: pair.meaning, style: meaningStyle));
        }
      } else {
        // No pali, just meaning
        spans.add(TextSpan(text: pair.meaning, style: meaningStyle));
      }

      // Add separator pipe between pairs
      if (i < pairs.length - 1) {
        spans.add(TextSpan(text: ' | ', style: separatorStyle));
      }
    }

    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }
}
