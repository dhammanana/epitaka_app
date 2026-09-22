/// Align commentary sections with main-text verses by quoted verse text.
///
/// A commentary book may number its `level = 10` sections differently from
/// the mūla book (e.g. Suttanipāta verses 786–793 vs Pj-ii sections
/// 787–794 for Duṭṭhaṭṭhakasuttaṃ). Matching sections by equal numbers then
/// pairs each verse with the wrong commentary. The commentary does quote
/// the verse it explains, so the anchor section is found by text instead:
/// the candidate whose opening lines share the longest letter-run with the
/// verse wins. Numbers are still used for the initial guess; the quote
/// match only adjusts to a neighbouring section when it scores well.
library;

/// Letters kept from a verse line to build its match key.
const int quoteMatchKeyLen = 32;

/// Minimum shared letter-run for a quote match to count. Stock phrases
/// (`tassa`, `…ti`) stay well below this; a real verse quote scores 20+.
const int quoteMatchThreshold = 14;

/// Minimum key length below which no matching is attempted.
const int quoteMatchMinKeyLen = 10;

/// Normalized match key for a verse line: tags/numbers stripped,
/// lowercased, diacritics folded, letters only, truncated.
String quoteMatchKey(String raw) {
  final n = _normalize(raw);
  return n.length <= quoteMatchKeyLen ? n : n.substring(0, quoteMatchKeyLen);
}

/// Score of a candidate commentary section: longest common letter-run
/// between the verse [key] and the candidate's opening [windowText].
int quoteMatchScore(String key, String windowText) {
  if (key.isEmpty) return 0;
  final w = _normalize(windowText);
  if (w.isEmpty) return 0;
  var best = 0;
  var prev = List<int>.filled(w.length + 1, 0);
  for (var i = 0; i < key.length; i++) {
    final cur = List<int>.filled(w.length + 1, 0);
    for (var j = 0; j < w.length; j++) {
      if (key.codeUnitAt(i) == w.codeUnitAt(j)) {
        cur[j + 1] = prev[j] + 1;
        if (cur[j + 1] > best) best = cur[j + 1];
      }
    }
    prev = cur;
  }
  return best;
}

String _normalize(String raw) {
  var s = raw.replaceAll(RegExp(r'<[^>]*>'), ' ');
  s = s.replaceFirst(RegExp(r'^\s*\d+\s*[\.\)]\s*'), '');
  s = s.toLowerCase();
  final buf = StringBuffer();
  for (final rune in s.runes) {
    final c = String.fromCharCode(rune);
    final folded = _folds[c] ?? c;
    if (folded.codeUnitAt(0) >= 97 && folded.codeUnitAt(0) <= 122) {
      buf.write(folded);
    }
  }
  return buf.toString();
}

const Map<String, String> _folds = {
  'ā': 'a',
  'ī': 'i',
  'ū': 'u',
  'ṃ': 'm',
  'ṁ': 'm',
  'ñ': 'n',
  'ṅ': 'n',
  'ṇ': 'n',
  'ḍ': 'd',
  'ṭ': 't',
  'ḷ': 'l',
  'ē': 'e',
  'ō': 'o',
  'ṛ': 'r',
  'ṝ': 'r',
  'ṣ': 's',
  'ś': 's',
  'ḥ': 'h',
};
