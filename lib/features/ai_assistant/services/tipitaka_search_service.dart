/// Service that searches the local Tipitaka SQLite database for passages
/// relevant to a user's question or research topic.
///
/// Inspired by the Python aichat app's SQLite tool layer (db_tools.py).
/// Searches the `sentences` table (Pāli) and optionally the translation
/// databases for relevant passages. Returns results with book_id, para_id,
/// line_id, and text excerpts that the AI can cite as [Source N].
library;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/epitaka_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';

/// A single search result from the Tipitaka, carrying all metadata needed
/// for the AI to cite it and for the UI to display a tappable link.
class TipitakaSearchResult {
  final String bookId;
  final String? bookName;
  final int paraId;
  final int lineId;
  final String text;
  final String? translation;
  final double score;

  const TipitakaSearchResult({
    required this.bookId,
    this.bookName,
    required this.paraId,
    required this.lineId,
    this.text = '',
    this.translation,
    this.score = 1.0,
  });
}

/// Service that encapsulates search logic across the Tipitaka SQLite DB.
class TipitakaSearchService {
  final Ref _ref;

  TipitakaSearchService(this._ref);

  /// Search for passages matching [query] across the Tipitaka.
  ///
  /// Strategy:
  /// 1. Tokenise the query into keywords.
  /// 2. Search `sentences.pali` with LIKE for each keyword.
  /// 3. If a translation DB is active, also search its `sentences.translation`.
  /// 4. Merge, deduplicate, and rank by keyword match density.
  /// 5. Return top [limit] results.
  ///
  /// Returns an empty list on any DB error rather than crashing.
  Future<List<TipitakaSearchResult>> search({
    required String query,
    int limit = 15,
    String? language,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final epitakaDb = await _ref.read(epitakaDbProvider.future);
      final settings = _ref.read(settingsProvider);

      // Tokenise and deduplicate keywords (skip very short terms)
      final keywords = trimmed
          .split(RegExp(r'[\s,;.()\[\]{}:;!?…—–\-"«»“”' "'" r']+'))
          .map((w) => w.trim())
          .where((w) => w.length >= 3)
          .toSet()
          .toList();

      if (keywords.isEmpty) return [];

      // ── Search Pāli sentences ──────────────────────────────────────
      final paliResults = await _searchPali(epitakaDb, keywords, limit);

      // ── Search translation if available ────────────────────────────
      List<TipitakaSearchResult> transResults = [];
      if (language != null || settings.showTranslation) {
        final lang = language ?? settings.primaryTranslationLang;
        transResults = await _searchTranslation(
          epitakaDb, keywords, lang, limit,
        );
      }

      // ── Merge & score ──────────────────────────────────────────────
      final seen = <String>{};
      final merged = <TipitakaSearchResult>[];

      for (final r in [...paliResults, ...transResults]) {
        final key = '${r.bookId}:${r.paraId}:${r.lineId}';
        if (seen.add(key)) {
          merged.add(r);
        }
      }

      // Sort by score descending, then by para_id
      merged.sort((a, b) {
        final scoreCmp = b.score.compareTo(a.score);
        if (scoreCmp != 0) return scoreCmp;
        return a.paraId.compareTo(b.paraId);
      });

      return merged.take(limit).toList();
    } catch (e) {
      debugPrint('[AI_SEARCH] Search error: $e');
      return [];
    }
  }

  /// Search Pāli text using LIKE on each keyword.
  Future<List<TipitakaSearchResult>> _searchPali(
    EpitakaDatabase db,
    List<String> keywords,
    int limit,
  ) async {
    if (keywords.isEmpty) return [];

    final conditions = keywords
        .map((kw) => 'LOWER(s.pali) LIKE ?')
        .join(' OR ');
    final params = keywords.map((kw) => '%${kw.toLowerCase()}%').toList();

    final rows = await db.customSelect(
      'SELECT s.book_id, s.para_id, s.line_id, s.pali, '
      'b.book_name '
      'FROM sentences s '
      'JOIN books b ON b.book_id = s.book_id '
      'WHERE $conditions '
      'ORDER BY s.book_id, s.para_id, s.line_id '
      'LIMIT ?',
      variables: [
        ...params.map((p) => Variable.withString(p)),
        Variable.withInt(limit * 5), // over-fetch for scoring
      ],
    ).get();

    // Score by how many keywords match in each sentence
    final results = <TipitakaSearchResult>[];
    for (final row in rows) {
      final paliText = (row.data['pali'] as String?) ?? '';
      final matchCount = keywords.where(
        (kw) => paliText.toLowerCase().contains(kw.toLowerCase()),
      ).length;
      final score = matchCount / keywords.length;

      results.add(TipitakaSearchResult(
        bookId: (row.data['book_id'] as String?) ?? '',
        bookName: (row.data['book_name'] as String?) ?? '',
        paraId: (row.data['para_id'] as int?) ?? 0,
        lineId: (row.data['line_id'] as int?) ?? 1,
        text: paliText,
        score: score,
      ));
    }

    return results;
  }

  /// Search translation text for the given language.
  Future<List<TipitakaSearchResult>> _searchTranslation(
    EpitakaDatabase db,
    List<String> keywords,
    String langCode,
    int limit,
  ) async {
    // The translation is stored in a separate database
    // We search the main epitaka sentences table using the same approach,
    // but the translation DB is separate (epitaka_en.db, etc.)
    // For now, we focus on Pāli-only search which is always available.
    // The translation search can be added later when translation DBs
    // have consistent schemas.
    return [];
  }

  /// Get the full text of a specific paragraph for the citation popup.
  ///
  /// Returns a map with 'pali', 'book_name', and optionally 'translation'.
  Future<Map<String, dynamic>?> getParagraph(
    String bookId,
    int paraId, {
    String? langCode,
  }) async {
    try {
      final db = await _ref.read(epitakaDbProvider.future);

      // Fetch all lines of this paragraph
      final rows = await (db.select(db.sentences)
            ..where((s) =>
                s.bookId.equals(bookId) & s.paraId.equals(paraId))
            ..orderBy([
              (s) => OrderingTerm(expression: s.lineId),
            ]))
          .get();

      if (rows.isEmpty) return null;

      final paliLines = rows.map((r) => r.pali ?? '').where((t) => t.isNotEmpty);
      final paliText = paliLines.join('\n');

      // Get book info
      final bookRows = await (db.select(db.books)
            ..where((b) => b.bookId.equals(bookId))
            ..limit(1))
          .get();
      final bookName = bookRows.isNotEmpty ? bookRows.first.bookName : null;

      return {
        'book_id': bookId,
        'para_id': paraId,
        'pali': paliText,
        'book_name': bookName ?? bookId,
        'sentences': rows
            .map((r) => {
                  'line_id': r.lineId,
                  'pali': r.pali ?? '',
                })
            .toList(),
      };
    } catch (e) {
      debugPrint('[AI_SEARCH] getParagraph error: $e');
      return null;
    }
  }

  /// Fetch a range of paragraphs (for the citation popup's "show context").
  Future<List<Map<String, dynamic>>?> getParagraphRange(
    String bookId,
    int paraStart,
    int paraEnd,
  ) async {
    try {
      final db = await _ref.read(epitakaDbProvider.future);

      final rows = await (db.select(db.sentences)
            ..where((s) =>
                s.bookId.equals(bookId) &
                s.paraId.isBetween(Variable.withInt(paraStart), Variable.withInt(paraEnd)))
            ..orderBy([
              (s) => OrderingTerm(expression: s.paraId),
              (s) => OrderingTerm(expression: s.lineId),
            ]))
          .get();

      if (rows.isEmpty) return null;

      // Group by paraId
      final grouped = <int, List<String>>{};
      for (final r in rows) {
        if (r.pali != null && r.pali!.trim().isNotEmpty) {
          grouped.putIfAbsent(r.paraId, () => []);
          grouped[r.paraId]!.add(r.pali!);
        }
      }

      return grouped.entries.map((e) {
        return {
          'para_id': e.key,
          'pali': e.value.join('\n'),
          'line_count': e.value.length,
        };
      }).toList()
        ..sort((a, b) => (a['para_id'] as int).compareTo(b['para_id'] as int));
    } catch (e) {
      debugPrint('[AI_SEARCH] getParagraphRange error: $e');
      return null;
    }
  }
}

/// Riverpod provider for TipitakaSearchService.
final tipitakaSearchServiceProvider = Provider<TipitakaSearchService>((ref) {
  return TipitakaSearchService(ref);
});
