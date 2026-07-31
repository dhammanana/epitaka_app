/// A pure-Dart fuzzy string matching library inspired by fzf and
/// nucleo-matcher.
///
/// This library provides a single public function, [fuzzySearch], that
/// implements the same greedy-forward + backward-optimization matching
/// and scoring algorithm used by fzf and nucleo-matcher.  It is designed
/// to be:
///
///   - **Portable** – pure Dart with no native dependencies (no FFI).
///   - **Fast** – O(n log K) for K results, essentially linear.
///   - **Reusable** – a single function with a clean signature.
///
/// ## Basic usage
///
/// ```dart
/// final results = fuzzySearch(
///   query: 'miicuvanna',
///   candidates: ['miiculasilasuttaculasihavannana', 'mulasuttavannana'],
///   limit: 10,
/// );
///
/// for (final r in results) {
///   print('Score: ${r.score}, positions: ${r.positions}');
/// }
/// ```
///
/// The returned [ScoredMatch] objects contain the input-list index,
/// a score, and the character positions of the match (for UI
/// highlighting).
library;

import 'dart:math';

import 'matcher.dart' show fuzzyMatch;
import 'scorer.dart' show scoreMatch;
import 'result.dart' show ScoredMatch;
import 'heap.dart' show TopKHeap;

// ── Constants ────────────────────────────────────────────────────────

/// Default limit for results when none is specified.
const int _defaultLimit = 20;

/// Maximum number of candidates to pre-filter with a simple prefix check.
/// Beyond this, we rely solely on the fuzzy matcher.
const int _preFilterLimit = 5000;

// ── Public API ───────────────────────────────────────────────────────

/// Search [query] against [candidates] using fzf-style fuzzy matching.
///
/// [query] is the user's search string (will be normalised internally).
/// [candidates] is a list of strings to match against.
/// [limit] controls how many results to return (default 20).
///
/// Returns results sorted by score, highest first.  An empty list means
/// no candidates matched.
///
/// ## Generic version
///
/// If you have typed data, use [fuzzySearchWith]:
///
/// ```dart
/// final results = fuzzySearchWith(
///   query: 'miicuvanna',
///   items: myObjects,
///   stringOf: (obj) => obj.searchableText,
///   limit: 10,
/// );
/// ```
List<ScoredMatch> fuzzySearch({
  required String query,
  required List<String> candidates,
  int limit = _defaultLimit,
}) {
  final results = fuzzySearchWith(
    query: query,
    items: candidates,
    stringOf: (s) => s,
    limit: limit,
  );
  return results;
}

/// Generic version of [fuzzySearch] for typed candidate lists.
///
/// [query] is the user's search string (will be normalised internally).
/// [items] is a list of typed items.
/// [stringOf] extracts the searchable text from each item.
/// [limit] controls how many results to return (default 20).
///
/// Returns results sorted by score, highest first.
List<ScoredMatch> fuzzySearchWith<T>({
  required String query,
  required List<T> items,
  required String Function(T item) stringOf,
  int limit = _defaultLimit,
}) {
  if (query.isEmpty || items.isEmpty) return [];

  final normalisedQuery = normalizeQuery(query);
  if (normalisedQuery.isEmpty) return [];

  final k = max(1, limit);
  final heap = TopKHeap(k);

  // Optional: pre-filter using a simple prefix check for very large
  // candidate sets to avoid O(n) fuzzy matching on everything.
  // Tracks original indices so results always map back to [items].
  final candidates = items.length > _preFilterLimit
      ? _preFilter(items, stringOf, normalisedQuery)
      : items.asMap().entries.map((e) => (idx: e.key, item: e.value)).toList();

  for (final c in candidates) {
    final candidateText = stringOf(c.item);
    final positions = fuzzyMatch(normalisedQuery, candidateText);
    if (positions == null) continue;

    final score = scoreMatch(candidateText, positions);
    heap.add(ScoredMatch(
      index: c.idx,
      score: score,
      positions: positions,
    ));
  }

  return heap.toSortedList();
}

// ── Internal helpers ─────────────────────────────────────────────────

/// Normalise a string for fuzzy matching.
///
/// Strips Pāli diacritics (ā→a, ṃ→m, etc.), lowercases, removes
/// non-index characters, and collapses whitespace.
///
/// Callers **must** use the same function on both the query and the
/// candidate texts to ensure consistent matching.
String normalizeQuery(String query) {
  return query
      .toLowerCase()
      .replaceAll('ā', 'a')
      .replaceAll('ī', 'i')
      .replaceAll('ū', 'u')
      .replaceAll('ṃ', 'm')
      .replaceAll('ṁ', 'm')
      .replaceAll('ñ', 'n')
      .replaceAll('ṇ', 'n')
      .replaceAll('ṭ', 't')
      .replaceAll('ḍ', 'd')
      .replaceAll('ḷ', 'l')
      .replaceAll('ō', 'o')
      .replaceAll('ṅ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9\s/@-]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Quickly pre-filter a large candidate list using the first few
/// characters of the normalised query.
///
/// This avoids running the full O(n) fuzzy matcher on thousands of
/// obviously non-matching candidates.
List<({int idx, T item})> _preFilter<T>(
  List<T> items,
  String Function(T) stringOf,
  String query,
) {
  // Take first 2 non-space chars and check they appear in order.
  // This is a very cheap check.
  final chars = <int>[];
  for (int i = 0; i < query.length && chars.length < 2; i++) {
    if (query.codeUnitAt(i) != 0x20) {
      chars.add(query.codeUnitAt(i));
    }
  }
  if (chars.isEmpty) {
    return items.asMap().entries.map((e) => (idx: e.key, item: e.value)).toList();
  }

  final result = <({int idx, T item})>[];
  for (int i = 0; i < items.length; i++) {
    final text = stringOf(items[i]);
    int ti = 0;
    bool matched = true;
    for (final c in chars) {
      while (ti < text.length && text.codeUnitAt(ti) != c) {
        ti++;
      }
      if (ti >= text.length) {
        matched = false;
        break;
      }
      ti++;
    }
    if (matched) {
      result.add((idx: i, item: items[i]));
    }
  }
  return result;
}
