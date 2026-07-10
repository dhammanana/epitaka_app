/// FTS5 virtual table names and helper queries.
///
/// These are used by [AppDatabase] for building and searching the full-text
/// search index across Pāli texts and translations.
class FtsTable {
  FtsTable._();

  /// The single FTS5 virtual table storing both Pāli and translation text.
  static const String index = 'fts_index';

  /// Get the number of rows indexed in the FTS table.
  static Future<int> getIndexedCount(dynamic db) async {
    try {
      final result = await db.customSelect(
        'SELECT COUNT(*) AS cnt FROM $index',
      ).get();
      if (result.isNotEmpty) return (result.first.data['cnt'] as num).toInt();
    } catch (_) {}
    return 0;
  }
}

/// A single FTS5 search result row from the combined index.
///
/// Each row represents a (book_id, para_id) pair with both the Pāli text
/// and the matching translation text side-by-side for fast combined search.
class FtsSearchResult {
  final String bookId;
  final int paraId;
  final String? bookName;
  final String? pali;
  final String? translation;
  final double rank;

  const FtsSearchResult({
    required this.bookId,
    required this.paraId,
    this.bookName,
    this.pali,
    this.translation,
    required this.rank,
  });
}

/// Progress snapshot emitted during FTS index building.
///
/// Carries cumulative counts, the current phase label, and batch
/// granularity so the UI can show detailed progress info.
class FtsBuildProgressData {
  /// Total rows processed so far (cumulative across all phases).
  final int current;

  /// Total rows expected across all phases.
  final int total;

  /// Human-readable phase label (e.g. "Indexing Pāli sentences…").
  final String phaseLabel;

  /// Step number label (e.g. "Step 1/4").
  final String stepLabel;

  /// Which batch within the current phase (1-based).
  final int batchCurrent;

  /// Total batches in the current phase.
  final int batchTotal;

  /// Estimated sentences processed per second.
  final double itemsPerSecond;

  /// Phase index (0=prefetch, 1=load translations, 2=index combined).
  /// Mapped to [IndexBuildPhase] in the indexing feature layer.
  final int phaseIndex;

  const FtsBuildProgressData({
    required this.current,
    required this.total,
    required this.phaseLabel,
    required this.stepLabel,
    this.batchCurrent = 0,
    this.batchTotal = 0,
    this.itemsPerSecond = 0,
    this.phaseIndex = 0,
  });

  /// Progress fraction (0.0 – 1.0) across the entire build.
  double get fraction => total > 0 ? current / total : 0.0;

  /// Formatted items-per-second string (e.g. "342/s").
  String get speedLabel {
    if (itemsPerSecond < 1) return '';
    if (itemsPerSecond >= 1000) {
      return '${(itemsPerSecond / 1000).toStringAsFixed(1)}k/s';
    }
    return '${itemsPerSecond.round()}/s';
  }
}

/// Escape a single-quoted SQL string literal (replaces `'` with `''`).
String escapeSqlString(String s) => s.replaceAll("'", "''");

/// Escape a FTS5 query string for MATCH (replaces `'` with `''`).
String escapeFtsQuery(String s) => s.replaceAll("'", "''");
