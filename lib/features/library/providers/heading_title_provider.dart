import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';

/// Query parameters for looking up a heading title by bookId and paraId.
class HeadingQuery {
  final String bookId;
  final int paraId;

  const HeadingQuery({required this.bookId, required this.paraId});

  @override
  bool operator ==(Object other) =>
      other is HeadingQuery && bookId == other.bookId && paraId == other.paraId;

  @override
  int get hashCode => Object.hash(bookId, paraId);
}

/// Provider that fetches the nearest heading title at or before [query.paraId]
/// for the given book.
final headingTitleProvider =
    FutureProvider.family<String?, HeadingQuery>((ref, query) async {
  final db = await ref.watch(epitakaDbProvider.future);
  return db.getHeadingTitleAtPara(query.bookId, query.paraId);
});
