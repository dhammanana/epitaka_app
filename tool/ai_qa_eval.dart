// Tier-1 offline evaluation harness for the Vimaṃsa (AI Q&A) retrieval
// pipeline (roadmap §7.2, tier 1).
//
// Run from the project root:
//   dart run tool/ai_qa_eval.dart [--db-dir <path>] [--questions <path>]
//
// What it does:
//   1. Loads test/ai_qa/golden_questions.json.
//   2. For each question, runs a SCRIPTED PLANNER that mirrors the tool
//      model's instructed retrieval strategy against the real local DBs:
//      search_sections → search_tipitaka → per-sense search_by_category.
//      (The live Gemini tool loop is a Tier-2 / manual step; this harness
//      measures the retrieval backbone deterministically and offline.)
//   3. Computes metrics per question: book recall, paragraph recall,
//      precision (fraction of retrieved passages in expected books),
//      tool efficiency (# retrieval steps), and records search_method
//      (bm25 vs like) per hit.
//   4. Prints a PASS/FAIL table + summary, and writes
//      test/ai_qa/eval_report.json next to the questions file.
//
// IMPORTANT: this script mirrors the SQL of AiQaToolService /
// SectionIndexService but cannot import them (they depend on Flutter).
// Keep the query text in sync when those services change.
//
// NOTE: BM25 requires the Gavesana-built `vec_chunks_fts` index inside
// epitaka.db; when absent (as on a fresh install) every search silently
// uses the LIKE fallback, which is recorded per hit.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

// ── Paths ───────────────────────────────────────────────────────────────

String _resolveDbDir(String? override) {
  final candidates = <String>[];
  if (override != null && override.isNotEmpty) candidates.add(override);
  final env = Platform.environment['EPITAKA_DB_PATH'];
  if (env != null && env.isNotEmpty) candidates.add(env);
  candidates.add(p.join(Directory.current.path, 'data'));
  candidates.add(
    p.join(
      Platform.environment['HOME'] ?? '',
      'Library/Containers/com.dn.epitaka/Data/Documents',
    ),
  );
  candidates.add(
    p.join(
      Platform.environment['HOME'] ?? '',
      'Library/Containers/com.epitaka.epitakaApp/Data/Documents',
    ),
  );
  for (final c in candidates) {
    final d = Directory(c);
    if (d.existsSync() && File(p.join(c, 'epitaka.db')).existsSync()) {
      return c;
    }
  }
  stderr.writeln('Could not locate epitaka.db. Pass --db-dir or set '
      'EPITAKA_DB_PATH.');
  exit(2);
}

// ── Small JSON helpers ──────────────────────────────────────────────────

String _j(Object? v) => const JsonEncoder().convert(v);

// ── Retrieval core (mirrors AiQaToolService) ───────────────────────────

class EvalRetriever {
  final Database epiDb;
  final Database? enDb;
  final Database appDb;
  final Database? dpdDb;

  /// Cache of books table for name/category lookups.
  final Map<String, Map<String, Object?>> _books = {};

  /// Whether BM25 (vec_chunks_fts) is available in epitaka.db.
  bool? _bm25Available;

  EvalRetriever({
    required this.epiDb,
    required this.enDb,
    required this.appDb,
    required this.dpdDb,
  });

  Map<String, Object?> _bookInfo(String bookId) {
    final cached = _books[bookId];
    if (cached != null) return cached;
    final rows = epiDb.select(
      'SELECT book_id, book_name, category, nikaya FROM books WHERE book_id = ?',
      [bookId],
    );
    final info = rows.isEmpty
        ? <String, Object?>{'book_id': bookId, 'book_name': bookId}
        : Map<String, Object?>.from(rows.first);
    _books[bookId] = info;
    return info;
  }

  bool get bm25Available {
    if (_bm25Available != null) return _bm25Available!;
    final rows = epiDb.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='vec_chunks_fts'",
    );
    _bm25Available = rows.isNotEmpty;
    return _bm25Available!;
  }

  List<String> _ftsTerms(String query) {
    return query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && w.length >= 2)
        .map((w) => '"${w.replaceAll('"', '""')}"*')
        .toList();
  }

  /// search_tipitaka — BM25 then LIKE fallback (mirrors _searchBm25 /
  /// _searchLike in ai_qa_tool_service.dart).
  List<Map<String, Object?>> searchTipitaka(String query, {int limit = 50}) {
    final hits = <Map<String, Object?>>[];
    var method = 'like';

    if (bm25Available) {
      final terms = _ftsTerms(query).join(' ');
      try {
        final rows = epiDb.select(
          'SELECT vc.book_id, vc.start_para, vc.end_para '
          'FROM vec_chunks_fts JOIN vec_chunks vc '
          'ON vc.chunk_id = vec_chunks_fts.chunk_id '
          'WHERE vec_chunks_fts MATCH ? '
          'ORDER BY bm25(vec_chunks_fts) ASC LIMIT 50',
          [terms],
        );
        if (rows.isNotEmpty) {
          method = 'bm25';
          for (final row in rows) {
            final bookId = row['book_id'] as String;
            final startPara = row['start_para'] as int;
            final endPara = row['end_para'] as int;
            final text = _firstLine(bookId, startPara, endPara);
            hits.add({
              'book_id': bookId,
              'para_id': startPara,
              'line_id': 1,
              'text': text,
              'method': 'bm25',
            });
          }
        }
      } catch (_) {
        method = 'like';
      }
    }

    if (hits.isEmpty) {
      method = 'like';
      final keywords = query
          .split(RegExp(r'\s+'))
          .map((w) => w.trim())
          .where((w) => w.length >= 3)
          .toSet()
          .toList();
      if (keywords.isNotEmpty) {
        // Same fix as AiQaToolService._searchLike: pool a generous number
        // of candidates (book-ordered so no book is starved) then rank by
        // keyword-occurrence density in Dart.
        final conds = keywords.map((_) => 'LOWER(s.pali) LIKE ?').join(' OR ');
        final params = keywords.map((k) => '%${k.toLowerCase()}%').toList();
        final rows = epiDb.select(
          'SELECT s.book_id, s.para_id, s.line_id, s.pali '
          'FROM sentences s JOIN books b ON b.book_id = s.book_id '
          'WHERE $conds '
          'ORDER BY s.book_id, s.para_id, s.line_id LIMIT 1000',
          params,
        );
        final seen = <String>{};
        final scored = <Map<String, Object?>>[];
        for (final row in rows) {
          final bookId = row['book_id'] as String;
          final paraId = row['para_id'] as int;
          if (!seen.add('$bookId:$paraId')) continue;
          final text = row['pali'] as String? ?? '';
          final lower = text.toLowerCase();
          double score = 0;
          for (final kw in keywords) {
            final needle = kw.toLowerCase();
            var idx = 0;
            while (idx != -1) {
              idx = lower.indexOf(needle, idx);
              if (idx != -1) {
                score += needle.length;
                idx += needle.length;
              }
            }
          }
          final relevance =
              lower.isEmpty ? 0.0 : (score / lower.length).clamp(0.0, 1.0);
          scored.add({
            'book_id': bookId,
            'para_id': paraId,
            'line_id': (row['line_id'] as int?) ?? 1,
            'text': text,
            'relevance': relevance,
            'method': 'like',
          });
        }
        scored.sort((a, b) {
          final c = (b['relevance'] as double)
              .compareTo(a['relevance'] as double);
          return c != 0
              ? c
              : (a['para_id'] as int).compareTo(b['para_id'] as int);
        });
        hits.addAll(scored);
      }
    }

    // Deduplicate by (book_id, para_id) and attach heading chains.
    final seenKeys = <String>{};
    final out = <Map<String, Object?>>[];
    for (final h in hits) {
      final key = '${h['book_id']}:${h['para_id']}';
      if (!seenKeys.add(key)) continue;
      final chain = _headingChain(h['book_id'] as String, h['para_id'] as int);
      if (chain.isNotEmpty) h['heading_chain'] = chain;
      h['search_method'] = method;
      out.add(h);
      if (out.length >= limit) break;
    }
    return out;
  }

  String _firstLine(String bookId, int startPara, int endPara) {
    final rows = epiDb.select(
      'SELECT pali FROM sentences '
      'WHERE book_id = ? AND para_id >= ? AND para_id <= ? '
      'ORDER BY para_id ASC, line_id ASC LIMIT 1',
      [bookId, startPara, endPara],
    );
    return rows.isEmpty ? '' : (rows.first['pali'] as String? ?? '');
  }

  List<Object?> _headingChain(String bookId, int paraId) {
    try {
      final rows = epiDb.select(
        'WITH RECURSIVE hc(para_id, title, parent) AS ('
        '  SELECT para_id, title, parent FROM headings '
        '  WHERE book_id = ? AND para_id <= ? '
        '  ORDER BY para_id DESC LIMIT 1 '
        '  UNION ALL '
        '  SELECT h.para_id, h.title, h.parent '
        '  FROM headings h INNER JOIN hc ON h.para_id = hc.parent'
        ') SELECT title FROM hc ORDER BY para_id ASC',
        [bookId, paraId],
      );
      return rows.map((r) => r['title'] as String).toList();
    } catch (_) {
      return [];
    }
  }

  /// search_sections — FTS over section_summaries_fts (Layer 1).
  List<Map<String, Object?>> searchSections(String query, {int limit = 20}) {
    _ensureSectionsIndex();
    final terms = _ftsTerms(query).join(' ');
    if (terms.isEmpty) return [];
    try {
      final rows = appDb.select(
        'SELECT s.book_id, s.para_start, s.para_end, s.title, s.title_en, '
        's.path, s.summary, s.summary_en '
        'FROM section_summaries_fts JOIN section_summaries s '
        'ON s.book_id = section_summaries_fts.book_id '
        'AND s.para_start = section_summaries_fts.para_start '
        'WHERE section_summaries_fts MATCH ? '
        'ORDER BY bm25(section_summaries_fts) ASC LIMIT 20',
        [terms],
      );
      return rows.map((r) {
        final bid = r['book_id'] as String;
        final ps = r['para_start'] as int;
        return {
          'book_id': bid,
          'para_id': ps,
          'para_start': ps,
          'para_end': r['para_end'] as int,
          'title': r['title'] as String? ?? '',
          'title_en': r['title_en'] as String? ?? '',
          'path': r['path'] as String? ?? '',
          'summary': r['summary'] as String? ?? '',
          'book_name': (_bookInfo(bid)['book_name'] as String?) ?? bid,
        };
      }).take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  /// search_by_category — resolve books by category/nikaya prefix, then
  /// run search_tipitaka per query and filter (mirrors the tool service).
  List<Map<String, Object?>> searchByCategory(
    List<String> queries,
    List<String> categories,
    List<String> nikayas,
  ) {
    if (queries.isEmpty) return [];
    final clauses = <String>[];
    final params = <Object?>[];
    if (categories.isNotEmpty) {
      final ph = categories.map((_) => '?').join(',');
      clauses.add('b.category IN ($ph)');
      params.addAll(categories);
    }
    if (nikayas.isNotEmpty) {
      final conds = nikayas.map((n) => 'b.book_id LIKE ?').join(' OR ');
      clauses.add('($conds)');
      params.addAll(nikayas.map((n) => '$n%'));
    }
    final filter = clauses.isNotEmpty ? 'AND ${clauses.join(' AND ')}' : '';
    final valid = <String>{};
    for (final row in epiDb.select(
      'SELECT b.book_id FROM books b WHERE 1=1 $filter',
      params,
    )) {
      valid.add(row['book_id'] as String);
    }
    if (valid.isEmpty) return [];

    final seen = <String>{};
    final out = <Map<String, Object?>>[];
    for (final q in queries) {
      for (final hit in searchTipitaka(q)) {
        final bid = hit['book_id'] as String;
        if (!valid.contains(bid)) continue;
        if (!seen.add('$bid:${hit['para_id']}')) continue;
        out.add(hit);
      }
    }
    return out;
  }

  /// get_dictionary — DPD lookup + pali_definition occurrences.
  Map<String, Object?> getDictionary(String term) {
    final result = <String, Object?>{'term': term, 'lookups': [], 'canon_occurrences': []};
    if (dpdDb != null) {
      try {
        final rows = dpdDb!.select(
          'SELECT lookup_key, headwords FROM dpd_lookup '
          'WHERE lookup_key = ? LIMIT 1',
          [term.toLowerCase()],
        );
        final lookups = <Map<String, Object?>>[];
        for (final row in rows) {
          final hwIds = <int>[];
          try {
            hwIds.addAll((jsonDecode(row['headwords'] as String) as List).cast<int>());
          } catch (_) {}
          if (hwIds.isEmpty) continue;
          final ph = hwIds.map((_) => '?').join(',');
          final hw = dpdDb!.select(
            'SELECT id, lemma_1, meaning_html FROM dpd_headwords '
            'WHERE id IN ($ph) LIMIT 5',
            hwIds,
          );
          lookups.add({
            'lookup_key': row['lookup_key'] as String,
            'headwords': hw.map((h) => {
                  'id': h['id'],
                  'lemma': h['lemma_1'],
                  'meaning': (h['meaning_html'] as String? ?? '').substring(
                    0,
                    ((h['meaning_html'] as String? ?? '')).length > 200
                        ? 200
                        : (h['meaning_html'] as String? ?? '').length,
                  ),
                }).toList(),
          });
        }
        result['lookups'] = lookups;
      } catch (_) {}
    }
    try {
      final rows = epiDb.select(
        'SELECT book_id, para_id, line_id, word FROM pali_definition '
        'WHERE word = ? LIMIT 10',
        [term.toLowerCase()],
      );
      result['canon_occurrences'] =
          rows.map((r) => Map<String, Object?>.from(r)).toList();
    } catch (_) {}
    return result;
  }

  // ── Section index build (mirrors SectionIndexService) ─────────────────

  bool _sectionsEnsured = false;

  void _ensureSectionsIndex() {
    if (_sectionsEnsured) {
      final c = appDb.select('SELECT COUNT(*) AS c FROM section_summaries').first;
      if ((c['c'] as int) > 0) return;
    }
    _sectionsEnsured = true;
    appDb.execute('''
      CREATE TABLE IF NOT EXISTS section_summaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id TEXT NOT NULL,
        para_start INTEGER NOT NULL,
        para_end INTEGER NOT NULL,
        level INTEGER NOT NULL DEFAULT 0,
        parent_para INTEGER NOT NULL DEFAULT 0,
        title TEXT NOT NULL,
        title_en TEXT DEFAULT '',
        path TEXT NOT NULL,
        summary TEXT DEFAULT '',
        summary_en TEXT DEFAULT '',
        word_count INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    appDb.execute('CREATE INDEX IF NOT EXISTS idx_sections_book ON section_summaries(book_id, para_start)');
    appDb.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS section_summaries_fts USING fts5(
        book_id UNINDEXED, para_start UNINDEXED,
        title, title_en, path, summary, summary_en,
        tokenize='unicode61 remove_diacritics 1'
      )
    ''');
    appDb.execute('DROP TABLE IF EXISTS headings_fts');
    final c = appDb.select('SELECT COUNT(*) AS c FROM section_summaries').first;
    if ((c['c'] as int) > 0) return;

    stdout.writeln('  [sections] building section index (first run)…');
    final books = epiDb.select('SELECT book_id, book_name FROM books ORDER BY id');
    var inserted = 0;
    for (final book in books) {
      final bookId = book['book_id'] as String;
      final bookName = (book['book_name'] as String?) ?? bookId;

      final headings = epiDb.select(
        'SELECT para_id, title, level, parent FROM headings '
        'WHERE book_id = ? AND level < 19 AND level != 10 ORDER BY para_id ASC',
        [bookId],
      );
      if (headings.isEmpty) {
        final last = _lastPara(bookId);
        if (last > 0) {
          appDb.execute(
            'INSERT INTO section_summaries '
            '(book_id, para_start, para_end, level, parent_para, title, '
            ' title_en, path, summary, summary_en, word_count, updated_at) '
            'VALUES (?, ?, ?, 0, 0, ?, ?, ?, ?, ?, ?, ?)',
            [
              bookId, 1, last, bookName, '',
              '$bookId/$bookName',
              _bodyText(bookId, 1, last, 'pali'),
              _bodyText(bookId, 1, last, 'translation'),
              last,
              DateTime.now().toIso8601String(),
            ],
          );
          inserted++;
        }
        continue;
      }

      final titles = <int, String>{};
      final levels = <int, int>{};
      final parents = <int, int>{};
      for (final h in headings) {
        final pid = h['para_id'] as int;
        titles[pid] = (h['title'] as String?) ?? '';
        levels[pid] = (h['level'] as int?) ?? 0;
        parents[pid] = (h['parent'] as int?) ?? 0;
      }
      final lastPara = _lastPara(bookId);

      final rows = <List<Object?>>[];
      for (int hi = 0; hi < headings.length; hi++) {
        final pid = headings[hi]['para_id'] as int;
        final title = titles[pid] ?? '';
        if (title.isEmpty) continue;
        final level = levels[pid] ?? 0;
        var end = lastPara;
        for (int j = hi + 1; j < headings.length; j++) {
          final np = headings[j]['para_id'] as int;
          if ((levels[np] ?? 0) <= level) {
            end = np - 1;
            break;
          }
        }
        if (end < pid) end = pid;
        final hierarchy = <String>[title];
        var parent = parents[pid] ?? 0;
        final seen = <int>{pid};
        while (parent > 0 && !seen.contains(parent)) {
          seen.add(parent);
          final pt = titles[parent];
          if (pt != null && pt.isNotEmpty) hierarchy.insert(0, pt);
          parent = parents[parent] ?? 0;
        }
        rows.add([bookId, pid, end, level, parents[pid] ?? 0, title,
            '$bookId/${hierarchy.join('/')}']);
      }

      final enTitles = <int, String>{};
      if (enDb != null && rows.isNotEmpty) {
        final ids = rows.map((r) => r[1] as int).toList();
        final ph = ids.map((_) => '?').join(',');
        for (final row in enDb!.select(
          'SELECT para_id, translation FROM sentences '
          'WHERE book_id = ? AND para_id IN ($ph) '
          'AND translation IS NOT NULL AND translation != \'\' '
          'ORDER BY para_id ASC, line_id ASC',
          [bookId, ...ids],
        )) {
          final pid = row['para_id'] as int;
          final t = (row['translation'] as String? ?? '').trim();
          if (t.isNotEmpty && !enTitles.containsKey(pid)) enTitles[pid] = t;
        }
      }

      appDb.execute('BEGIN');
      try {
        for (final r in rows) {
          final bid = r[0] as String;
          final ps = r[1] as int;
          final pe = r[2] as int;
          final title = r[5] as String;
          final path = r[6] as String;
          final titleEn = enTitles[ps] ?? '';
          final summary = _bodyText(bid, ps, pe, 'pali');
          final summaryEn = enDb == null
              ? ''
              : _bodyText(bid, ps, pe, 'translation');
          appDb.execute(
            'INSERT INTO section_summaries '
            '(book_id, para_start, para_end, level, parent_para, title, '
            ' title_en, path, summary, summary_en, word_count, updated_at) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              bid, ps, pe, r[3], r[4], title, titleEn, path,
              summary, summaryEn,
              summary.isEmpty ? 0 : summary.split(RegExp(r'\s+')).length,
              DateTime.now().toIso8601String(),
            ],
          );
          appDb.execute(
            'INSERT INTO section_summaries_fts '
            '(book_id, para_start, title, title_en, path, summary, summary_en) '
            'VALUES (?, ?, ?, ?, ?, ?, ?)',
            [bid, ps, title, titleEn, path, summary, summaryEn],
          );
          inserted++;
        }
        appDb.execute('COMMIT');
      } catch (e) {
        appDb.execute('ROLLBACK');
        rethrow;
      }
    }
    stdout.writeln('  [sections] built $inserted sections');
  }

  int _lastPara(String bookId) {
    try {
      final r = epiDb.select(
        'SELECT MAX(para_id) AS m FROM sentences WHERE book_id = ?',
        [bookId],
      );
      return (r.first['m'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  String _bodyText(String bookId, int start, int end, String column) {
    try {
      final rows = epiDb.select(
        'SELECT $column FROM sentences '
        'WHERE book_id = ? AND para_id >= ? AND para_id <= ? '
        'AND $column IS NOT NULL AND $column != \'\' '
        'ORDER BY para_id ASC, line_id ASC',
        [bookId, start, end],
      );
      final buffer = StringBuffer();
      for (final r in rows) {
        buffer.write((r[column] as String? ?? '').trim());
        buffer.write(' ');
        if (buffer.length >= 1200) break;
      }
      var s = buffer.toString().trim();
      if (s.length > 1200) s = s.substring(0, 1200).trim();
      return s;
    } catch (_) {
      return '';
    }
  }
}

// ── Scripted planner ────────────────────────────────────────────────────

class StepRecord {
  final String tool;
  final Map<String, Object?> args;
  final int hits;
  final String method;
  StepRecord(this.tool, this.args, this.hits, this.method);
}

/// (book_id, para_start, para_end) span retrieved by a tool step.
typedef RetrievedSpan = (String, int, int);

class QuestionResult {
  final Map<String, dynamic> q;
  final List<StepRecord> steps;
  final Set<RetrievedSpan> retrievedSpans;

  QuestionResult(this.q, this.steps, this.retrievedSpans);

  int get stepsUsed => steps.length;
  int get totalRetrieved => retrievedSpans.length;

  Set<String> get retrievedBooks =>
      retrievedSpans.map((s) => s.$1).toSet();

  Set<String> get expectedBooks =>
      (q['expects_book_ids'] as List).map((e) => e.toString()).toSet();

  List<Map<String, dynamic>> get expectedParas =>
      (q['expects_para_any'] as List? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();

  /// Expected book ids may be exact ids ('S-iii', 'Dhp') or prefixes
  /// ('S-', 'Vin-', 'Ja-') — matching the design doc's own example
  /// `expects_book_ids: ["vinaya"]`.
  bool _bookMatches(String expected, String actual) =>
      actual == expected || actual.startsWith(expected);

  double get bookRecall {
    final exp = expectedBooks;
    if (exp.isEmpty) return 1.0;
    final hit = exp
        .where((e) => retrievedBooks.any((b) => _bookMatches(e, b)))
        .length;
    return hit / exp.length;
  }

  /// Any expected (book, para) is covered by a retrieved span — a
  /// search_sections hit [start..end] covers it when start ≤ para ≤ end,
  /// a search_tipitaka hit covers it when para matches exactly.
  bool get paraAnyHit {
    if (expectedParas.isEmpty) return true;
    for (final p in expectedParas) {
      final eb = p['book_id'].toString();
      final ep = (p['para_id'] as num).toInt();
      final covered = retrievedSpans.any(
        (s) => _bookMatches(eb, s.$1) && s.$2 <= ep && ep <= s.$3,
      );
      if (covered) return true;
    }
    return false;
  }

  double get precision {
    if (retrievedSpans.isEmpty) return 0.0;
    var relevant = 0;
    for (final s in retrievedSpans) {
      if (expectedBooks.any((e) => _bookMatches(e, s.$1))) relevant++;
    }
    return relevant / retrievedSpans.length;
  }

  bool get pass => bookRecall >= 1.0 && paraAnyHit;
}

List<StepRecord> _runPlanner(EvalRetriever r, Map<String, dynamic> q) {
  const maxSteps = 8;
  final steps = <StepRecord>[];
  final terms = (q['search_terms'] as List? ?? [q['question']])
      .map((e) => e.toString())
      .where((s) => s.trim().isNotEmpty)
      .toList();
  final question = q['question'] as String;

  void record(String tool, Map<String, Object?> args, List hits, String method) {
    if (steps.length >= maxSteps) return;
    steps.add(StepRecord(tool, args, hits.length, method));
  }

  // 1. Map first: search section titles for the question's core terms.
  for (final t in terms.take(1)) {
    if (steps.length >= maxSteps) break;
    final hits = r.searchSections(t);
    record('search_sections', {'query': t}, hits, 'fts');
  }

  // 2. Full-text search on the question's core terms.
  for (final t in terms.take(2)) {
    if (steps.length >= maxSteps) break;
    final hits = r.searchTipitaka(t);
    record('search_tipitaka', {'query': t}, hits, hits.isNotEmpty ? (hits.first['search_method']?.toString() ?? 'like') : 'like');
  }

  // 3. Targeted per-sense / category searches.
  final senses = q['senses'] as List? ?? [];
  if (senses.isNotEmpty) {
    for (final s in senses) {
      if (steps.length >= maxSteps) break;
      final m = s as Map<String, dynamic>;
      final st = ((m['terms'] as List? ?? [m['label']]) as List)
          .map((e) => e.toString())
          .toList();
      final niks = (m['nikayas'] as List? ?? []).map((e) => e.toString()).toList();
      final cats = (m['categories'] as List? ?? []).map((e) => e.toString()).toList();
      if (niks.isNotEmpty || cats.isNotEmpty) {
        final hits = r.searchByCategory(st, cats, niks);
        record('search_by_category', {
          'queries': st,
          'categories': cats,
          'nikayas': niks,
        }, hits, hits.isNotEmpty ? (hits.first['search_method']?.toString() ?? 'like') : 'like');
      } else {
        for (final t in st.take(1)) {
          if (steps.length >= maxSteps) break;
          final hits = r.searchSections(t);
          record('search_sections', {'query': t}, hits, 'fts');
        }
      }
    }
  } else {
    final niks = (q['nikayas'] as List? ?? []).map((e) => e.toString()).toList();
    final cats = (q['categories'] as List? ?? []).map((e) => e.toString()).toList();
    final tags = (q['tags'] as List? ?? []).map((e) => e.toString()).toList();
    if (tags.contains('vinaya') && niks.isEmpty) {
      final hits = r.searchByCategory(terms, const [], ['Vin-']);
      record('search_by_category', {
        'queries': terms,
        'categories': const [],
        'nikayas': const ['Vin-'],
      }, hits, hits.isNotEmpty ? (hits.first['search_method']?.toString() ?? 'like') : 'like');
    } else if (niks.isNotEmpty || cats.isNotEmpty) {
      final hits = r.searchByCategory(terms, cats, niks);
      record('search_by_category', {
        'queries': terms,
        'categories': cats,
        'nikayas': niks,
      }, hits, hits.isNotEmpty ? (hits.first['search_method']?.toString() ?? 'like') : 'like');
    } else if (tags.contains('concept') || tags.contains('polysemous')) {
      for (final t in terms.skip(2).take(2)) {
        if (steps.length >= maxSteps) break;
        final hits = r.searchSections(t);
        record('search_sections', {'query': t}, hits, 'fts');
      }
    }
  }

  // 4. Concept questions: verify the term in the dictionary (Layer 0 tool).
  if ((q['tags'] as List? ?? []).contains('concept') && steps.length < maxSteps) {
    final dict = r.getDictionary(terms.first);
    final lookups = (dict['lookups'] as List? ?? []).length;
    final occs = (dict['canon_occurrences'] as List? ?? []).length;
    steps.add(StepRecord('get_dictionary', {'term': terms.first},
        lookups + occs, 'dpd'));
  }

  return steps.take(maxSteps).toList();
}

// ── Metrics + reporting ─────────────────────────────────────────────────

void main(List<String> args) {
  String? dbDirOverride;
  String? questionsPath;
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--db-dir' && i + 1 < args.length) {
      dbDirOverride = args[i + 1];
      i++;
    } else if (args[i] == '--questions' && i + 1 < args.length) {
      questionsPath = args[i + 1];
      i++;
    } else if (args[i] == '--help') {
      print('Usage: dart run tool/ai_qa_eval.dart [--db-dir <path>] '
          '[--questions <path>]');
      return;
    }
  }

  final dbDir = _resolveDbDir(dbDirOverride);
  stdout.writeln('DB dir: $dbDir');

  final epiDb = sqlite3.open(p.join(dbDir, 'epitaka.db'));
  final enDb = sqlite3.open(p.join(dbDir, 'epitaka_en.db'));
  final appDb = sqlite3.open(p.join(dbDir, 'app_data.db'));
  Database? dpdDb;
  if (File(p.join(dbDir, 'dpd-dictionary.db')).existsSync()) {
    dpdDb = sqlite3.open(p.join(dbDir, 'dpd-dictionary.db'));
  } else {
    stdout.writeln('  (dpd-dictionary.db not found — get_dictionary limited)');
  }

  final retriever = EvalRetriever(
    epiDb: epiDb,
    enDb: enDb,
    appDb: appDb,
    dpdDb: dpdDb,
  );
  stdout.writeln('BM25 (vec_chunks_fts) available: ${retriever.bm25Available}');

  final qPath = questionsPath ??
      p.join(Directory.current.path, 'test', 'ai_qa', 'golden_questions.json');
  if (!File(qPath).existsSync()) {
    stderr.writeln('Golden questions not found at $qPath');
    exit(2);
  }
  final questions =
      (jsonDecode(File(qPath).readAsStringSync()) as List).cast<Map<String, dynamic>>();
  stdout.writeln('Loaded ${questions.length} golden questions\n');

  final results = <QuestionResult>[];
  int passCount = 0;
  int totalSteps = 0;
  double totalBookRecall = 0;
  double totalPrecision = 0;

  for (final q in questions) {
    final steps = _runPlanner(retriever, q);

    final retrievedSpans = <RetrievedSpan>{};

    for (final step in steps) {
      // Re-run each step's retrieval to collect hits (steps already hold
      // hit counts; re-run is cheap on local SQLite).
      List hits = [];
      switch (step.tool) {
        case 'search_sections':
          hits = retriever.searchSections(step.args['query'] as String);
          break;
        case 'search_tipitaka':
          hits = retriever.searchTipitaka(step.args['query'] as String);
          break;
        case 'search_by_category':
          hits = retriever.searchByCategory(
            (step.args['queries'] as List).cast<String>(),
            (step.args['categories'] as List).cast<String>(),
            (step.args['nikayas'] as List).cast<String>(),
          );
          break;
        default:
          hits = [];
      }
      for (final h in hits) {
        final bid = h['book_id'].toString();
        final ps = (h['para_id'] as num?)?.toInt() ?? 0;
        final pe = (h['para_end'] as num?)?.toInt() ?? ps;
        retrievedSpans.add((bid, ps, pe));
      }
    }

    final result = QuestionResult(q, steps, retrievedSpans);
    results.add(result);
    if (result.pass) passCount++;
    totalSteps += result.stepsUsed;
    totalBookRecall += result.bookRecall;
    totalPrecision += result.precision;

    final mark = result.pass ? 'PASS' : 'FAIL';
    final methods = steps
        .map((s) => s.method)
        .toSet()
        .join('/');
    stdout.writeln(
      '$mark  ${q['id']!.toString().padRight(28)} '
      'recall=${result.bookRecall.toStringAsFixed(2)} '
      'para=${result.paraAnyHit ? "✓" : "✗"} '
      'prec=${result.precision.toStringAsFixed(2)} '
      'steps=${result.stepsUsed} [$methods]',
    );
    for (final s in steps) {
      stdout.writeln(
        '      ${s.tool.padRight(20)} ${s.hits.toString().padLeft(3)} hits '
        '${s.args.toString().length > 90 ? s.args.toString().substring(0, 90) + "…" : s.args}',
      );
    }
  }

  final n = questions.length;
  stdout.writeln('\n──────────────────────────────────────────');
  stdout.writeln('TOTAL: $passCount/$n passed');
  stdout.writeln(
      'Avg book recall: ${(totalBookRecall / n).toStringAsFixed(3)}');
  stdout.writeln(
      'Avg precision:  ${(totalPrecision / n).toStringAsFixed(3)}');
  stdout.writeln('Avg tool steps: ${(totalSteps / n).toStringAsFixed(1)}');

  // Write report JSON next to the questions file.
  final report = {
    'db_dir': dbDir,
    'bm25_available': retriever.bm25Available,
    'summary': {
      'total': n,
      'passed': passCount,
      'avg_book_recall': totalBookRecall / n,
      'avg_precision': totalPrecision / n,
      'avg_steps': totalSteps / n,
    },
    'results': results.map((r) => {
          'id': r.q['id'],
          'pass': r.pass,
          'book_recall': r.bookRecall,
          'para_any_hit': r.paraAnyHit,
          'precision': r.precision,
          'steps': r.stepsUsed,
          'retrieved_books': r.retrievedBooks.toList()..sort(),
          'missing_books': r.expectedBooks
              .where((e) =>
                  !r.retrievedBooks.any((b) => b == e || b.startsWith(e)))
              .toList(),
          'tool_trace': r.steps
              .map((s) => {
                    'tool': s.tool,
                    'args': s.args,
                    'hits': s.hits,
                    'method': s.method,
                  })
              .toList(),
        }).toList(),
  };
  final reportPath = p.join(
    p.dirname(qPath),
    'eval_report.json',
  );
  File(reportPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(report),
  );
  stdout.writeln('Report written to $reportPath');

  epiDb.dispose();
  enDb.dispose();
  appDb.dispose();
  dpdDb?.dispose();
}
