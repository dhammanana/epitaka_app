import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';

/// The start of a VRI paragraph number: `36` → 36, `36-37` → 36,
/// `18-19-20` → 18. Null when there is no number.
int? parseParagraphNumber(String? vripara) {
  if (vripara == null) return null;
  return int.tryParse(vripara.split('-').first.trim());
}

/// One numbered paragraph of a book.
typedef NumberedParagraph = ({int paraId, int number});

/// The numbered paragraphs of one book, in paragraph order.
class ParagraphNumberIndex {
  final List<NumberedParagraph> entries;
  final int lastParaId;

  /// Paragraphs that are titles (sutta, vagga and other headings above
  /// level 10). None of them carries a number itself.
  final Set<int> titleParaIds;

  /// Every paragraph id of the book, sorted; ids skip in some books.
  final List<int> paraIds;

  const ParagraphNumberIndex({
    required this.entries,
    required this.lastParaId,
    this.titleParaIds = const {},
    this.paraIds = const [],
  });

  /// Builds the index from `(para_id, vripara)` rows in paragraph order.
  ///
  /// Section headings such as "2. Dutiyapaṇṇāsakaṃ" carry their section
  /// number in `vripara`, so a lone 2 sits between 50 and 51. Left in, it
  /// would pull a jump for sutta 2 to the middle of the book. A number that
  /// falls below the one before while the next carries on above it is
  /// dropped; a real restart keeps falling and stays.
  factory ParagraphNumberIndex.fromRows(
    Iterable<({int paraId, String? vripara})> rows, {
    required int lastParaId,
    Set<int> titleParaIds = const {},
    List<int> paraIds = const [],
  }) {
    final numbered = <NumberedParagraph>[];
    for (final row in rows) {
      final number = parseParagraphNumber(row.vripara);
      if (number != null) numbered.add((paraId: row.paraId, number: number));
    }
    final entries = <NumberedParagraph>[];
    for (var i = 0; i < numbered.length; i++) {
      final isLoneDip =
          i > 0 &&
          i + 1 < numbered.length &&
          numbered[i].number < numbered[i - 1].number &&
          numbered[i + 1].number > numbered[i - 1].number;
      if (!isLoneDip) entries.add(numbered[i]);
    }
    return ParagraphNumberIndex(
      entries: entries,
      lastParaId: lastParaId,
      titleParaIds: titleParaIds,
      paraIds: paraIds,
    );
  }

  /// The numbered paragraph [paraId] belongs to: the one at or before it,
  /// except that a title belongs to the section it introduces, the next
  /// numbered paragraph, when only titles stand between them. A contents
  /// jump lands on the title line, just before its sutta's number (live
  /// test: the commentaries went to the previous sutta). The headings
  /// inside a commentary's opening have text after them, so the opening
  /// still never matches (`Sp-i` titles 3–259, first number at 491).
  NumberedParagraph? numberFor(int paraId) {
    if (titleParaIds.contains(paraId)) {
      final next = entries.where((e) => e.paraId > paraId).firstOrNull;
      if (next != null && _onlyTitlesBetween(paraId, next.paraId)) return next;
    }
    return numberedAtOrBefore(paraId);
  }

  bool _onlyTitlesBetween(int from, int to) {
    for (final id in paraIds) {
      if (id >= to) break;
      if (id > from && !titleParaIds.contains(id)) return false;
    }
    return true;
  }

  /// The last numbered paragraph at or before [paraId], or null.
  NumberedParagraph? numberedAtOrBefore(int paraId) {
    var low = 0;
    var high = entries.length - 1;
    NumberedParagraph? found;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (entries[mid].paraId <= paraId) {
        found = entries[mid];
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return found;
  }

  double positionOf(int paraId) => lastParaId == 0 ? 0 : paraId / lastParaId;
}

/// A paragraph of the source book and a paragraph of the target book that
/// a word-level `book_links` row joins.
typedef ParagraphLink = ({int sourceParaId, int targetParaId});

/// The paragraph of [target] that matches the paragraph [sourceTopParaId]
/// of [source], or null to leave the target where it is.
///
/// The commentary skips plain suttas or covers several with one range, so
/// the target paragraph is the one with the highest number at or below the
/// source's. Numbers restart inside some books (the Jātaka, the Apadāna), so
/// several paragraphs can share that number. Then the word [links] between
/// the two books decide: the candidate nearest the paragraph linked from
/// closest to the source wins. One commentary often serves several mūla
/// books, so a relative place in the book misleads there; it is used only
/// when the two books have no links (artifacts/link_check.txt: ties near
/// the linked paragraph rise from 37% to 92%).
int? matchParagraph(
  ParagraphNumberIndex source,
  int sourceTopParaId,
  ParagraphNumberIndex target, {
  List<ParagraphLink> links = const [],
}) {
  final from = source.numberFor(sourceTopParaId);
  if (from == null) return null;

  int? best;
  for (final entry in target.entries) {
    if (entry.number <= from.number && (best == null || entry.number > best)) {
      best = entry.number;
    }
  }
  if (best == null) return null;

  final anchor = _linkedParaNear(links, from.paraId);
  final sourcePosition = source.positionOf(from.paraId);
  double distanceOf(NumberedParagraph entry) => anchor != null
      ? (entry.paraId - anchor).abs().toDouble()
      : (target.positionOf(entry.paraId) - sourcePosition).abs();

  NumberedParagraph? closest;
  var closestDistance = double.infinity;
  for (final entry in target.entries) {
    if (entry.number != best) continue;
    final distance = distanceOf(entry);
    if (distance < closestDistance) {
      closest = entry;
      closestDistance = distance;
    }
  }
  return closest?.paraId;
}

/// The target paragraph of the link whose source paragraph is nearest
/// [paraId]; [links] are sorted by source paragraph.
int? _linkedParaNear(List<ParagraphLink> links, int paraId) {
  if (links.isEmpty) return null;
  var low = 0;
  var high = links.length;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (links[mid].sourceParaId < paraId) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  final after = low < links.length ? links[low] : null;
  final before = low > 0 ? links[low - 1] : null;
  if (after == null) return before!.targetParaId;
  if (before == null) return after.targetParaId;
  return paraId - before.sourceParaId <= after.sourceParaId - paraId
      ? before.targetParaId
      : after.targetParaId;
}

/// The numbered paragraphs of [bookId], read from `sentences.vripara`.
final paragraphNumberIndexProvider =
    FutureProvider.family<ParagraphNumberIndex, String>((ref, bookId) async {
      final db = await ref.watch(epitakaDbProvider.future);
      final rows = await db
          .customSelect(
            '''
  SELECT para_id, vripara FROM sentences
  WHERE book_id = ? AND vripara IS NOT NULL AND vripara <> ''
  ORDER BY para_id, line_id
  ''',
            variables: [Variable.withString(bookId)],
          )
          .get();
      final last = await db
          .customSelect(
            'SELECT MAX(para_id) AS last FROM sentences WHERE book_id = ?',
            variables: [Variable.withString(bookId)],
          )
          .getSingle();
      final titles = await db
          .customSelect(
            'SELECT para_id FROM headings WHERE book_id = ? AND level < 10',
            variables: [Variable.withString(bookId)],
          )
          .get();
      final paragraphs = await db
          .customSelect(
            'SELECT DISTINCT para_id FROM sentences WHERE book_id = ? '
            'ORDER BY para_id',
            variables: [Variable.withString(bookId)],
          )
          .get();

      return ParagraphNumberIndex.fromRows(
        rows.map(
          (row) => (
            paraId: row.data['para_id'] as int,
            vripara: row.data['vripara'] as String?,
          ),
        ),
        lastParaId: (last.data['last'] as int?) ?? 0,
        titleParaIds: {for (final row in titles) row.data['para_id'] as int},
        paraIds: [for (final row in paragraphs) row.data['para_id'] as int],
      );
    });

/// The paragraph pairs that word links join between two books, as
/// `(source, target)`, sorted by the source paragraph.
final paragraphLinksProvider =
    FutureProvider.family<
      List<ParagraphLink>,
      ({String sourceBookId, String targetBookId})
    >((ref, books) async {
      final db = await ref.watch(epitakaDbProvider.future);
      final rows = await db
          .customSelect(
            '''
  SELECT src_para AS source, dst_para AS target FROM book_links
  WHERE src_book = ? AND dst_book = ?
  UNION
  SELECT dst_para AS source, src_para AS target FROM book_links
  WHERE src_book = ? AND dst_book = ?
  ORDER BY source, target
  ''',
            variables: [
              Variable.withString(books.sourceBookId),
              Variable.withString(books.targetBookId),
              Variable.withString(books.targetBookId),
              Variable.withString(books.sourceBookId),
            ],
          )
          .get();
      return [
        for (final row in rows)
          (
            sourceParaId: row.data['source'] as int,
            targetParaId: row.data['target'] as int,
          ),
      ];
    });
