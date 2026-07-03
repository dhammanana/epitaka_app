import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';
import '../../../core/providers/database_provider.dart';

/// Provider that fetches the table of contents (headings) for a given book.
final contentsProvider =
    FutureProvider.family<List<HeadingInfo>, String>((ref, bookId) async {
  final db = await ref.watch(epitakaDbProvider.future);

  final rows = await (db.select(db.headings)
        ..where((h) =>
            h.bookId.equals(bookId) & h.level.isSmallerThan(const Constant(10)))
        ..orderBy([(h) => OrderingTerm(expression: h.paraId)]))
      .get();

  return rows
      .map((row) => HeadingInfo(
            bookId: row.bookId,
            paraId: row.paraId,
            level: row.level,
            title: row.title,
            chapterLen: row.chapterLen,
            parent: row.parent,
            scId: row.scId,
          ))
      .toList();
});
