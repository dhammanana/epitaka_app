import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/dpd_database.dart';
import 'dpd_database_provider.dart';

/// The entries of one external DPD dictionary for one word, by exact match
/// (case and diacritics as `searchDictExact` folds them), sorted by Pāḷi order.
/// The word is [DictEntriesKey.word], the cleaned lemma the other dictionaries
/// are searched with.
final dictEntriesProvider = FutureProvider.autoDispose
    .family<List<DictEntry>, DictEntriesKey>((ref, key) async {
      final dao = await ref.watch(dpdDaoProvider.future);
      final rows = await dao.searchDictExact([key.dictId], key.word);
      return [...rows]
        ..sort((a, b) => paliSortKey(a.word).compareTo(paliSortKey(b.word)));
    });

class DictEntriesKey {
  const DictEntriesKey(this.dictId, this.word);
  final String dictId;
  final String word;

  @override
  bool operator ==(Object other) =>
      other is DictEntriesKey && dictId == other.dictId && word == other.word;

  @override
  int get hashCode => Object.hash(dictId, word);
}
