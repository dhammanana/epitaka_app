import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../features/ai_qa/models/ai_qa_models.dart'
    show ChatThread, ChatMessageRecord;
import '../utils/database_initializer.dart';
import 'drift_database_executor.dart';
import '../utils/pali_search_utils.dart';
import 'epitaka_database.dart';
import 'translation_database.dart';

part 'app_database.g.dart';

// ── Progress callback ──────────────────────────────────────────────────

/// Callback for reporting indexing progress (0.0–1.0) with a status message.
typedef IndexProgressCallback = void Function(double progress, String status);

/// Bumped whenever the FTS5 index schema changes in a way that makes
/// indexes built by older app versions incompatible (tokenizer options,
/// column layout, …). Each index build stamps this version into the
/// `index_meta` table; the "is built" checks treat a missing or older
/// stamp as "not built", so after an upgrade the app rebuilds the affected
/// index once through the normal build gate.
///
///   v1 — published builds: `unicode61 remove_diacritics 0` (tokens keep
///        diacritics, so `katva` cannot match `katvā`).
///   v2 — `unicode61 remove_diacritics 1` (diacritic-insensitive search).
const int kSearchIndexSchemaVersion = 2;

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
// Table: annotations (highlights, notes, bookmarks — unified & synced)
// ---------------------------------------------------------------------------
// The generated row class is named `AnnotationRow` (via @DataClassName) so it
// doesn't collide with the domain model `Annotation` in
// features/annotations/models/annotation.dart.
@DataClassName('AnnotationRow')
class Annotations extends Table {
  /// Client-generated UUID. Identical on the local device and on Supabase,
  /// which makes upsert-based sync idempotent. Marked as the primary key so
  /// Drift's `insertOnConflictUpdate` can build its `ON CONFLICT (id)`
  /// clause — without it, saving a bookmark/highlight/note throws
  /// "Invalid arguments: table has no primary key".
  @override
  Set<Column> get primaryKey => {id};
  TextColumn get id => text()();

  /// 'highlight' | 'note' | 'bookmark'.
  TextColumn get type => text()();
  TextColumn get bookId => text()();
  TextColumn get bookName => text().nullable()();
  IntColumn get paraId => integer().nullable()();
  IntColumn get lineId => integer().nullable()();

  /// Which text the anchor points at: 'pali' | 'translation' | null (bookmark).
  TextColumn get segment => text().nullable()();

  /// Translation language code when [segment] == 'translation'.
  TextColumn get langCode => text().nullable()();

  /// Character offsets inside the segment's *stripped* text.
  IntColumn get startOffset => integer().nullable()();
  IntColumn get endOffset => integer().nullable()();

  /// Text-quote selector for re-anchoring (robust across script/font changes).
  TextColumn get exactText => text().nullable()();
  TextColumn get prefixText => text().nullable()();
  TextColumn get suffixText => text().nullable()();

  /// Highlight color key ('yellow', 'green', …) — null for bookmarks.
  TextColumn get color => text().nullable()();

  /// Markdown note body — non-null when this is a note/highlight-with-note.
  TextColumn get note => text().nullable()();

  /// Bookmark name / page number (bookmark-only fields).
  TextColumn get name => text().nullable()();
  TextColumn get pageNumber => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Soft-delete marker; deletions propagate through sync without races.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// True when this row has local changes not yet pushed to Supabase.
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  /// `updated_at` on the server — used for last-write-wins conflict
  /// resolution during pull/merge.
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();
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
@DriftDatabase(tables: [Bookmarks, ReadingHistory, TtsReplacements, Annotations])
class AppDatabase extends _$AppDatabase {
  // ── Chat Threads & Messages (raw SQL tables) ──────────────────────────

  /// Ensure chat_* tables exist (called on first use).
  Future<void> _ensureChatTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS chat_threads (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        message_count INTEGER NOT NULL DEFAULT 0,
        max_messages INTEGER NOT NULL DEFAULT 8
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        thread_id TEXT NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
        role TEXT NOT NULL CHECK(role IN ('user', 'assistant')),
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        metadata TEXT
      )
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_chat_messages_thread
      ON chat_messages(thread_id, created_at ASC)
    ''');
  }

  // ── Thread CRUD ───────────────────────────────────────────────────────

  /// Create a new chat thread.
  Future<ChatThread> createChatThread({
    required String id,
    required String title,
    int maxMessages = 8,
  }) async {
    await _ensureChatTables();
    final now = DateTime.now().toIso8601String();
    await customStatement(
      'INSERT INTO chat_threads(id, title, created_at, updated_at, message_count, max_messages) '
      'VALUES (?, ?, ?, ?, 0, ?)',
      [id, title, now, now, maxMessages],
    );
    return ChatThread(
      id: id,
      title: title,
      createdAt: DateTime.parse(now),
      updatedAt: DateTime.parse(now),
      messageCount: 0,
      maxMessages: maxMessages,
    );
  }

  /// Get all chat threads ordered by most recent first.
  Future<List<ChatThread>> getAllChatThreads() async {
    await _ensureChatTables();
    final rows = await customSelect(
      'SELECT * FROM chat_threads ORDER BY updated_at DESC',
    ).get();
    return rows
        .map(
          (r) => ChatThread.fromJson({
            'id': r.data['id'] as String,
            'title': r.data['title'] as String,
            'created_at': r.data['created_at'] as String,
            'updated_at': r.data['updated_at'] as String,
            'message_count': r.data['message_count'] as int,
            'max_messages': r.data['max_messages'] as int,
          }),
        )
        .toList();
  }

  /// Get a single thread by ID.
  Future<ChatThread?> getChatThread(String id) async {
    await _ensureChatTables();
    final rows = await customSelect(
      'SELECT * FROM chat_threads WHERE id = ?',
      variables: [Variable.withString(id)],
    ).get();
    if (rows.isEmpty) return null;
    final r = rows.first.data;
    return ChatThread.fromJson({
      'id': r['id'] as String,
      'title': r['title'] as String,
      'created_at': r['created_at'] as String,
      'updated_at': r['updated_at'] as String,
      'message_count': r['message_count'] as int,
      'max_messages': r['max_messages'] as int,
    });
  }

  /// Update thread title.
  Future<void> updateChatThreadTitle(String id, String title) async {
    await _ensureChatTables();
    await customStatement(
      'UPDATE chat_threads SET title = ?, updated_at = ? WHERE id = ?',
      [title, DateTime.now().toIso8601String(), id],
    );
  }

  /// Increment message count and update timestamp.
  Future<void> incrementChatThreadMessageCount(String id) async {
    await _ensureChatTables();
    await customStatement(
      'UPDATE chat_threads SET message_count = message_count + 1, '
      'updated_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), id],
    );
  }

  /// Delete a chat thread and all its messages.
  Future<void> deleteChatThread(String id) async {
    await _ensureChatTables();
    await customStatement('DELETE FROM chat_messages WHERE thread_id = ?', [
      id,
    ]);
    await customStatement('DELETE FROM chat_threads WHERE id = ?', [id]);
  }

  /// Delete all chat threads and messages.
  Future<void> deleteAllChatThreads() async {
    await _ensureChatTables();
    await customStatement('DELETE FROM chat_messages');
    await customStatement('DELETE FROM chat_threads');
  }

  // ── Message CRUD ───────────────────────────────────────────────────────

  /// Save a user message to the database.
  Future<void> saveUserMessage({
    required String threadId,
    required String content,
    String? metadata,
  }) async {
    await _ensureChatTables();
    await customStatement(
      'INSERT INTO chat_messages(thread_id, role, content, created_at, metadata) '
      'VALUES (?, ?, ?, ?, ?)',
      [
        threadId,
        'user',
        content,
        DateTime.now().toIso8601String(),
        metadata ?? '{}',
      ],
    );
  }

  /// Save an assistant message to the database.
  Future<void> saveAssistantMessage({
    required String threadId,
    required String content,
    String? metadata,
  }) async {
    await _ensureChatTables();
    await customStatement(
      'INSERT INTO chat_messages(thread_id, role, content, created_at, metadata) '
      'VALUES (?, ?, ?, ?, ?)',
      [
        threadId,
        'assistant',
        content,
        DateTime.now().toIso8601String(),
        metadata ?? '{}',
      ],
    );
  }

  /// Get all messages for a thread, ordered chronologically.
  Future<List<ChatMessageRecord>> getChatMessages(String threadId) async {
    await _ensureChatTables();
    final rows = await customSelect(
      'SELECT * FROM chat_messages WHERE thread_id = ? ORDER BY created_at ASC, id ASC',
      variables: [Variable.withString(threadId)],
    ).get();
    return rows.map((r) {
      final d = r.data;
      return ChatMessageRecord(
        id: d['id'] as int,
        threadId: d['thread_id'] as String,
        role: d['role'] as String,
        content: d['content'] as String,
        createdAt: DateTime.parse(d['created_at'] as String),
        metadata: d['metadata'] as String?,
      );
    }).toList();
  }

  /// Update an assistant message's content (for stream finalization).
  Future<void> updateAssistantMessage(
    int messageId,
    String content,
    String metadata,
  ) async {
    await _ensureChatTables();
    await customStatement(
      'UPDATE chat_messages SET content = ?, metadata = ? WHERE id = ?',
      [content, metadata, messageId],
    );
  }

  AppDatabase(super.e);

  @override
  int get schemaVersion => 6;

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
        if (from < 3) {
          // Chat tables are created lazily via _ensureChatTables()
        }
        if (from < 4) {
          // Unified annotations table (highlights / notes / bookmarks).
          // Existing bookmarks are copied in as type='bookmark' rows with a
          // freshly generated UUID, so users keep their saved positions and
          // the new cloud sync has a single source of truth.
          await m.createTable(annotations);
          await customStatement('''
            INSERT INTO annotations (
              id, type, book_id, book_name, para_id, line_id,
              name, page_number, created_at, updated_at, deleted_at, dirty
            )
            SELECT
              lower(
                hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-' ||
                '4' || substr(hex(randomblob(2)), 2) || '-' ||
                substr('89ab', abs(random()) % 4 + 1, 1) ||
                substr(hex(randomblob(2)), 2) || '-' || hex(randomblob(6))
              ),
              'bookmark', book_id, book_name, para_id, line_id,
              name, page_number, created_at, updated_at, NULL, 0
            FROM bookmarks
          ''');
        }
        if (from < 5) {
          // The v4 table was created WITHOUT a primary key on `id`, which
          // makes Drift's insertOnConflictUpdate (used for every annotation
          // save) throw "table has no primary key". SQLite cannot add a
          // primary key via ALTER TABLE, so rebuild the table in place:
          // rename old → create new (with PK) → copy rows → drop old. All
          // existing bookmarks/highlights/notes are preserved.
          await customStatement('ALTER TABLE annotations RENAME TO annotations_old');
          await m.createTable(annotations);
          await customStatement('''
            INSERT INTO annotations (
              id, type, book_id, book_name, para_id, line_id,
              segment, lang_code, start_offset, end_offset,
              exact_text, prefix_text, suffix_text, color, note,
              name, page_number, created_at, updated_at, deleted_at,
              dirty, server_updated_at
            )
            SELECT
              id, type, book_id, book_name, para_id, line_id,
              segment, lang_code, start_offset, end_offset,
              exact_text, prefix_text, suffix_text, color, note,
              name, page_number, created_at, updated_at, deleted_at,
              dirty, server_updated_at
            FROM annotations_old
          ''');
          await customStatement('DROP TABLE annotations_old');
        }
        if (from < 6) {
          // Self-healing migration: some devices reached schemaVersion 5
          // with an annotations table that STILL lacks a PRIMARY KEY on
          // `id` (the v5 migration could run against generated code that
          // hadn't yet declared the key). Drift's insertOnConflictUpdate
          // then emits `ON CONFLICT (id)`, which SQLite rejects with
          // "ON CONFLICT clause does not match any PRIMARY KEY or UNIQUE
          // constraint". Rebuild the table only when the key is actually
          // missing, so already-correct tables pass straight through.
          final tables = await customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='annotations'",
          ).get();
          if (tables.isEmpty) {
            await m.createTable(annotations);
          } else {
            final info = await customSelect(
              "SELECT name, pk FROM pragma_table_info('annotations')",
            ).get();
            final idIsPk = info.any(
              (r) => r.data['name'] == 'id' && r.data['pk'] != 0,
            );
            if (!idIsPk) {
              await customStatement(
                'ALTER TABLE annotations RENAME TO annotations_old',
              );
              await m.createTable(annotations);
              await customStatement('''
                INSERT INTO annotations (
                  id, type, book_id, book_name, para_id, line_id,
                  segment, lang_code, start_offset, end_offset,
                  exact_text, prefix_text, suffix_text, color, note,
                  name, page_number, created_at, updated_at, deleted_at,
                  dirty, server_updated_at
                )
                SELECT
                  id, type, book_id, book_name, para_id, line_id,
                  segment, lang_code, start_offset, end_offset,
                  exact_text, prefix_text, suffix_text, color, note,
                  name, page_number, created_at, updated_at, deleted_at,
                  dirty, server_updated_at
                FROM annotations_old
              ''');
              await customStatement('DROP TABLE annotations_old');
            }
          }
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
    final dir = await getDatabaseDirectory();
    final dbPath = p.join(dir.path, 'app_data.db');
    final file = File(dbPath);

    debugPrint(
      '[DB] Opening app_data.db at: $dbPath (exists: ${file.existsSync()})',
    );

    try {
      final db = AppDatabase._create(file);
      // Force the connection to actually run its first query now, rather
      // than lazily on first use, so a corrupted file fails here.
      await db.customSelect('PRAGMA user_version').get();
      debugPrint('[DB] AppDatabase opened successfully');
      return db;
    } catch (e) {
      debugPrint(
        '[DB] First open failed: $e — clearing stale WAL/SHM and retrying once…',
      );
    }

    // Retry once after clearing journals left behind by an unclean
    // shutdown. This is safe to attempt (it does NOT touch app_data.db
    // itself) and resolves the common "leftover WAL from a killed app"
    // case without any data loss.
    _deleteJournalFiles(dbPath);
    try {
      final db = AppDatabase._create(file);
      await db.customSelect('PRAGMA user_version').get();
      debugPrint(
        '[DB] AppDatabase opened successfully after clearing journals',
      );
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
    final dir = await getDatabaseDirectory();
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
      if (exists.isEmpty) {
        return true; // nothing built yet, nothing to be corrupt
      }
      // FTS5's built-in self-check: throws if the shadow tables disagree
      // with the index content.
      await customStatement(
        "INSERT INTO search_fts(search_fts) VALUES('integrity-check')",
      );
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
    final database = openDriftExecutor(
      file,
      setup: (db) {
        try {
          db.execute('PRAGMA journal_mode=WAL');
        } catch (_) {}
        try {
          db.execute('PRAGMA foreign_keys=ON');
        } catch (_) {}
        try {
          db.execute('PRAGMA mmap_size=0'); // ← add this line
        } catch (_) {}
      },
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
    final id = await into(bookmarks).insert(
      BookmarksCompanion(
        name: Value(name),
        bookId: Value(bookId),
        paraId: Value(paraId),
        lineId: Value(lineId),
        bookName: Value(bookName),
        pageNumber: Value(pageNumber),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    return (await (select(
      bookmarks,
    )..where((b) => b.id.equals(id))).get()).first;
  }

  /// Delete a bookmark by ID.
  Future<void> deleteBookmark(int id) async {
    await (delete(bookmarks)..where((b) => b.id.equals(id))).go();
  }

  /// Get all bookmarks, ordered by most recent first.
  Future<List<Bookmark>> getAllBookmarks() async {
    return (select(bookmarks)..orderBy([
          (b) => OrderingTerm(expression: b.createdAt, mode: OrderingMode.desc),
        ]))
        .get();
  }

  /// Get bookmarks for a specific book.
  Future<List<Bookmark>> getBookmarksForBook(String bookId) async {
    return (select(bookmarks)
          ..where((b) => b.bookId.equals(bookId))
          ..orderBy([
            (b) =>
                OrderingTerm(expression: b.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  // ── Annotations (highlights, notes, bookmarks — unified) ───────────────

  /// Insert or update an annotation row. [id] is client-generated so the
  /// same UUID exists locally and on the server (idempotent upserts).
  ///
  /// Implemented as a manual read-then-write (not `insertOnConflictUpdate`)
  /// so it works even when the SQLite table has no PRIMARY KEY / UNIQUE
  /// constraint on `id` — e.g. devices whose `annotations` table predates
  /// the primary-key migration. `insertOnConflictUpdate` emits
  /// `ON CONFLICT (id)`, which SQLite rejects with "ON CONFLICT clause does
  /// not match any PRIMARY KEY or UNIQUE constraint" on such tables,
  /// silently failing every highlight/note/bookmark save.
  Future<void> upsertAnnotation(AnnotationRow annotation) async {
    try {
      final existing = await getAnnotation(annotation.id);
      if (existing == null) {
        await into(annotations).insert(annotation);
      } else {
        await (update(annotations)..where((a) => a.id.equals(annotation.id)))
            .write(annotation.toCompanion(false));
      }
      debugPrint(
        '[DB] upsertAnnotation ok id=${annotation.id} '
        'type=${annotation.type} book=${annotation.bookId} '
        'insert=${existing == null} para=${annotation.paraId} '
        'line=${annotation.lineId} seg=${annotation.segment}',
      );
    } catch (e, st) {
      debugPrint('[DB] upsertAnnotation FAILED id=${annotation.id}: $e\n$st');
      rethrow;
    }
  }

  /// Get a single annotation by id.
  Future<AnnotationRow?> getAnnotation(String id) async {
    final rows = await (select(annotations)
          ..where((a) => a.id.equals(id)))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// All annotations for a book (including soft-deleted, so sync can
  /// reconcile tombstones), newest first.
  Future<List<AnnotationRow>> getAnnotationsForBook(String bookId) async {
    return (select(annotations)
          ..where((a) => a.bookId.equals(bookId))
          ..orderBy([
            (a) => OrderingTerm(expression: a.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// All non-deleted annotations for a book, newest first (UI queries).
  Future<List<AnnotationRow>> getVisibleAnnotationsForBook(String bookId) async {
    return (select(annotations)
          ..where((a) => a.bookId.equals(bookId) & a.deletedAt.isNull())
          ..orderBy([
            (a) => OrderingTerm(expression: a.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// Watch (live) all visible annotations for a book.
  Stream<List<AnnotationRow>> watchVisibleAnnotationsForBook(String bookId) {
    return (select(annotations)
          ..where((a) => a.bookId.equals(bookId) & a.deletedAt.isNull())
          ..orderBy([
            (a) => OrderingTerm(expression: a.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// All annotations across every book (used by sync and backup export).
  Future<List<AnnotationRow>> getAllAnnotations() async {
    return (select(annotations)..orderBy([
          (a) => OrderingTerm(expression: a.createdAt, mode: OrderingMode.desc),
        ]))
        .get();
  }

  /// Watch (live) all visible (non-deleted) annotations across every book,
  /// most recently updated first — used by the global annotations screen.
  Stream<List<AnnotationRow>> watchAllVisibleAnnotations() {
    return (select(annotations)
          ..where((a) => a.deletedAt.isNull())
          ..orderBy([
            (a) =>
                OrderingTerm(expression: a.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Rows with local changes that still need pushing to Supabase.
  Future<List<AnnotationRow>> getDirtyAnnotations() async {
    return (select(annotations)..where((a) => a.dirty.equals(true))).get();
  }

  /// Mark a row as clean after a successful server upsert and record the
  /// server's `updated_at` for LWW conflict resolution.
  Future<void> markAnnotationSynced(
    String id, {
    DateTime? serverUpdatedAt,
  }) async {
    await (update(annotations)..where((a) => a.id.equals(id))).write(
      AnnotationsCompanion(
        dirty: const Value(false),
        serverUpdatedAt: Value(serverUpdatedAt),
      ),
    );
  }

  /// Soft-delete an annotation: tombstone stays local (and later remote)
  /// so deletes propagate to other devices without resurrection races.
  Future<void> softDeleteAnnotation(String id) async {
    await (update(annotations)..where((a) => a.id.equals(id))).write(
      AnnotationsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  /// Permanently remove soft-deleted tombstones older than [before]. Called
  /// after a successful sync so the local DB doesn't accumulate them.
  Future<void> purgeAnnotationTombstones(DateTime before) async {
    await (delete(annotations)
          ..where((a) => a.deletedAt.isNotNull() & a.deletedAt.isSmallerThanValue(before)))
        .go();
  }

  /// Hard-delete a row locally. Used when the server reports a DELETE (the
  /// row no longer exists remotely, so there is nothing to tombstone).
  Future<void> hardDeleteAnnotation(String id) async {
    await (delete(annotations)..where((a) => a.id.equals(id))).go();
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
    final existing =
        await (select(readingHistory)
              ..where((h) => h.bookId.equals(bookId))
              ..orderBy([
                (h) => OrderingTerm(
                  expression: h.updatedAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .get();

    if (existing.isNotEmpty) {
      final entry = existing.first;
      // Update the existing entry with new location and timestamp
      await (update(readingHistory)..where((h) => h.id.equals(entry.id))).write(
        ReadingHistoryCompanion(
          bookName: Value(bookName ?? entry.bookName),
          paraId: Value(paraId ?? entry.paraId),
          lineId: Value(lineId ?? entry.lineId),
          updatedAt: Value(now),
          readCount: Value(entry.readCount + 1),
        ),
      );
    } else {
      await into(readingHistory).insert(
        ReadingHistoryCompanion(
          bookId: Value(bookId),
          bookName: Value(bookName),
          paraId: Value(paraId),
          lineId: Value(lineId),
          openedAt: Value(now),
          updatedAt: Value(now),
          readCount: const Value(1),
        ),
      );
    }
  }

  /// Get all reading history, ordered by most recently updated first.
  Future<List<ReadingHistoryData>> getAllHistory() async {
    return (select(readingHistory)..orderBy([
          (h) => OrderingTerm(expression: h.updatedAt, mode: OrderingMode.desc),
        ]))
        .get();
  }

  /// Delete a reading history entry by ID.
  Future<void> deleteHistoryEntry(int id) async {
    await (delete(readingHistory)..where((h) => h.id.equals(id))).go();
  }

  // ── Listening History (books played with TTS) ──────────────────────────

  /// Ensure the `listening_history` table exists.
  ///
  /// Created lazily on first use (same pattern as the chat_* tables) so
  /// existing installs get the table without a schema migration.
  Future<void> _ensureListeningHistoryTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS listening_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id TEXT NOT NULL,
        book_name TEXT,
        para_id INTEGER,
        line_id INTEGER,
        opened_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        listen_count INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  /// Add or update a listening-history entry for [bookId] (TTS playback).
  Future<void> recordListening({
    required String bookId,
    String? bookName,
    int? paraId,
    int? lineId,
  }) async {
    await _ensureListeningHistoryTable();
    final now = DateTime.now().toIso8601String();
    final existing = await customSelect(
      'SELECT id, book_name, para_id, line_id, listen_count '
      'FROM listening_history WHERE book_id = ? '
      'ORDER BY updated_at DESC LIMIT 1',
      variables: [Variable.withString(bookId)],
    ).get();

    if (existing.isNotEmpty) {
      final row = existing.first.data;
      await customStatement(
        'UPDATE listening_history SET book_name = ?, para_id = ?, '
        'line_id = ?, updated_at = ?, listen_count = ? WHERE id = ?',
        [
          bookName ?? row['book_name'],
          paraId ?? row['para_id'],
          lineId ?? row['line_id'],
          now,
          (row['listen_count'] as int) + 1,
          row['id'],
        ],
      );
    } else {
      await customStatement(
        'INSERT INTO listening_history '
        '(book_id, book_name, para_id, line_id, opened_at, updated_at, listen_count) '
        'VALUES (?, ?, ?, ?, ?, ?, 1)',
        [bookId, bookName, paraId, lineId, now, now],
      );
    }
  }

  /// Get all listening history, ordered by most recently updated first.
  Future<List<ListeningHistoryData>> getAllListeningHistory() async {
    await _ensureListeningHistoryTable();
    final rows = await customSelect(
      'SELECT * FROM listening_history ORDER BY updated_at DESC',
    ).get();
    return rows.map((r) => ListeningHistoryData.fromRow(r.data)).toList();
  }

  /// Delete a listening-history entry by ID.
  Future<void> deleteListeningHistoryEntry(int id) async {
    await _ensureListeningHistoryTable();
    await customStatement(
      'DELETE FROM listening_history WHERE id = ?',
      [id],
    );
  }

  // ── TTS Replacements ────────────────────────────────────────────────────

  /// Get all TTS replacement rules, ordered by creation date.
  Future<List<TtsReplacement>> getAllTtsReplacements() async {
    return (select(ttsReplacements)..orderBy([
          (r) => OrderingTerm(expression: r.createdAt, mode: OrderingMode.desc),
        ]))
        .get();
  }

  /// Add a new TTS replacement rule.
  Future<int> addTtsReplacement({
    required String pattern,
    required String replacement,
    bool isRegex = false,
    bool enabled = true,
  }) async {
    return into(ttsReplacements).insert(
      TtsReplacementsCompanion(
        pattern: Value(pattern),
        replacement: Value(replacement),
        isRegex: Value(isRegex),
        enabled: Value(enabled),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update an existing TTS replacement rule.
  Future<void> updateTtsReplacement(
    int id, {
    required String pattern,
    required String replacement,
    required bool isRegex,
    required bool enabled,
  }) async {
    await (update(ttsReplacements)..where((r) => r.id.equals(id))).write(
      TtsReplacementsCompanion(
        pattern: Value(pattern),
        replacement: Value(replacement),
        isRegex: Value(isRegex),
        enabled: Value(enabled),
      ),
    );
  }

  /// Toggle a TTS replacement rule's enabled state.
  Future<void> toggleTtsReplacement(int id, bool enabled) async {
    await (update(ttsReplacements)..where((r) => r.id.equals(id))).write(
      TtsReplacementsCompanion(enabled: Value(enabled)),
    );
  }

  /// Delete a TTS replacement rule by ID.
  Future<void> deleteTtsReplacement(int id) async {
    await (delete(ttsReplacements)..where((r) => r.id.equals(id))).go();
  }

  /// Apply all enabled TTS replacement rules to [text]. Returns the
  /// transformed text.
  Future<String> applyTtsReplacements(String text) async {
    final rules = await (select(
      ttsReplacements,
    )..where((r) => r.enabled.equals(true))).get();
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
      // First, list ALL tables in the database for debugging
      final allTables = await customSelect(
        "SELECT name, type FROM sqlite_master WHERE type IN ('table', 'view', 'virtual') ORDER BY name",
      ).get();
      debugPrint('[INDEX_CHECK] Tables in app_data.db:');
      for (final t in allTables) {
        debugPrint('  - ${t.data['type']}: ${t.data['name']}');
      }

      // Check for search_fts FTS5 virtual table
      // Note: FTS5 virtual tables appear with type='table' in sqlite_master
      final ftsRows = await customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='search_fts'",
      ).get();
      if (ftsRows.isEmpty) {
        debugPrint('[INDEX_CHECK] search_fts table NOT FOUND');
        // Try without type filter as a fallback (some SQLite versions may differ)
        final fallback = await customSelect(
          "SELECT name, type FROM sqlite_master WHERE name='search_fts'",
        ).get();
        if (fallback.isNotEmpty) {
          debugPrint(
            '[INDEX_CHECK] search_fts found with type=${fallback.first.data['type']}',
          );
        }
        return false;
      }
      debugPrint('[INDEX_CHECK] search_fts FOUND');

      // Also check that search_words exists
      final wordRows = await customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='search_words'",
      ).get();
      if (wordRows.isEmpty) {
        debugPrint('[INDEX_CHECK] search_words table NOT FOUND');
        return false;
      }
      debugPrint('[INDEX_CHECK] search_words FOUND');

      // The tables existing isn't enough: the FTS5 tokenizer options are
      // baked into each virtual table at CREATE time and can't be changed
      // in place, so an index built by an older app version (e.g. with
      // remove_diacritics 0) must be rebuilt. The build stamps the schema
      // version that produced it into `index_meta`; a missing or older
      // stamp means this index was built by different code than what's
      // running now, so report it as "not built" to trigger the rebuild.
      final version = await _storedIndexSchemaVersion('search_index_version');
      if (version == null || version < kSearchIndexSchemaVersion) {
        debugPrint(
          '[INDEX_CHECK] Pāli index schema stamp missing/old '
          '(v$version) → needs rebuild',
        );
        return false;
      }
      debugPrint(
        '[INDEX_CHECK] Pāli index schema v$version is current → ready',
      );
      debugPrint('[INDEX_CHECK] Index is BUILT and ready');
      return true;
    } catch (e) {
      debugPrint('[INDEX_CHECK] SQL error in isSearchIndexBuilt: $e');
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
    final pageRows = await epitakaDb
        .customSelect(
          "SELECT book_id, para_id, group_concat(pali, ' ') as pali_text "
          'FROM sentences '
          'WHERE para_id IS NOT NULL '
          'GROUP BY book_id, para_id '
          'ORDER BY book_id, para_id',
        )
        .get();

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
        "  tokenize='unicode61 remove_diacritics 1'"
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
      await customStatement(
        'CREATE INDEX idx_search_words_pali ON search_words(pali)',
      );
      await customStatement(
        'CREATE INDEX idx_search_words_fuzzy ON search_words(fuzzy)',
      );

      // NOTE: deliberately NO FTS5 `prefix` option here. Every search term
      // is matched as a prefix (`term*`), and FTS5 already resolves prefix
      // queries with B-tree range scans (~0.1–2ms on the full corpus); the
      // earlier `prefix="3 4"` idea was also broken SQL (`prefix` inside
      // the tokenize string is a parse error). Prefix indexes only shave
      // very short (2–3 char) prefixes further while making the build
      // ~30–50% slower — and build time is the part users feel.
      //
      // Inserts are batched into multi-row statements: every
      // customStatement call round-trips through Drift's async executor,
      // so a row-by-row insert paid that overhead once per paragraph
      // (~hundreds of thousands of times in a full build). Chunking cuts
      // it down to a handful of round-trips.
      const yieldInterval = 200;
      const insertChunk = 200; // rows per multi-row INSERT (200×3 = 600 params)
      int yieldCounter = 0;
      final ftsBuffer = <Object?>[]; // flat book_id, para_id, pali_text tuples

      for (final row in pageRows) {
        final bookId = row.data['book_id'] as String;
        final paraId = row.data['para_id'] as int;
        var paliText = row.data['pali_text'] as String;

        // Lowercase BEFORE cleaning/indexing so "Citta" and "citta" become
        // the same FTS token and the same search_words entry. Without
        // this, suggestions treated them as two unrelated words.
        paliText = _cleanPaliText(paliText.toLowerCase());
        if (paliText.isEmpty) continue;

        ftsBuffer
          ..add(bookId)
          ..add(paraId)
          ..add(paliText);
        insertedPages++;
        yieldCounter++;

        for (final w in paliText.split(RegExp(r'\s+'))) {
          if (w.isNotEmpty) {
            wordCounts[w] = (wordCounts[w] ?? 0) + 1;
          }
        }

        if (insertedPages % 50 == 0 || insertedPages == totalPages) {
          final p = 0.02 + (insertedPages / totalPages) * 0.50;
          onProgress?.call(
            p.clamp(0.02, 0.52),
            'Indexing Pāli texts… $insertedPages / $totalPages pages',
          );
        }

        if (ftsBuffer.length >= insertChunk * 3) {
          await _flushBatchInsert(
            'search_fts',
            'book_id, para_id, pali_text',
            ftsBuffer,
            3,
          );
        }

        // Yielding inside a transaction still keeps the UI responsive
        // (this is cooperative multitasking on the same isolate) without
        // giving up the atomicity of the transaction itself.
        if (yieldCounter >= yieldInterval) {
          await Future.delayed(Duration.zero);
          yieldCounter = 0;
        }
      }
      await _flushBatchInsert(
        'search_fts',
        'book_id, para_id, pali_text',
        ftsBuffer,
        3,
      );

      final wordTotal = wordCounts.length;
      final wordBuffer = <Object?>[]; // flat pali, fuzzy, count tuples
      for (final entry in wordCounts.entries) {
        wordBuffer
          ..add(entry.key)
          ..add(_normalizeFuzzy(entry.key))
          ..add(entry.value);
        wordCount++;

        if (wordBuffer.length >= insertChunk * 3) {
          await _flushBatchInsert(
            'search_words',
            'pali, fuzzy, count',
            wordBuffer,
            3,
          );
        }

        if (wordCount % 200 == 0 || wordCount == wordTotal) {
          final p = 0.55 + (wordCount / wordTotal) * 0.45;
          onProgress?.call(
            p.clamp(0.55, 1.0),
            'Building word index… $wordCount / $wordTotal words',
          );
        }
        if (wordCount % 200 == 0) {
          await Future.delayed(Duration.zero);
        }
      }
      await _flushBatchInsert(
        'search_words',
        'pali, fuzzy, count',
        wordBuffer,
        3,
      );

      // Stamp the index-schema version that built this table. Runs inside
      // the same transaction as the data, so a build killed mid-way rolls
      // both back and the table can never look "current" while half-built.
      await customStatement(
        'CREATE TABLE IF NOT EXISTS index_meta ('
        '  key TEXT PRIMARY KEY,'
        '  value TEXT NOT NULL'
        ')',
      );
      await customStatement(
        'INSERT OR REPLACE INTO index_meta(key, value) '
        "VALUES ('search_index_version', ?)",
        [kSearchIndexSchemaVersion.toString()],
      );
    });

    stopwatch.stop();
    debugPrint(
      '[INDEX] Pāli index built: $insertedPages pages, $wordCount words in ${stopwatch.elapsed.inSeconds}s',
    );
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
    final sentenceRows = await translationDb
        .customSelect(
          "SELECT book_id, para_id, group_concat(translation, ' ') as translation_text "
          'FROM sentences '
          "WHERE translation IS NOT NULL AND translation != '' "
          'GROUP BY book_id, para_id '
          'ORDER BY book_id, para_id',
        )
        .get();

    debugPrint(
      '[INDEX] Found ${sentenceRows.length} $langCode paragraphs to index',
    );
    if (sentenceRows.isEmpty) return 0;

    final totalRows = sentenceRows.length;
    onProgress?.call(
      0.0,
      'Indexing $totalRows ${langCode.toUpperCase()} translation paragraphs…',
    );

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
        "  tokenize='unicode61 remove_diacritics 1'"
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

      // Same multi-row INSERT batching as the Pāli index: each
      // customStatement round-trips through Drift's async executor, so
      // batching hundreds of rows per statement cuts the build time a lot.
      const yieldInterval = 200;
      const insertChunk = 200;
      int yieldCounter = 0;
      final ftsBuffer = <Object?>[]; // flat book_id, para_id, translation tuples

      for (final row in sentenceRows) {
        final bookId = row.data['book_id'] as String;
        final paraId = row.data['para_id'] as int;
        var translationText = row.data['translation_text'] as String;

        // Lowercase up front (same fix as the Pāli index) so "Citta" and
        // "citta" collapse into one suggestion entry.
        translationText = translationText
            .toLowerCase()
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll(
              RegExp(
                r'[\[\](){}⟨⟩:;.,!?…—–\-"«»“”'
                "'"
                r']',
              ),
              '',
            )
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (translationText.isEmpty) continue;

        ftsBuffer
          ..add(bookId)
          ..add(paraId)
          ..add(translationText);
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
          onProgress?.call(
            p,
            'Indexing ${langCode.toUpperCase()} translation… $count / $totalRows paragraphs',
          );
        }

        if (ftsBuffer.length >= insertChunk * 3) {
          await _flushBatchInsert(
            tableName,
            'book_id, para_id, translation_text',
            ftsBuffer,
            3,
          );
        }
        if (yieldCounter >= yieldInterval) {
          await Future.delayed(Duration.zero);
          yieldCounter = 0;
        }
      }
      await _flushBatchInsert(
        tableName,
        'book_id, para_id, translation_text',
        ftsBuffer,
        3,
      );

      final wordBuffer = <Object?>[]; // flat word, count tuples
      for (final entry in wordCounts.entries) {
        wordBuffer
          ..add(entry.key)
          ..add(entry.value);
        if (wordBuffer.length >= insertChunk * 2) {
          await _flushBatchInsert(
            'search_words_$langCode',
            'word, count',
            wordBuffer,
            2,
          );
        }
      }
      await _flushBatchInsert(
        'search_words_$langCode',
        'word, count',
        wordBuffer,
        2,
      );

      // Same schema-version stamp as the Pāli index, per-language key.
      await customStatement(
        'CREATE TABLE IF NOT EXISTS index_meta ('
        '  key TEXT PRIMARY KEY,'
        '  value TEXT NOT NULL'
        ')',
      );
      await customStatement(
        'INSERT OR REPLACE INTO index_meta(key, value) '
        "VALUES ('search_index_version_$langCode', ?)",
        [kSearchIndexSchemaVersion.toString()],
      );
    });

    stopwatch.stop();
    debugPrint(
      '[INDEX] $langCode translation index built: $count paragraphs, '
      '${wordCounts.length} words in ${stopwatch.elapsed.inSeconds}s',
    );
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
      if (rows.isEmpty) return false;

      // Same tokenizer-version check as the Pāli index: an index built by
      // a pre-versioning app build must be rebuilt so the new tokenizer
      // takes effect.
      final version = await _storedIndexSchemaVersion(
        'search_index_version_$langCode',
      );
      if (version == null || version < kSearchIndexSchemaVersion) {
        debugPrint(
          '[INDEX_CHECK] $langCode index schema stamp missing/old '
          '(v$version) → needs rebuild',
        );
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Search a translation FTS index for [query].
  /// Returns matching sentences with translation snippets.
  Future<List<SearchResultRow>> searchTranslationFts(
    String langCode,
    String query, {
    int distance = 0,
  }) async {
    final tableName = 'search_fts_$langCode';

    // Check if the table exists first
    final exists = await isTranslationIndexBuilt(langCode);
    if (!exists) return [];

    final ftsQuery = _buildFtsQuery(query, distance: distance);
    if (ftsQuery.isEmpty) return [];

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
          .map(
            (r) => SearchResultRow(
              bookId: r.data['book_id'] as String,
              vripage: '',
              snippet: r.data['snippet_text'] as String? ?? '',
              firstParaId: r.data['para_id'] as int?,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Build an FTS5 query string from the user's raw [query].
  ///
  /// Search is always diacritic-insensitive: the FTS5 index is built with
  /// `unicode61 remove_diacritics 1`, so the tokenizer already normalizes
  /// diacritics on both the indexed text and the query — there is no need
  /// (and no longer any code) for the slow per-word search_words expansion
  /// that used to look up every diacritic variant and OR them together.
  ///
  /// The query is cleaned with the same [cleanPaliForIndexing] pipeline
  /// used when indexing, so a sentence pasted from a book (commas, quotes,
  /// dashes, brackets, HTML tags …) becomes exactly the same words that
  /// were indexed. Without this, punctuation such as `,` or `'` inside a
  /// MATCH query is an FTS5 syntax error and the search silently returns
  /// zero results.
  ///
  /// Words are matched as prefixes (`term*`). With [distance] > 0 and more
  /// than one word, FTS5's NEAR() function (not the FTS3/4 infix syntax)
  /// requires the words within [distance] tokens of each other.
  String _buildFtsQuery(String query, {int distance = 0}) {
    final normalized = cleanPaliForIndexing(query.trim().toLowerCase());
    if (normalized.isEmpty) return '';

    final words = normalized
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        // Strip FTS5 operator characters (* ^ ~) that would otherwise
        // produce a syntax error once the prefix `*` is appended.
        .map(
          (w) => _escapeFtsTerm(w)
              .replaceAll('*', '')
              .replaceAll('^', '')
              .replaceAll('~', ''),
        )
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';

    final terms = words.map((w) => '$w*').toList();
    if (distance > 0 && terms.length > 1) {
      return 'NEAR(${terms.join(' ')}, $distance)';
    }
    return terms.join(' AND ');
  }

  /// Count search results grouped by book_id from the Pali FTS index.
  /// Returns a map of book_id -> count.
  Future<Map<String, int>> countPaliResultsByBook(
    String query, {
    int distance = 0,
  }) async {
    final ftsQuery = _buildFtsQuery(query, distance: distance);
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

      return {
        for (final r in rows)
          r.data['book_id'] as String: (r.data['cnt'] as num).toInt(),
      };
    } catch (_) {
      return {};
    }
  }

  /// Count search results grouped by book_id from a translation FTS index.
  Future<Map<String, int>> countTranslationResultsByBook(
    String langCode,
    String query, {
    int distance = 0,
  }) async {
    final tableName = 'search_fts_$langCode';
    final exists = await isTranslationIndexBuilt(langCode);
    if (!exists) return {};

    final ftsQuery = _buildFtsQuery(query, distance: distance);
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
      return {
        for (final r in rows)
          r.data['book_id'] as String: (r.data['cnt'] as num).toInt(),
      };
    } catch (_) {
      return {};
    }
  }

  /// Fetch paginated Pali FTS results for a specific [bookId].
  /// Returns the matching para_ids with highlighted snippets and full text.
  Future<List<SearchResultRow>> searchPaliFtsByBook(
    String bookId,
    String query, {
    int distance = 0,
    int limit = 30,
    int offset = 0,
  }) async {
    final ftsQuery = _buildFtsQuery(query, distance: distance);
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
          .map(
            (r) => SearchResultRow(
              bookId: r.data['book_id'] as String,
              vripage: '',
              firstParaId: r.data['para_id'] as int?,
              snippet: r.data['snippet_text'] as String? ?? '',
              paliText: r.data['pali_text'] as String? ?? '',
            ),
          )
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
    int distance = 0,
    int limit = 30,
    int offset = 0,
  }) async {
    final tableName = 'search_fts_$langCode';
    final exists = await isTranslationIndexBuilt(langCode);
    if (!exists) return [];

    final ftsQuery = _buildFtsQuery(query, distance: distance);
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
          .map(
            (r) => SearchResultRow(
              bookId: r.data['book_id'] as String,
              vripage: '',
              firstParaId: r.data['para_id'] as int?,
              snippet: r.data['snippet_text'] as String? ?? '',
              translation: r.data['translation_text'] as String? ?? '',
            ),
          )
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
    int distance = 0,
  }) async {
    final ftsQuery = _buildFtsQuery(query, distance: distance);
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
          .map(
            (r) => SearchResultRow(
              bookId: r.data['book_id'] as String,
              vripage: '',
              firstParaId: r.data['para_id'] as int?,
              snippet: r.data['snippet_text'] as String? ?? '',
              paliText: r.data['pali_text'] as String? ?? '',
            ),
          )
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
        .map(
          (r) => SearchSuggestion(
            pali: r.data['pali'] as String,
            fuzzy: r.data['fuzzy'] as String,
            count: r.data['count'] as int,
            source: SuggestionSource.pali,
          ),
        )
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
          suggestions.addAll(
            tRows.map(
              (r) => SearchSuggestion(
                pali: r.data['word'] as String,
                fuzzy: r.data['word'] as String,
                count: r.data['count'] as int,
                source: SuggestionSource.translation,
              ),
            ),
          );
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

  /// Flush buffered row-tuples into [table] as ONE multi-row INSERT,
  /// cutting the per-row async round-trip through Drift's executor during
  /// index builds. [buffer] holds flat `[c1, c2, …, cN, c1, c2, …]` values;
  /// [arity] is the number of columns (N). The buffer is cleared on return.
  /// Read the index-schema version stamp for [key] from the `index_meta`
  /// table. Returns null when the table or the row doesn't exist — which
  /// is exactly how indexes built by pre-versioning app builds are
  /// detected (they have no stamp at all).
  Future<int?> _storedIndexSchemaVersion(String key) async {
    try {
      final rows = await customSelect(
        'SELECT value FROM index_meta WHERE key = ?',
        variables: [Variable.withString(key)],
      ).get();
      if (rows.isEmpty) return null;
      return int.tryParse(rows.first.data['value'] as String);
    } catch (_) {
      return null;
    }
  }

  Future<void> _flushBatchInsert(
    String table,
    String columns,
    List<Object?> buffer,
    int arity,
  ) async {
    if (buffer.isEmpty) return;
    final groups = buffer.length ~/ arity;
    final group = '(${List.filled(arity, '?').join(', ')})';
    final placeholders = List.filled(groups, group).join(', ');
    await customStatement(
      'INSERT INTO $table($columns) VALUES $placeholders',
      List<Object?>.of(buffer),
    );
    buffer.clear();
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

// ── Listening history row model ─────────────────────────────────────────

/// A single listening-history entry (a book played with TTS).
class ListeningHistoryData {
  final int id;
  final String bookId;
  final String? bookName;
  final int? paraId;
  final int? lineId;
  final DateTime openedAt;
  final DateTime updatedAt;
  final int listenCount;

  const ListeningHistoryData({
    required this.id,
    required this.bookId,
    this.bookName,
    this.paraId,
    this.lineId,
    required this.openedAt,
    required this.updatedAt,
    required this.listenCount,
  });

  /// Build from a raw `listening_history` row.
  factory ListeningHistoryData.fromRow(Map<String, Object?> data) {
    return ListeningHistoryData(
      id: data['id'] as int,
      bookId: data['book_id'] as String,
      bookName: data['book_name'] as String?,
      paraId: data['para_id'] as int?,
      lineId: data['line_id'] as int?,
      openedAt: DateTime.parse(data['opened_at'] as String),
      updatedAt: DateTime.parse(data['updated_at'] as String),
      listenCount: data['listen_count'] as int,
    );
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
