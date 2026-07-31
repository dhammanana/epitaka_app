/// Service for the @ mention heading/sutta attachment system.
///
/// The mention_index table now stores TWO kinds of entries:
///
///  **book** (entry_type='book', para_id=0):
///    One row per book/sutta.  Searchable by book name.  Contains
///    mula_ref/attha_ref/tika_ref so the AI can find commentaries.
///    chapter_len shows the paragraph count.
///
///  **heading** (entry_type='heading', para_id>0):
///    One row per heading within a book.  Contains the hierarchy path
///    and links to the parent book.
///
/// Performance:
///  - Build runs once (~1s) and is triggered at startup or on first @ use.
///  - Search uses LIKE on search_text (indexed) — sub-10ms on 100k+ rows.
///  - Full Pāli text is fetched ON SELECTION (not on keystroke).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../../core/utils/fuzzy_matcher/fuzzy_matcher_library.dart'
    show fuzzySearchWith, normalizeQuery;

import '../../../core/database/app_database.dart';
import '../../../core/providers/app_db_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../models/heading_attachment.dart';

/// Maximum length for attached Pāli text (200,000 characters).
const int kMaxAttachmentChars = 200000;

/// Service managing the @ mention index.
class MentionService {
  final Ref _ref;

  /// Cache: whether the index table has been created in this session.
  bool _indexEnsured = false;

  /// Guard against concurrent [buildIndex] calls.
  bool _isBuilding = false;

  MentionService(this._ref);

  /// Ensure the mention_index table exists with all columns.
  Future<void> _ensureIndexTable(AppDatabase appDb) async {
    if (_indexEnsured) return;
    await appDb.customStatement('''
      CREATE TABLE IF NOT EXISTS mention_index (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_type TEXT NOT NULL DEFAULT 'heading',
        book_id TEXT NOT NULL,
        para_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        book_name TEXT NOT NULL DEFAULT '',
        hierarchy_json TEXT NOT NULL DEFAULT '[]',
        path TEXT NOT NULL,
        search_text TEXT NOT NULL,
        is_mula INTEGER NOT NULL DEFAULT 1,
        book_order_id INTEGER NOT NULL DEFAULT 0,
        chapter_len INTEGER NOT NULL DEFAULT 0,
        mula_ref TEXT DEFAULT '',
        attha_ref TEXT DEFAULT '',
        tika_ref TEXT DEFAULT ''
      )
    ''');
    // Add columns that might not exist in older versions (migration).
    await appDb
        .customStatement(
          "ALTER TABLE mention_index ADD COLUMN entry_type TEXT NOT NULL DEFAULT 'heading'",
        )
        .catchError((_) {}); // Ignore if column already exists.
    await appDb
        .customStatement(
          'ALTER TABLE mention_index ADD COLUMN chapter_len INTEGER NOT NULL DEFAULT 0',
        )
        .catchError((_) {});
    await appDb
        .customStatement(
          "ALTER TABLE mention_index ADD COLUMN mula_ref TEXT DEFAULT ''",
        )
        .catchError((_) {});
    await appDb
        .customStatement(
          "ALTER TABLE mention_index ADD COLUMN attha_ref TEXT DEFAULT ''",
        )
        .catchError((_) {});
    await appDb
        .customStatement(
          "ALTER TABLE mention_index ADD COLUMN tika_ref TEXT DEFAULT ''",
        )
        .catchError((_) {});

    await appDb.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_mention_search
      ON mention_index(search_text)
    ''');
    await appDb.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_mention_book
      ON mention_index(book_id, para_id)
    ''');
    _indexEnsured = true;

    // Auto-build if table is empty (first use after app install).
    final countRows = await appDb
        .customSelect('SELECT COUNT(*) as cnt FROM mention_index')
        .get();
    final count = countRows.first.data['cnt'] as int? ?? 0;
    if (count == 0) {
      // If _isBuilding is true, another call is already populating the
      // table (the DELETE in _buildIndexInternal emptied it).  Don't
      // trigger a duplicate — the concurrent build will finish shortly.
      if (_isBuilding) {
        debugPrint('[MENTION] Table empty during concurrent build — skipping');
        return;
      }
      debugPrint('[MENTION] Index table is empty — auto-building…');
      await buildIndex();
      debugPrint(
        '[MENTION] Auto-build complete: ${await getIndexSize()} entries',
      );
      return;
    }

    // Check if existing index uses the new FZF-friendly search_text format.
    // Old format: space-separated words like "m ii bhikkhuvaggo ambalatthika"
    // New format: path-separated like "m-ii/bhikkhuvaggo/ambalatthika-suttam"
    // We detect this by checking if any search_text uses '/' as a separator.
    if (!_isBuilding) {
      try {
        final sampleRows = await appDb
            .customSelect(
              'SELECT search_text FROM mention_index WHERE search_text LIKE ? LIMIT 1',
              variables: [Variable.withString('%/%')],
            )
            .get();
        if (sampleRows.isEmpty) {
          debugPrint(
            '[MENTION] Detected old search_text format (no / separator) — rebuilding…',
          );
          // Rebuild asynchronously so the user isn't blocked
          buildIndex();
        }
      } catch (_) {
        // If the query fails for any reason, just proceed with old data
      }
    }
  }

  // ── Build index ───────────────────────────────────────────────────────

  /// Build the mention index.
  ///
  /// [onProgress] is called with a value 0.0–1.0 and a human-readable label
  /// so the UI can show a progress bar.  The method also yields to the
  /// Flutter event loop between books so the UI stays responsive.
  Future<int> buildIndex({
    void Function(double progress, String label)? onProgress,
  }) async {
    if (_isBuilding) {
      debugPrint('[MENTION] buildIndex: already building, skipping');
      return 0;
    }
    _isBuilding = true;
    try {
      return await _buildIndexInternal(onProgress: onProgress);
    } finally {
      _isBuilding = false;
    }
  }

  Future<int> _buildIndexInternal({
    void Function(double progress, String label)? onProgress,
  }) async {
    final appDb = await _ref.read(appDbProvider.future);
    final epiDb = await _ref.read(epitakaDbProvider.future);

    await _ensureIndexTable(appDb);

    // Drop old data
    await appDb.customStatement('DELETE FROM mention_index');

    debugPrint('[MENTION] Building mention index…');
    final stopwatch = Stopwatch()..start();

    // Step 1: Get all books with ordering info
    final books = await epiDb.customSelect('''
      SELECT book_id, book_name, id, mula_ref, attha_ref, tika_ref, chapter_len
      FROM books
      ORDER BY
        CASE WHEN mula_ref IS NULL THEN 0 ELSE 1 END,
        id
    ''').get();

    final totalBooks = books.length;
    debugPrint('[MENTION] $totalBooks books found');

    onProgress?.call(0.0, 'Preparing…');

    int totalEntries = 0;

    for (int i = 0; i < totalBooks; i++) {
      final book = books[i];
      final bookId = book.data['book_id'] as String;
      final bookName = book.data['book_name'] as String? ?? '';
      final bookOrderId = book.data['id'] as int;
      final mulaRef = book.data['mula_ref'] as String?;
      final atthaRef = book.data['attha_ref'] as String?;
      final tikaRef = book.data['tika_ref'] as String?;
      final chapterLen = (book.data['chapter_len'] as int?) ?? 0;
      final isMula = mulaRef == null ? 1 : 0;

      // Report progress for this book
      final progress = (i + 1) / totalBooks;
      onProgress?.call(progress, '$bookId ($bookName)');

      // ── Add a BOOK-level entry (para_id = 0) ─────────────────────────
      if (bookName.isNotEmpty) {
        final bookPath = '$bookId/$bookName';
        final bookSearchText = normalizeQuery('$bookId/$bookName');
        await appDb.customStatement(
          '''
          INSERT INTO mention_index
            (entry_type, book_id, para_id, title, book_name, hierarchy_json,
             path, search_text, is_mula, book_order_id, chapter_len,
             mula_ref, attha_ref, tika_ref)
          VALUES ('book', ?, 0, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
          [
            bookId,
            bookName,
            bookName,
            jsonEncode([bookName]),
            bookPath,
            bookSearchText,
            isMula,
            bookOrderId,
            chapterLen,
            mulaRef ?? '',
            atthaRef ?? '',
            tikaRef ?? '',
          ],
        );
        totalEntries++;
      }

      // ── Add heading-level entries ────────────────────────────────────
      final headings = await epiDb
          .customSelect(
            '''
        SELECT para_id, title, level, parent
        FROM headings
        WHERE book_id = ? AND level < 19 AND level != 10
        ORDER BY para_id ASC
      ''',
            variables: [Variable.withString(bookId)],
          )
          .get();

      if (headings.isEmpty) continue;

      final titleMap = <int, String>{};
      final parentMap = <int, int>{};
      for (final h in headings) {
        final pid = h.data['para_id'] as int;
        titleMap[pid] = (h.data['title'] as String?) ?? '';
        parentMap[pid] = (h.data['parent'] as int?) ?? 0;
      }

      for (int hi = 0; hi < headings.length; hi++) {
        final h = headings[hi];
        final paraId = h.data['para_id'] as int;
        final title = (h.data['title'] as String?) ?? '';
        if (title.isEmpty) continue;

        final hierarchy = <String>[title];
        int? currentParent = parentMap[paraId];
        final seen = <int>{paraId};
        while (currentParent != null &&
            currentParent > 0 &&
            !seen.contains(currentParent)) {
          seen.add(currentParent);
          final parentTitle = titleMap[currentParent];
          if (parentTitle != null && parentTitle.isNotEmpty) {
            hierarchy.insert(0, parentTitle);
          }
          currentParent = parentMap[currentParent];
        }

        final path = '$bookId/${hierarchy.join('/')}';
        final searchParts = <String>[bookId, ...hierarchy];
        final searchText = normalizeQuery(searchParts.join('/'));
        final hierarchyJson = jsonEncode(hierarchy);

        await appDb.customStatement(
          '''
          INSERT INTO mention_index
            (entry_type, book_id, para_id, title, book_name, hierarchy_json,
             path, search_text, is_mula, book_order_id, chapter_len,
             mula_ref, attha_ref, tika_ref)
          VALUES ('heading', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
          [
            bookId,
            paraId,
            title,
            bookName,
            hierarchyJson,
            path,
            searchText,
            isMula,
            bookOrderId,
            chapterLen,
            mulaRef ?? '',
            atthaRef ?? '',
            tikaRef ?? '',
          ],
        );
        totalEntries++;

        // Yield inside large heading loops too so the UI stays
        // responsive even for books with hundreds of headings.
        if (hi % 30 == 0 && hi < headings.length - 1) {
          await Future.delayed(Duration.zero);
        }
      }

      // Yield to the event loop between books so the progress bar
      // updates smoothly and the app doesn't freeze.
      if (i % 5 == 0 && i < totalBooks - 1) {
        await Future.delayed(Duration.zero);
      }
    }

    stopwatch.stop();
    debugPrint(
      '[MENTION] Index built: $totalEntries entries in ${stopwatch.elapsed.inSeconds}s',
    );
    return totalEntries;
  }

  // ── Search index ──────────────────────────────────────────────────────

  /// Search the mention index using ffuzzy (FZF-style) fuzzy matching.
  Future<List<MentionSearchResult>> search(
    String query, {
    int limit = 20,
  }) async {
    final appDb = await _ref.read(appDbProvider.future);
    await _ensureIndexTable(appDb);

    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final normalized = normalizeQuery(trimmed);
    if (normalized.isEmpty) return [];

    final firstChars = normalized.replaceAll('/', '').replaceAll('-', '');
    final prefixLen = firstChars.length >= 2 ? 2 : firstChars.length;
    if (prefixLen == 0) return [];
    final prefix = firstChars.substring(0, prefixLen);
    final likePattern = prefix.split('').join('%');
    final broadPattern = '%$likePattern%';

    try {
      var rows = await appDb
          .customSelect(
            '''
        SELECT entry_type, book_id, para_id, title, book_name,
               hierarchy_json, path, search_text, is_mula, chapter_len,
               mula_ref, attha_ref, tika_ref
        FROM mention_index
        WHERE search_text LIKE ?
        ORDER BY is_mula DESC, book_order_id ASC, para_id ASC
        LIMIT 200
      ''',
            variables: [Variable.withString(broadPattern)],
          )
          .get();

      if (rows.isEmpty) {
        final fallbackPattern = '%${firstChars.substring(0, prefixLen)}%';
        rows = await appDb
            .customSelect(
              '''
          SELECT entry_type, book_id, para_id, title, book_name,
                 hierarchy_json, path, search_text, is_mula, chapter_len,
                 mula_ref, attha_ref, tika_ref
          FROM mention_index
          WHERE search_text LIKE ?
          ORDER BY is_mula DESC, book_order_id ASC, para_id ASC
          LIMIT 200
        ''',
              variables: [Variable.withString(fallbackPattern)],
            )
            .get();
      }

      if (rows.isEmpty) return [];

      return _filterWithFfuzzy(rows, normalized, limit: limit);
    } catch (e) {
      debugPrint('[MENTION] Search error: $e');
      return [];
    }
  }

  /// Filter and rank SQL rows using the pure-Dart fuzzy matcher.
  ///
  /// Uses [fuzzySearchWith] — our fzf/nucleo-inspired algorithm — which
  /// requires no native libraries and works on all platforms.
  List<MentionSearchResult> _filterWithFfuzzy(
    List<QueryRow> rows,
    String normalized, {
    int limit = 20,
  }) {
    final candidates = rows.map((r) => _rowToResult(r.data)).toList();

    final results = fuzzySearchWith(
      query: normalized,
      items: candidates,
      stringOf: (r) => r.searchText,
      limit: limit,
    );

    return results.map((r) => candidates[r.index]).toList();
  }

  // ── Fetch full Pāli text ──────────────────────────────────────────────

  Future<String> fetchPaliText(String bookId, {int? maxChars}) async {
    final epiDb = await _ref.read(epitakaDbProvider.future);
    final limit = maxChars ?? kMaxAttachmentChars;

    try {
      final rows = await epiDb
          .customSelect(
            '''
        SELECT para_id, group_concat(pali, ' ') as para_text
        FROM sentences
        WHERE book_id = ? AND pali IS NOT NULL
        GROUP BY para_id
        ORDER BY para_id ASC
      ''',
            variables: [Variable.withString(bookId)],
          )
          .get();

      if (rows.isEmpty) return '';

      final buffer = StringBuffer();
      for (final row in rows) {
        final paraId = row.data['para_id'] as int;
        final paraText = row.data['para_text'] as String? ?? '';
        if (paraText.isEmpty) continue;

        final line = '§$paraId $paraText\n';
        if (buffer.length + line.length > limit) {
          buffer.write('… (truncated at $limit characters)');
          break;
        }
        buffer.write(line);
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('[MENTION] Failed to fetch Pāli text for $bookId: $e');
      return '';
    }
  }

  // ── Index status ──────────────────────────────────────────────────────

  Future<bool> isIndexBuilt() async {
    try {
      final appDb = await _ref.read(appDbProvider.future);
      final rows = await appDb
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='mention_index'",
          )
          .get();
      if (rows.isEmpty) return false;
      final count = await appDb
          .customSelect('SELECT COUNT(*) as cnt FROM mention_index')
          .get();
      return (count.first.data['cnt'] as int) > 0;
    } catch (_) {
      return false;
    }
  }

  Future<int> getIndexSize() async {
    try {
      final appDb = await _ref.read(appDbProvider.future);
      final rows = await appDb
          .customSelect('SELECT COUNT(*) as cnt FROM mention_index')
          .get();
      return (rows.first.data['cnt'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ── Row parser ────────────────────────────────────────────────────────

  MentionSearchResult _rowToResult(Map<String, dynamic> row) {
    final entryTypeStr = row['entry_type'] as String? ?? 'heading';
    final entryType = entryTypeStr == 'book'
        ? AttachmentEntryType.book
        : AttachmentEntryType.heading;
    final bookId = row['book_id'] as String;
    final paraId = row['para_id'] as int;
    final title = row['title'] as String? ?? '';
    final bookName = row['book_name'] as String? ?? '';
    final path = row['path'] as String? ?? '$bookId/$title';
    final isMula = (row['is_mula'] as int?) == 1;
    final chapterLen = (row['chapter_len'] as int?) ?? 0;
    final mulaRef = row['mula_ref'] as String?;
    final atthaRef = row['attha_ref'] as String?;
    final tikaRef = row['tika_ref'] as String?;

    List<String> hierarchy = [];
    try {
      final jsonStr = row['hierarchy_json'] as String? ?? '[]';
      final decoded = jsonDecode(jsonStr) as List<dynamic>?;
      if (decoded != null) {
        hierarchy = decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    final searchText = row['search_text'] as String? ?? '';

    return MentionSearchResult(
      entryType: entryType,
      bookId: bookId,
      paraId: paraId,
      title: title,
      bookName: bookName,
      path: path,
      hierarchy: hierarchy,
      isMula: isMula,
      chapterLen: chapterLen,
      mulaRef: mulaRef,
      atthaRef: atthaRef,
      tikaRef: tikaRef,
      searchText: searchText,
    );
  }

}

/// Riverpod provider for the MentionService.
final mentionServiceProvider = Provider<MentionService>((ref) {
  return MentionService(ref);
});
