import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/pali_search_utils.dart';
import 'epitaka_database.dart';
import 'translation_database.dart';

part 'app_database.g.dart';

// ── Progress callback ──────────────────────────────────────────────────

/// Callback for reporting indexing progress (0.0–1.0) with a status message.
typedef IndexProgressCallback = void Function(double progress, String status);

/// Thrown by [AppDatabase.open] when `app_data.db` cannot be opened even
/// after a journal-file cleanup retry. Callers should catch this and let
/// the user choose to clear + rebuild rather than doing it automatically.
class AppDatabaseCorruptedException implements Exception {
  final String path;
  final Object cause;
  AppDatabaseCorruptedException(this.path, this.cause);

  @override
  String toString() => 'AppDatabaseCorruptedException($path): $cause';
}

// ---------------------------------------------------------------------------
// Table: bookmarks
// ---------------------------------------------------------------------------
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get bookId => text()();
  IntColumn get paraId => integer().nullable()();
  IntColumn get lineId => integer().nullable()();
  TextColumn get bookName => text().nullable()();
  TextColumn get pageNumber => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

}

// ---------------------------------------------------------------------------
// Table: tts_replacements
// ---------------------------------------------------------------------------
class TtsReplacements extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get pattern => text()();
  TextColumn get replacement => text()();
  BoolColumn get isRegex => boolean().withDefault(const Constant(false))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
}

// ---------------------------------------------------------------------------
// Table: reading_history
// ---------------------------------------------------------------------------
class ReadingHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text()();
  TextColumn get bookName => text().nullable()();
  IntColumn get paraId => integer().nullable()();
  IntColumn get lineId => integer().nullable()();
  DateTimeColumn get openedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get readCount => integer().withDefault(const Constant(1))();

}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------
@DriftDatabase(tables: [Bookmarks, ReadingHistory, TtsReplacements])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(ttsReplacements);
        }
      },
      beforeOpen: (details) async {
        try {
          await customStatement('PRAGMA journal_mode=WAL');
        } catch (_) {}
        try {
          await customStatement('PRAGMA foreign_keys=ON');
        } catch (_) {}
      },
    );
  }

  /// Open the app database at the default path.
  ///
  /// IMPORTANT: this used to unconditionally delete the `-wal`/`-shm`
  /// journal files *before* every open attempt, and to silently delete
  /// (and thus wipe bookmarks/history from) `app_data.db` the moment
  /// opening threw. That was the source of the "works, then crashes after
  /// I close and reopen the app" bug:
  ///
  ///  - If the previous session was killed while the FTS5 index build was
  ///    mid-write, SQLite's WAL file still holds the not-yet-checkpointed
  ///    pages that make the on-disk schema consistent. Deleting that WAL
  ///    file *before* even trying to open leaves the main db file with a
  ///    half-created FTS5 virtual table (its shadow tables `*_data`,
  ///    `*_idx`, `*_docsize`, `*_config` can be out of sync), which SQLite
  ///    reports as "database disk image is malformed" the next time
  ///    anything touches it.
  ///  - Any open failure (even a transient one) then triggered a silent
  ///    delete-and-recreate of the whole file, wiping the user's
  ///    bookmarks and reading history with no warning.
  ///
  /// The new sequence is: try a normal open; if that fails, retry once
  /// after clearing stale journals (a *legitimate* crash-recovery step);
  /// if it still fails, throw [AppDatabaseCorruptedException] instead of
  /// silently deleting anything, so the UI can offer an explicit
  /// "Clear data & rebuild" action.
  static Future<AppDatabase> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'app_data.db');
    final file = File(dbPath);

    debugPrint('[DB] Opening app_data.db at: $dbPath (exists: ${file.existsSync()})');

    try {
      final db = AppDatabase._create(file);
      // Force the connection to actually run its first query now, rather
      // than lazily on first use, so a corrupted file fails here.
      await db.customSelect('PRAGMA user_version').get();
      debugPrint('[DB] AppDatabase opened successfully');
      return db;
    } catch (e) {
      debugPrint('[DB] First open failed: $e — clearing stale WAL/SHM and retrying once…');
    }

    // Retry once after clearing journals left behind by an unclean
    // shutdown. This is safe to attempt (it does NOT touch app_data.db
    // itself) and resolves the common "leftover WAL from a killed app"
    // case without any data loss.
    _deleteJournalFiles(dbPath);
    try {
      final db = AppDatabase._create(file);
      await db.customSelect('PRAGMA user_version').get();
      debugPrint('[DB] AppDatabase opened successfully after clearing journals');
      return db;
    } catch (e) {
      debugPrint('[DB] AppDatabase still will not open: $e');
      throw AppDatabaseCorruptedException(dbPath, e);
    }
  }

  /// Delete `app_data.db` (and its journals) without opening a new one.
  /// This is destructive — bookmarks and reading history are lost — so it
  /// should only be called from an explicit user action (a "Clear data &
  /// rebuild" button), never automatically.
  ///
  /// Deliberately does NOT return a new [AppDatabase] instance: callers
  /// should invalidate whatever provider owns the current connection (e.g.
  /// `ref.invalidate(appDbProvider)`) afterwards so the *existing* open()
  /// codepath creates the fresh database, rather than this method
  /// silently creating a second connection to the same file.
  static Future<void> deleteDatabaseFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'app_data.db');
    final file = File(dbPath);

    debugPrint('[DB] Clearing app_data.db at user request…');
    _deleteJournalFiles(dbPath);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (e) {
        debugPrint('[DB] Failed to delete app_data.db: $e');
      }
    }
  }

  /// Runs a cheap FTS5-specific integrity check (much faster than a full
  /// `PRAGMA integrity_check` on a large corpus). Returns true if the
  /// search index is missing (nothing to check) or healthy, false if the
  /// FTS5 shadow tables are detectably corrupted.
  Future<bool> isSearchIndexHealthy() async {
    try {
      final exists = await customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='search_fts'",
      ).get();
      if (exists.isEmpty) return true; // nothing built yet, nothing to be corrupt
      // FTS5's built-in self-check: throws if the shadow tables disagree
      // with the index content.
      await customStatement("INSERT INTO search_fts(search_fts) VALUES('integrity-check')");
      return true;
    } catch (e) {
      debugPrint('[DB] Search index integrity check failed: $e');
      return false;
    }
  }

  static void _deleteJournalFiles(String dbPath) {
    for (final ext in ['-wal', '-shm', '-journal']) {
      final f = File('$dbPath$ext');
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
  }

  static AppDatabase _create(File file) {
    final database = NativeDatabase(
      file,
      setup: (db) {
        try {
          db.execute('PRAGMA journal_mode=WAL');
        } catch (_) {}
        try {
          db.execute('PRAGMA foreign_keys=ON');
        } catch (_) {}
        try {
          db.execute('PRAGMA mmap_size=0');   // ← add this line
        } catch (_) {}
      },
      logStatements: false,
    );

    return AppDatabase(database);
  }

  /// Add or update a bookmark.
  Future<Bookmark> addBookmark({
    required String name,
    required String bookId,
    int? paraId,
    int? lineId,
    String? bookName,
    String? pageNumber,
  }) async {
    final now = DateTime.now();
    final id = await into(bookmarks).insert(BookmarksCompanion(
      name: Value(name),
      bookId: Value(bookId),
      paraId: Value(paraId),
      lineId: Value(lineId),
      bookName: Value(bookName),
      pageNumber: Value(pageNumber),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    return (await (select(bookmarks)..where((b) => b.id.equals(id))).get()).first;
  }

  /// Delete a bookmark by ID.
  Future<void> deleteBookmark(int id) async {
    await (delete(bookmarks)..where((b) => b.id.equals(id))).go();
  }

  /// Get all bookmarks, ordered by most recent first.
  Future<List<Bookmark>> getAllBookmarks() async {
    return (select(bookmarks)..orderBy([(b) => OrderingTerm(expression: b.createdAt, mode: OrderingMode.desc)])).get();
  }

  /// Get bookmarks for a specific book.
  Future<List<Bookmark>> getBookmarksForBook(String bookId) async {
    return (select(bookmarks)
          ..where((b) => b.bookId.equals(bookId))
          ..orderBy([(b) => OrderingTerm(expression: b.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  /// Add or update reading history entry.
  Future<void> recordReading({
    required String bookId,
    String? bookName,
    int? paraId,
    int? lineId,
  }) async {
    final now = DateTime.now();

    // Check if an entry for this book already exists (not just updated today)
    final existing = await (select(readingHistory)
          ..where((h) => h.bookId.equals(bookId))
          ..orderBy([(h) => OrderingTerm(expression: h.updatedAt, mode: OrderingMode.desc)])
          ..limit(1))
        .get();

    if (existing.isNotEmpty) {
      final entry = existing.first;
      // Update the existing entry with new location and timestamp
      await (update(readingHistory)..where((h) => h.id.equals(entry.id))).write(ReadingHistoryCompanion(
        bookName: Value(bookName ?? entry.bookName),
        paraId: Value(paraId ?? entry.paraId),
        lineId: Value(lineId ?? entry.lineId),
        updatedAt: Value(now),
        readCount: Value(entry.readCount + 1),
      ));
    } else {
      await into(readingHistory).insert(ReadingHistoryCompanion(
        bookId: Value(bookId),
        bookName: Value(bookName),
        paraId: Value(paraId),
        lineId: Value(lineId),
        openedAt: Value(now),
        updatedAt: Value(now),
        readCount: const Value(1),
      ));
    }
  }

  /// Get all reading history, ordered by most recently updated first.
  Future<List<ReadingHistoryData>> getAllHistory() async {
    return (select(readingHistory)
          ..orderBy([(h) => OrderingTerm(expression: h.updatedAt, mode: OrderingMode.desc)]))
        .get();
  }

  /// Delete a reading history entry by ID.
  Future<void> deleteHistoryEntry(int id) async {
    await (delete(readingHistory)..where((h) => h.id.equals(id))).go();
  }

  // ── TTS Replacements ────────────────────────────────────────────────────

  /// Get all TTS replacement rules, ordered by creation date.
  Future<List<TtsReplacement>> getAllTtsReplacements() async {
    return (select(ttsReplacements)
          ..orderBy([(r) => OrderingTerm(expression: r.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  /// Add a new TTS replacement rule.
  Future<int> addTtsReplacement({
    required String pattern,
    required String replacement,
    bool isRegex = false,
    bool enabled = true,
  }) async {
    return into(ttsReplacements).insert(TtsReplacementsCompanion(
      pattern: Value(pattern),
      replacement: Value(replacement),
      isRegex: Value(isRegex),
      enabled: Value(enabled),
      createdAt: Value(DateTime.now()),
    ));
  }

  /// Update an existing TTS replacement rule.
  Future<void> updateTtsReplacement(
    int id, {
    required String pattern,
    required String replacement,
    required bool isRegex,
    required bool enabled,
  }) async {
    await (update(ttsReplacements)..where((r) => r.id.equals(id))).write(TtsReplacementsCompanion(
      pattern: Value(pattern),
      replacement: Value(replacement),
      isRegex: Value(isRegex),
      enabled: Value(enabled),
    ));
  }

  /// Toggle a TTS replacement rule's enabled state.
  Future<void> toggleTtsReplacement(int id, bool enabled) async {
    await (update(ttsReplacements)..where((r) => r.id.equals(id))).write(TtsReplacementsCompanion(
      enabled: Value(enabled),
    ));
  }

  /// Delete a TTS replacement rule by ID.
  Future<void> deleteTtsReplacement(int id) async {
    await (delete(ttsReplacements)..where((r) => r.id.equals(id))).go();
  }

  /// Apply all enabled TTS replacement rules to [text]. Returns the
  /// transformed text.
  Future<String> applyTtsReplacements(String text) async {
    final rules = await (select(ttsReplacements)
          ..where((r) => r.enabled.equals(true)))
        .get();
    if (rules.isEmpty) return text;

    var result = text;
    for (final rule in rules) {
      try {
        if (rule.isRegex) {
          result = result.replaceAll(RegExp(rule.pattern), rule.replacement);
        } else {
          result = result.replaceAll(rule.pattern, rule.replacement);
        }
      } catch (_) {
        // Skip invalid regex patterns silently
      }
    }
    return result;
  }

  // ── Search Index ───────────────────────────────────────────────────────

  /// Check whether the search index has been built.
  Future<bool> isSearchIndexBuilt() async {
    try {
      final rows = await customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='search_fts'",
      ).get();
      if (rows.isEmpty) return false;
      // Also check that search_words exists
      final wordRows = await customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='search_words'",
      ).get();
      return wordRows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Build the full-text search index from the main Tipitaka database.
  /// This should be called once after the app database is first opened.
  /// Returns the number of indexed pages and the number of unique words.
  Future<({int pages, int words})> buildSearchIndex(
    EpitakaDatabase epitakaDb, {
    IndexProgressCallback? onProgress,
  }) async {
    debugPrint('[INDEX] Building Pāli search index…');
    final stopwatch = Stopwatch()..start();

    // Get all sentences grouped by (book_id, para_id) BEFORE opening the
    // write transaction below, since epitakaDb is a different connection
    // and we don't want to hold our own transaction open while waiting on
    // another database.
    //
    // Indexing by para_id (rather than the old vripage/page grouping)
    // means each FTS row is one paragraph, so a match points straight at
    // its paragraph instead of the whole page — no separate pali_definition
    // JOIN is needed afterwards to work out where on the page the match
    // actually occurred.
    debugPrint('[INDEX] Querying sentences from epitaka.db…');
    final pageRows = await epitakaDb.customSelect(
      "SELECT book_id, para_id, group_concat(pali, ' ') as pali_text "
      'FROM sentences '
      'WHERE para_id IS NOT NULL '
      'GROUP BY book_id, para_id '
      'ORDER BY book_id, para_id',
    ).get();

    debugPrint('[INDEX] Found ${pageRows.length} para_id groups to index');
    final totalPages = pageRows.length;
    onProgress?.call(0.02, 'Indexing $totalPages Pāli pages…');

    int insertedPages = 0;
    int wordCount = 0;
    final wordCounts = <String, int>{};

    // Everything below runs inside ONE transaction. If the app is killed
    // mid-build, SQLite rolls the whole thing back on next open instead of
    // leaving the FTS5 shadow tables half-written (that half-written state
    // was the cause of the "works, then corrupted after restart" bug).
    await transaction(() async {
      await customStatement('DROP TABLE IF EXISTS search_fts');
      await customStatement('DROP TABLE IF EXISTS search_words');

      await customStatement(
        'CREATE VIRTUAL TABLE search_fts USING fts5('
        '  book_id UNINDEXED,'
        '  para_id UNINDEXED,'
        '  pali_text,'
        "  tokenize='unicode61 remove_diacritics 0'"
        ')',
      );
      await customStatement(
        'CREATE TABLE search_words ('
        '  id INTEGER PRIMARY KEY AUTOINCREMENT,'
        '  pali TEXT NOT NULL,'
        '  fuzzy TEXT NOT NULL,'
        '  count INTEGER NOT NULL DEFAULT 0'
        ')',
      );
      await customStatement('CREATE INDEX idx_search_words_pali ON search_words(pali)');
      await customStatement('CREATE INDEX idx_search_words_fuzzy ON search_words(fuzzy)');

      const yieldInterval = 200;
      int yieldCounter = 0;

      for (final row in pageRows) {
        final bookId = row.data['book_id'] as String;
        final paraId = row.data['para_id'] as int;
        var paliText = row.data['pali_text'] as String;

        // Lowercase BEFORE cleaning/indexing so "Citta" and "citta" become
        // the same FTS token and the same search_words entry. Without
        // this, suggestions treated them as two unrelated words.
        paliText = _cleanPaliText(paliText.toLowerCase());
        if (paliText.isEmpty) continue;

        await customStatement(
          'INSERT INTO search_fts(book_id, para_id, pali_text) VALUES (?, ?, ?)',
          [bookId, paraId, paliText],
        );
        insertedPages++;
        yieldCounter++;

        for (final w in paliText.split(RegExp(r'\s+'))) {
          if (w.isNotEmpty) {
            wordCounts[w] = (wordCounts[w] ?? 0) + 1;
          }
        }

        if (insertedPages % 50 == 0 || insertedPages == totalPages) {
          final p = 0.02 + (insertedPages / totalPages) * 0.50;
          onProgress?.call(p.clamp(0.02, 0.52), 'Indexing Pāli texts… $insertedPages / $totalPages pages');
        }

        // Yielding inside a transaction still keeps the UI responsive
        // (this is cooperative multitasking on the same isolate) without
        // giving up the atomicity of the transaction itself.
        if (yieldCounter >= yieldInterval) {
          await Future.delayed(Duration.zero);
          yieldCounter = 0;
        }
      }

      final wordTotal = wordCounts.length;
      for (final entry in wordCounts.entries) {
        final fuzzy = _normalizeFuzzy(entry.key);
        await customStatement(
          'INSERT INTO search_words(pali, fuzzy, count) VALUES (?, ?, ?)',
          [entry.key, fuzzy, entry.value],
        );
        wordCount++;

        if (wordCount % 200 == 0 || wordCount == wordTotal) {
          final p = 0.55 + (wordCount / wordTotal) * 0.45;
          onProgress?.call(p.clamp(0.55, 1.0), 'Building word index… $wordCount / $wordTotal words');
        }
        if (wordCount % 200 == 0) {
          await Future.delayed(Duration.zero);
        }
      }
    });

    stopwatch.stop();
    debugPrint('[INDEX] Pāli index built: $insertedPages pages, $wordCount words in ${stopwatch.elapsed.inSeconds}s');
    return (pages: insertedPages, words: wordCount);
  }

  /// Build an FTS index for a translation database.
  /// Creates a table named `search_fts_{langCode}` in app_data.db.
  /// Returns the number of indexed sentences.
  Future<int> buildTranslationSearchIndex(
    String langCode,
    TranslationDatabase translationDb, {
    IndexProgressCallback? onProgress,
  }) async {
    debugPrint('[INDEX] Building $langCode translation search index…');
    final stopwatch = Stopwatch()..start();
    final tableName = 'search_fts_$langCode';

    debugPrint('[INDEX] Querying $langCode translation sentences…');
    final sentenceRows = await translationDb.customSelect(
      "SELECT book_id, para_id, group_concat(translation, ' ') as translation_text "
      'FROM sentences '
      "WHERE translation IS NOT NULL AND translation != '' "
      'GROUP BY book_id, para_id '
      'ORDER BY book_id, para_id',
    ).get();

    debugPrint('[INDEX] Found ${sentenceRows.length} $langCode paragraphs to index');
    if (sentenceRows.isEmpty) return 0;

    final totalRows = sentenceRows.length;
    onProgress?.call(0.0, 'Indexing $totalRows ${langCode.toUpperCase()} translation paragraphs…');

    int count = 0;
    final wordCounts = <String, int>{};

    // One transaction for the whole build — same corruption fix as the
    // Pāli index above.
    await transaction(() async {
      await customStatement('DROP TABLE IF EXISTS $tableName');
      await customStatement(
        'CREATE VIRTUAL TABLE $tableName USING fts5('
        '  book_id UNINDEXED,'
        '  para_id UNINDEXED,'
        '  translation_text,'
        "  tokenize='unicode61 remove_diacritics 0'"
        ')',
      );
      // Word suggestions for THIS language. Kept per-language (rather than
      // merged into search_words) since "citta" in Pāli and "citta" as an
      // English loanword shouldn't be conflated, and different
      // translations may use different vocabularies.
      await customStatement('DROP TABLE IF EXISTS search_words_$langCode');
      await customStatement(
        'CREATE TABLE search_words_$langCode ('
        '  id INTEGER PRIMARY KEY AUTOINCREMENT,'
        '  word TEXT NOT NULL,'
        '  count INTEGER NOT NULL DEFAULT 0'
        ')',
      );
      await customStatement(
        'CREATE INDEX idx_search_words_${langCode}_word ON search_words_$langCode(word)',
      );

      const yieldInterval = 200;
      int yieldCounter = 0;

      for (final row in sentenceRows) {
        final bookId = row.data['book_id'] as String;
        final paraId = row.data['para_id'] as int;
        var translationText = row.data['translation_text'] as String;

        // Lowercase up front (same fix as the Pāli index) so "Citta" and
        // "citta" collapse into one suggestion entry.
        translationText = translationText
            .toLowerCase()
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll(RegExp(r'[\[\](){}⟨⟩:;.,!?…—–\-"«»“”' "'"
                r']'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (translationText.isEmpty) continue;

        await customStatement(
          'INSERT INTO $tableName(book_id, para_id, translation_text) VALUES (?, ?, ?)',
          [bookId, paraId, translationText],
        );
        count++;
        yieldCounter++;

        for (final w in translationText.split(' ')) {
          if (w.length > 1) {
            wordCounts[w] = (wordCounts[w] ?? 0) + 1;
          }
        }

        // Report progress every 50 rows — reporting every 10 (as before)
        // meant firing a Riverpod state update roughly 10x more often
        // than necessary, which itself was a meaningful chunk of the
        // "translation indexing is slow" complaint.
        if (count % 50 == 0 || count == totalRows) {
          final p = (count / totalRows).clamp(0.0, 1.0);
          onProgress?.call(p, 'Indexing ${langCode.toUpperCase()} translation… $count / $totalRows paragraphs');
        }
        if (yieldCounter >= yieldInterval) {
          await Future.delayed(Duration.zero);
          yieldCounter = 0;
        }
      }

      for (final entry in wordCounts.entries) {
        await customStatement(
          'INSERT INTO search_words_$langCode(word, count) VALUES (?, ?)',
          [entry.key, entry.value],
        );
      }
    });

    stopwatch.stop();
    debugPrint('[INDEX] $langCode translation index built: $count paragraphs, '
        '${wordCounts.length} words in ${stopwatch.elapsed.inSeconds}s');
    return count;
  }

  /// Check whether a translation FTS index exists for [langCode].
  Future<bool> isTranslationIndexBuilt(String langCode) async {
    final tableName = 'search_fts_$langCode';
    try {
      final rows = await customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        variables: [Variable.withString(tableName)],
      ).get();
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Search a translation FTS index for [query].
  /// Returns matching sentences with translation snippets.
  Future<List<SearchResultRow>> searchTranslationFts(
    String langCode,
    String query, {
    bool fuzzy = false,
    int distance = 0,
  }) async {
    final tableName = 'search_fts_$langCode';

    // Check if the table exists first
    final exists = await isTranslationIndexBuilt(langCode);
    if (!exists) return [];

    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];

    String ftsQuery;

    if (fuzzy) {
      // For fuzzy search on translations, we do a LIKE-based fallback
      // since translations are in modern languages (not Pali).
      return _translationFuzzySearch(tableName, normalized);
    } else if (distance > 0) {
      // FTS5 has no `term1 NEAR/N term2` operator — that's FTS3/4 syntax
      // and FTS5's parser doesn't accept it. FTS5's NEAR is a function
      // call: NEAR(term1 term2 ..., N).
      final terms = normalized
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .map((w) => '${_escapeFtsTerm(w)}*')
          .join(' ');
      ftsQuery = 'NEAR($terms, $distance)';
    } else {
      final terms = normalized
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .map((w) => '${_escapeFtsTerm(w)}*')
          .join(' AND ');
      ftsQuery = terms;
    }

    try {
      final rows = await customSelect(
        'SELECT book_id, para_id, '
        "snippet($tableName, 1, '<b>', '</b>', '…', 48) as snippet_text "
        'FROM $tableName '
        'WHERE translation_text MATCH ? '
        'ORDER BY rank '
        'LIMIT 100',
        variables: [Variable.withString(ftsQuery)],
      ).get();

      return rows
          .map((r) => SearchResultRow(
                bookId: r.data['book_id'] as String,
                vripage: '',
                snippet: r.data['snippet_text'] as String? ?? '',
                firstParaId: r.data['para_id'] as int?,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fallback fuzzy search for translation FTS: uses LIKE on stored text
  /// since translations are in modern languages without Pali diacritics.
  Future<List<SearchResultRow>> _translationFuzzySearch(
    String tableName,
    String normalized,
  ) async {
    try {
      // First, get all distinct book_id, para_id pairs that match the query
      final rows = await customSelect(
        'SELECT DISTINCT book_id, para_id '
        'FROM $tableName '
        'WHERE translation_text LIKE ? '
        'ORDER BY book_id, para_id '
        'LIMIT 100',
        variables: [Variable.withString('%$normalized%')],
      ).get();

      return rows.map((r) => SearchResultRow(
            bookId: r.data['book_id'] as String,
            vripage: '',
            snippet: '...$normalized...',
            firstParaId: r.data['para_id'] as int?,
          )).toList();
    } catch (_) {
      return [];
    }
  }

  /// Build an FTS5 query string from the user's raw [query].
  /// Handles prefix matching, fuzzy expansion via search_words, and
  /// NEAR/phrase queries. Returns the FTS5-safe query string.
  Future<String> _buildFtsQuery(
    String query, {
    bool fuzzy = false,
    int distance = 0,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return '';

    if (fuzzy) {
      final rawWords = normalized
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      if (rawWords.isEmpty) return '';

      final fuzzyNormalized = _normalizeFuzzy(normalized);
      final fuzzyWords = fuzzyNormalized
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();

      // For each word, find all diacritic variants from search_words.
      // Group per-word so we can apply NEAR/AND between groups.
      final wordGroups = <List<String>>[];
      for (int i = 0; i < fuzzyWords.length; i++) {
        final likePattern = '${fuzzyWords[i]}%';
        final variants = <String>{};
        try {
          final matches = await customSelect(
            'SELECT DISTINCT pali FROM search_words WHERE fuzzy LIKE ? '
            'ORDER BY count DESC LIMIT 30',
            variables: [Variable.withString(likePattern)],
          ).get();
          for (final row in matches) {
            variants.add(row.data['pali'] as String);
          }
        } catch (_) {}

        // Fallback: use the original word form
        if (variants.isEmpty) {
          variants.add(rawWords[i]);
        }
        wordGroups.add(variants.toList());
      }

      if (wordGroups.isEmpty) return '';

      // Build group queries: each group is (var1* OR var2* OR …)
      // meaning ANY diacritic variant of that word is accepted.
      final groupQueries = wordGroups.map((vars) {
        final escaped =
            vars.map((v) => '${v.replaceAll('"', '""')}*').join(' OR ');
        return '($escaped)';
      }).toList();

      // Combine groups: ALL original words must appear (AND).
      //
      // FTS5 has no `group1 NEAR/N group2` operator — that's FTS3/4
      // syntax. FTS5's NEAR is a function call, NEAR(phrase1 phrase2 ...,
      // N), and each phrase argument must be a plain token/phrase, not a
      // parenthesized OR sub-expression like the `(var1* OR var2*)`
      // groups above. So when distance>0 we can't feed the full
      // variant-OR groups into NEAR(); instead take each word's
      // highest-frequency variant (wordGroups entries are already
      // ordered by count DESC) to build a valid NEAR() phrase list.
      if (distance > 0 && wordGroups.length > 1) {
        final nearTerms = wordGroups
            .map((vars) => '${vars.first.replaceAll('"', '""')}*')
            .join(' ');
        return 'NEAR($nearTerms, $distance)';
      }
      return groupQueries.join(' AND ');
    }

    if (distance > 0) {
      // Same FTS5 NEAR() fix as above: NEAR is a function call, not a
      // `term1 NEAR/N term2` infix operator.
      final terms = normalized
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .map((w) => '${_escapeFtsTerm(w)}*')
          .join(' ');
      return 'NEAR($terms, $distance)';
    }

    final terms = normalized
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${_escapeFtsTerm(w)}*')
        .join(' AND ');
    return terms;
  }

  /// Count search results grouped by book_id from the Pali FTS index.
  /// Returns a map of book_id -> count.
  Future<Map<String, int>> countPaliResultsByBook(
    String query, {
    bool fuzzy = false,
    int distance = 0,
  }) async {
    final ftsQuery = await _buildFtsQuery(query, fuzzy: fuzzy, distance: distance);
    if (ftsQuery.isEmpty) return {};

    try {
      final rows = await customSelect(
        'SELECT book_id, COUNT(*) as cnt '
        'FROM search_fts '
        'WHERE pali_text MATCH ? '
        'GROUP BY book_id '
        'ORDER BY book_id',
        variables: [Variable.withString(ftsQuery)],
      ).get();

      return {for (final r in rows) r.data['book_id'] as String: (r.data['cnt'] as num).toInt()};
    } catch (_) {
      return {};
    }
  }

  /// Count search results grouped by book_id from a translation FTS index.
  Future<Map<String, int>> countTranslationResultsByBook(
    String langCode,
    String query, {
    bool fuzzy = false,
    int distance = 0,
  }) async {
    final tableName = 'search_fts_$langCode';
    final exists = await isTranslationIndexBuilt(langCode);
    if (!exists) return {};

    // For translations, we use LIKE-based fuzzy for non-Pali languages
    if (fuzzy) {
      try {
        final normalized = query.trim().toLowerCase();
        final rows = await customSelect(
          'SELECT book_id, COUNT(*) as cnt '
          'FROM $tableName '
          "WHERE translation_text LIKE '%' || ? || '%' "
          'GROUP BY book_id '
          'ORDER BY book_id',
          variables: [Variable.withString(normalized)],
        ).get();
        return {for (final r in rows) r.data['book_id'] as String: (r.data['cnt'] as num).toInt()};
      } catch (_) {
        return {};
      }
    }

    final ftsQuery = await _buildFtsQuery(query, fuzzy: false, distance: distance);
    if (ftsQuery.isEmpty) return {};

    try {
      final rows = await customSelect(
        'SELECT book_id, COUNT(*) as cnt '
        'FROM $tableName '
        'WHERE translation_text MATCH ? '
        'GROUP BY book_id '
        'ORDER BY book_id',
        variables: [Variable.withString(ftsQuery)],
      ).get();
      return {for (final r in rows) r.data['book_id'] as String: (r.data['cnt'] as num).toInt()};
    } catch (_) {
      return {};
    }
  }

  /// Fetch paginated Pali FTS results for a specific [bookId].
  /// Returns the matching para_ids with highlighted snippets and full text.
  Future<List<SearchResultRow>> searchPaliFtsByBook(
    String bookId,
    String query, {
    bool fuzzy = false,
    int distance = 0,
    int limit = 30,
    int offset = 0,
  }) async {
    final ftsQuery = await _buildFtsQuery(query, fuzzy: fuzzy, distance: distance);
    if (ftsQuery.isEmpty) return [];

    try {
      final rows = await customSelect(
        "SELECT book_id, para_id, "
        "snippet(search_fts, 2, '<mark>', '</mark>', '…', 20) as snippet_text, "
        'pali_text '
        'FROM search_fts '
        'WHERE pali_text MATCH ? AND book_id = ? '
        'ORDER BY rank '
        'LIMIT ? OFFSET ?',
        variables: [
          Variable.withString(ftsQuery),
          Variable.withString(bookId),
          Variable.withInt(limit),
          Variable.withInt(offset),
        ],
      ).get();

      return rows
          .map((r) => SearchResultRow(
                bookId: r.data['book_id'] as String,
                vripage: '',
                firstParaId: r.data['para_id'] as int?,
                snippet: r.data['snippet_text'] as String? ?? '',
                paliText: r.data['pali_text'] as String? ?? '',
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch paginated translation FTS results for a specific [bookId].
  Future<List<SearchResultRow>> searchTranslationFtsByBook(
    String langCode,
    String bookId,
    String query, {
    bool fuzzy = false,
    int distance = 0,
    int limit = 30,
    int offset = 0,
  }) async {
    final tableName = 'search_fts_$langCode';
    final exists = await isTranslationIndexBuilt(langCode);
    if (!exists) return [];

    if (fuzzy) {
      try {
        final normalized = query.trim().toLowerCase();
        final rows = await customSelect(
          "SELECT book_id, para_id, "
          "'…<mark>' || ? || '</mark>…' as snippet_text, "
          'translation_text '
          'FROM $tableName '
          "WHERE translation_text LIKE '%' || ? || '%' AND book_id = ? "
          'ORDER BY book_id, para_id '
          'LIMIT ? OFFSET ?',
          variables: [
            Variable.withString(normalized),
            Variable.withString(normalized),
            Variable.withString(bookId),
            Variable.withInt(limit),
            Variable.withInt(offset),
          ],
        ).get();
        return rows
            .map((r) => SearchResultRow(
                  bookId: r.data['book_id'] as String,
                  vripage: '',
                  firstParaId: r.data['para_id'] as int?,
                  snippet: r.data['snippet_text'] as String? ?? '',
                  translation: r.data['translation_text'] as String? ?? '',
                ))
            .toList();
      } catch (_) {
        return [];
      }
    }

    final ftsQuery = await _buildFtsQuery(query, fuzzy: false, distance: distance);
    if (ftsQuery.isEmpty) return [];

    try {
      final rows = await customSelect(
        "SELECT book_id, para_id, "
        "snippet($tableName, 2, '<mark>', '</mark>', '…', 30) as snippet_text, "
        'translation_text '
        'FROM $tableName '
        'WHERE translation_text MATCH ? AND book_id = ? '
        'ORDER BY rank '
        'LIMIT ? OFFSET ?',
        variables: [
          Variable.withString(ftsQuery),
          Variable.withString(bookId),
          Variable.withInt(limit),
          Variable.withInt(offset),
        ],
      ).get();

      return rows
          .map((r) => SearchResultRow(
                bookId: r.data['book_id'] as String,
                vripage: '',
                firstParaId: r.data['para_id'] as int?,
                snippet: r.data['snippet_text'] as String? ?? '',
                translation: r.data['translation_text'] as String? ?? '',
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Search the Pali FTS index for [query]. Returns matching pages with
  /// the highlighted snippet plus the full `pali_text` (so the provider can
  /// render richer results and look up translations).
  ///
  /// Uses FTS5 prefix matching (`term*`) so that "cakk" also finds
  /// "cakka", "cakkhu", "cakkuṃ" etc.
  Future<List<SearchResultRow>> searchFts(
    String query, {
    bool fuzzy = false,
    int distance = 0,
  }) async {
    final ftsQuery = await _buildFtsQuery(query, fuzzy: fuzzy, distance: distance);
    if (ftsQuery.isEmpty) return [];

    try {
      final rows = await customSelect(
        "SELECT book_id, para_id, "
        "snippet(search_fts, 2, '<b>', '</b>', '…', 48) as snippet_text, "
        'pali_text '
        'FROM search_fts '
        'WHERE pali_text MATCH ? '
        'ORDER BY rank '
        'LIMIT 200',
        variables: [Variable.withString(ftsQuery)],
      ).get();

      return rows
          .map((r) => SearchResultRow(
                bookId: r.data['book_id'] as String,
                vripage: '',
                firstParaId: r.data['para_id'] as int?,
                snippet: r.data['snippet_text'] as String? ?? '',
                paliText: r.data['pali_text'] as String? ?? '',
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get word suggestions for autocomplete. Returns words that start with
  /// [prefix] (or whose fuzzy equivalent does), ordered by frequency.
  Future<List<SearchSuggestion>> getSearchSuggestions(
    String prefix, {
    int limit = 10,
    String? translationLangCode,
  }) async {
    final trimmed = prefix.trim().toLowerCase();
    if (trimmed.isEmpty) return [];

    final fuzzy = _normalizeFuzzy(trimmed);

    final rows = await customSelect(
      'SELECT pali, fuzzy, count FROM search_words '
      'WHERE pali LIKE ?1 OR fuzzy LIKE ?2 '
      'ORDER BY count DESC LIMIT ?3',
      variables: [
        Variable.withString('$trimmed%'),
        Variable.withString('$fuzzy%'),
        Variable.withInt(limit),
      ],
    ).get();

    final suggestions = rows
        .map((r) => SearchSuggestion(
              pali: r.data['pali'] as String,
              fuzzy: r.data['fuzzy'] as String,
              count: r.data['count'] as int,
              source: SuggestionSource.pali,
            ))
        .toList();

    // Also pull translation-word suggestions for the active language, if
    // that table exists. Previously getSearchSuggestions only ever read
    // search_words (Pāli), so a search for an English term like "mind"
    // never suggested anything — this was the "suggestions only show
    // Pāli terms" bug.
    if (translationLangCode != null) {
      final tableName = 'search_words_$translationLangCode';
      try {
        final exists = await customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          variables: [Variable.withString(tableName)],
        ).get();
        if (exists.isNotEmpty) {
          final tRows = await customSelect(
            'SELECT word, count FROM $tableName '
            'WHERE word LIKE ?1 '
            'ORDER BY count DESC LIMIT ?2',
            variables: [
              Variable.withString('$trimmed%'),
              Variable.withInt(limit),
            ],
          ).get();
          suggestions.addAll(tRows.map((r) => SearchSuggestion(
                pali: r.data['word'] as String,
                fuzzy: r.data['word'] as String,
                count: r.data['count'] as int,
                source: SuggestionSource.translation,
              )));
        }
      } catch (_) {
        // Translation suggestions are optional.
      }
    }

    suggestions.sort((a, b) => b.count.compareTo(a.count));
    return suggestions.take(limit).toList();
  }

  /// Rebuild the search index from scratch.
  Future<({int pages, int words})> rebuildSearchIndex(
    EpitakaDatabase epitakaDb, {
    IndexProgressCallback? onProgress,
  }) async {
    return buildSearchIndex(epitakaDb, onProgress: onProgress);
  }

  // ── Search helpers ────────────────────────────────────────────────────

  String _cleanPaliText(String text) {
    return cleanPaliForIndexing(text);
  }

  String _normalizeFuzzy(String text) {
    return normalizePaliFuzzy(text);
  }

  /// Escape an FTS5 term for safe use in a query string.
  /// Replaces double-quotes and wraps in a `"…"` pair only if the term
  /// contains special FTS5 characters (so a simple prefix like `cakk*`
  /// stays clean).
  String _escapeFtsTerm(String term) {
    // Replace any embedded double-quotes
    final safe = term.replaceAll('"', '""');
    // FTS5 special chars: ^ * ( ) " ~ NEAR OR AND NOT
    // If the term has any of these (other than normal letters), quote it.
    if (safe.contains(RegExp(r'[()^~"\s]'))) {
      return '"$safe"';
    }
    return safe;
  }
}

// ── Search result types (public for use by search_provider) ──────────────

/// A single row from an FTS search result.
class SearchResultRow {
  final String bookId;
  final String vripage;
  final String snippet;

  /// The full Pali text for this page (from FTS, unbolded).
  final String paliText;

  /// Translation text for the first paragraph of this page (optional).
  final String? translation;

  /// Para-level identifier. Set for both Pali FTS results (indexed by
  /// para_id) and translation FTS results.
  final int? firstParaId;

  const SearchResultRow({
    required this.bookId,
    required this.vripage,
    required this.snippet,
    this.paliText = '',
    this.translation,
    this.firstParaId,
  });
}

enum SuggestionSource { pali, translation }

/// A word suggestion for autocomplete.
class SearchSuggestion {
  final String pali;
  final String fuzzy;
  final int count;
  final SuggestionSource source;

  const SearchSuggestion({
    required this.pali,
    required this.fuzzy,
    required this.count,
    this.source = SuggestionSource.pali,
  });
}

// ── Search filter model ──────────────────────────────────────────────────

/// Represents a book filter option (by category or nikaya).
class BookFilterOption {
  final String label;
  final String? category;
  final String? nikaya;
  bool selected;

  BookFilterOption({
    required this.label,
    this.category,
    this.nikaya,
    this.selected = true,
  });
}