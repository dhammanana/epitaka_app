import 'package:drift/drift.dart' show Variable;

import '../../../core/database/epitaka_database.dart';
import '../../../core/database/translation_database.dart';

/// Result of an in-book search query.
class InBookSearchResult {
  final List<int> paraIds;
  final List<int> lineIds;

  const InBookSearchResult({
    required this.paraIds,
    required this.lineIds,
  });

  bool get isEmpty => paraIds.isEmpty;
  bool get isNotEmpty => paraIds.isNotEmpty;
  int get length => paraIds.length;
}

/// Run an in-book search on the `sentences` table with a `book_id`
/// b-tree filter. Searches both Pāli text (epitaka.db) and enabled
/// translation texts. Returns `(para_id, line_id)` pairs so the caller can
/// jump to the exact matching sentence (not just the paragraph start).
///
/// This is a pure utility function that takes all DB handles explicitly;
/// the caller is responsible for the UI state updates (setState).
Future<InBookSearchResult> runInBookSearch({
  required String query,
  required String bookId,
  required EpitakaDatabase epitakaDb,
  required List<String> enabledLangs,
  required Future<TranslationDatabase?> Function(String langCode)
      getTranslationDb,
}) async {
  final words = query
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  if (words.isEmpty) {
    return const InBookSearchResult(paraIds: [], lineIds: []);
  }

  // ── Collect matching (paraId, lineId) pairs ──────────────────────
  //
  // Both epitaka.db.sentences and translation*.db.sentences have
  // `book_id`, `para_id`, `line_id` as a composite primary key, so we
  // can SELECT line_id and jump to the exact sentence.

  final seenKeys = <int>{};
  final matchParas = <int>[];
  final matchLines = <int>[];

  void addMatch(int paraId, int lineId) {
    // Encode (paraId, lineId) into a single int for dedup
    final key = paraId * 1000000 + lineId;
    if (seenKeys.add(key)) {
      matchParas.add(paraId);
      matchLines.add(lineId);
    }
  }

  // 1. Search Pāli text from epitaka.db ───────────────────────────────
  final paliConditions = words
      .map((_) => "pali LIKE '%' || ? || '%'")
      .join(' AND ');

  final paliRows = await epitakaDb
      .customSelect(
        'SELECT para_id, line_id FROM sentences '
        'WHERE book_id = ? AND $paliConditions '
        'ORDER BY para_id, line_id LIMIT 500',
        variables: [
          Variable.withString(bookId),
          for (final w in words) Variable.withString(w),
        ],
      )
      .get();

  for (final row in paliRows) {
    addMatch(row.data['para_id'] as int, row.data['line_id'] as int);
  }

  // 2. Search translation texts from active translation DBs ───────────
  for (final langCode in enabledLangs) {
    try {
      final transDb = await getTranslationDb(langCode);
      if (transDb == null) continue;

      final transConditions = words
          .map((_) => "translation LIKE '%' || ? || '%'")
          .join(' AND ');

      final transRows = await transDb
          .customSelect(
            'SELECT para_id, line_id FROM sentences '
            'WHERE book_id = ? AND $transConditions '
            'ORDER BY para_id, line_id LIMIT 500',
            variables: [
              Variable.withString(bookId),
              for (final w in words) Variable.withString(w),
            ],
          )
          .get();

      for (final row in transRows) {
        addMatch(row.data['para_id'] as int, row.data['line_id'] as int);
      }
    } catch (_) {
      // Translation db may not exist — skip
    }
  }

  return InBookSearchResult(paraIds: matchParas, lineIds: matchLines);
}
