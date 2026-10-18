/// Builds the grouped outline of a book.
///
/// Preferred source is the translated `summaries` table in `epitaka_en.db`
/// (offline): each row already carries `vagga_title` → `sutta_title` →
/// English `title`, so level-10 sections show their translated title text
/// instead of the bare Pāli heading number ("1", "2", …).
///
/// Fallback is the local `headings` table in `epitaka.db`, mirroring the web
/// outline page (epitaka.org `_book_outline_items`):
/// - Books normally have numbered (level-10) sections; those are the items.
/// - Books without level-10 sections (grammars, anthologies, saṅgāyana
///   summaries) fall back to their level 2–6 headings so every book gets a
///   non-empty outline.
/// - Items are grouped vagga (level 2) → sutta (level 4) via the parent
///   chain; a level-2/4 heading acts as its own group when no ancestor
///   exists.
library;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../models/outline_models.dart';

final outlineProvider = FutureProvider.family<List<OutlineGroup>, String>((
  ref,
  bookId,
) async {
  final fromSummaries = await _loadFromSummaries(ref, bookId);
  if (fromSummaries != null && fromSummaries.isNotEmpty) {
    debugPrint(
      '[OUTLINE] book=$bookId source=summaries groups=${fromSummaries.length}',
    );
    return fromSummaries;
  }
  debugPrint('[OUTLINE] book=$bookId source=headings (summaries miss)');
  return _loadFromHeadings(ref, bookId);
});

/// Load the outline from `summaries` in `epitaka_en.db` when that table
/// exists and holds rows for [bookId]. Returns null when the English DB is
/// missing, predates the summaries table, or has no rows for this book so
/// the caller falls back to `headings`.
Future<List<OutlineGroup>?> _loadFromSummaries(Ref ref, String bookId) async {
  try {
    final enDb = await ref.watch(translationDbProvider('en').future);
    if (enDb == null) {
      debugPrint(
        '[OUTLINE] book=$bookId summaries miss: epitaka_en.db not open (not downloaded?)',
      );
      return null;
    }

    final table = await enDb
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          'AND name = ?',
          variables: [Variable.withString('summaries')],
        )
        .get();
    if (table.isEmpty) {
      debugPrint(
        '[OUTLINE] book=$bookId summaries miss: no summaries table (stale epitaka_en.db — re-download English)',
      );
      return null;
    }

    final rows = await enDb
        .customSelect(
          'SELECT section_id, para_start, para_end, title, heading_title, '
          'sutta_title, vagga_title FROM summaries WHERE book_id = ? '
          'ORDER BY section_id ASC',
          variables: [Variable.withString(bookId)],
        )
        .get();
    debugPrint('[OUTLINE] book=$bookId summaries rows=${rows.length}');
    if (rows.isEmpty) {
      debugPrint('[OUTLINE] book=$bookId summaries miss: 0 rows for this book');
      return null;
    }

    final groups = <OutlineGroup>[];
    OutlineGroup? vagga;
    OutlineSutta? sutta;

    for (final r in rows) {
      final vaggaTitle = r.readNullable<String>('vagga_title') ?? '';
      final suttaTitle = r.readNullable<String>('sutta_title') ?? '';
      var title = r.readNullable<String>('title') ?? '';
      if (title.trim().isEmpty) {
        title =
            r.readNullable<String>('heading_title') ??
            '${r.readNullable<int>('section_id') ?? r.read<int>('para_start')}';
      }
      final paraStart = r.read<int>('para_start');
      final paraEnd = r.read<int>('para_end');

      final item = OutlineItem(
        paraId: paraStart,
        sectionEnd: paraEnd,
        title: title,
        level: 10,
        translated: true,
      );

      if (vagga == null || vaggaTitle != vagga.title) {
        vagga = OutlineGroup(title: vaggaTitle, suttas: []);
        groups.add(vagga);
        sutta = null;
      }
      if (sutta == null || suttaTitle != sutta.title) {
        sutta = OutlineSutta(title: suttaTitle, items: []);
        vagga.suttas.add(sutta);
      }
      sutta.items.add(item);
    }

    return groups;
  } catch (e) {
    debugPrint('[OUTLINE] book=$bookId summaries miss: exception $e');
    return null;
  }
}

Future<List<OutlineGroup>> _loadFromHeadings(Ref ref, String bookId) async {
  final db = await ref.watch(epitakaDbProvider.future);

  final rows =
      await (db.select(db.headings)
            ..where((h) => h.bookId.equals(bookId))
            ..orderBy([(h) => OrderingTerm(expression: h.paraId)]))
          .get();

  if (rows.isEmpty) return const [];

  final level10 = rows.where((h) => (h.level ?? 0) == 10).toList();
  final items = level10.isNotEmpty
      ? level10
      : rows.where((h) {
          final lvl = h.level ?? 0;
          return lvl >= 2 && lvl <= 6;
        }).toList();

  if (items.isEmpty) return const [];

  final byPara = {for (final r in rows) r.paraId: r};

  /// Walk the parent chain of [pid] (excluding [pid] itself) collecting the
  /// first title at [targetLevel].
  String ancestorTitle(int? pid, int targetLevel) {
    var seen = <int>{};
    var p = pid;
    while (p != null && !seen.contains(p) && byPara.containsKey(p)) {
      seen.add(p);
      final h = byPara[p]!;
      if ((h.level ?? 0) == targetLevel) return h.title ?? '';
      p = h.parent;
    }
    return '';
  }

  // Section end for an item = the paragraph just before the next heading of
  // ANY level (a large number when it is the last section). Both lists are
  // sorted, so binary-search the next heading.
  final allParaIds = rows.map((h) => h.paraId).toList();

  int sectionEndFor(int pid) {
    var lo = 0, hi = allParaIds.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (allParaIds[mid] <= pid) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo < allParaIds.length ? allParaIds[lo] - 1 : 999999999;
  }

  final groups = <OutlineGroup>[];
  OutlineGroup? vagga;
  OutlineSutta? sutta;

  for (final it in items) {
    final level = it.level ?? 0;
    final own = it.title ?? '';
    // A level-2/4 heading acts as its own vagga/sutta group; deeper
    // headings inherit from their level-2/4 ancestor instead.
    final vaggaTitle = level == 2 ? own : ancestorTitle(it.parent, 2);
    final suttaTitle = level == 4 ? own : ancestorTitle(it.parent, 4);

    final sectionEnd = sectionEndFor(it.paraId);

    final item = OutlineItem(
      paraId: it.paraId,
      sectionEnd: sectionEnd,
      title: own,
      level: level,
    );

    // A group/sutta is ALWAYS created when the current one is null (e.g.
    // the very first item, or a book whose sections have no level-2/4
    // ancestor — there the resolved title is empty, which the UI already
    // handles by showing the book name / rendering items flat). Without
    // this, the first such item crashed with a null check on the
    // not-yet-created sutta.
    if (vagga == null || vaggaTitle != vagga.title) {
      vagga = OutlineGroup(title: vaggaTitle, suttas: []);
      groups.add(vagga);
      sutta = null;
    }
    // vagga is non-null here (created above when null).
    if (sutta == null || suttaTitle != sutta.title) {
      sutta = OutlineSutta(title: suttaTitle, items: []);
      vagga.suttas.add(sutta);
    }
    // sutta is non-null here (created above when null).
    sutta.items.add(item);
  }

  return groups;
}

/// Whether the Outline search boxes (phone screen and desktop panel) take a
/// regex over section titles (spec H). Session only, never saved, like the
/// other rx flags.
final outlineRegexProvider = StateProvider<bool>((ref) => false);
