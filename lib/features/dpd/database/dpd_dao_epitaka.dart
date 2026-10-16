import 'package:drift/drift.dart';

import '../utils/diacritics.dart';
import '../utils/fuzzy_rank.dart';
import '../utils/query_cleaning.dart';
import 'dpd_database.dart';

/// The extra dictionaries' rows for the partial and fuzzy groups, by
/// dictionary id.
class DictLoose {
  const DictLoose({this.partial = const {}, this.fuzzy = const {}});

  final Map<String, List<DictEntry>> partial;
  final Map<String, List<DictEntry>> fuzzy;
}

/// Splits [rows] from [DpdDaoEpitaka.searchDictLoose] into the two groups.
///
/// A row whose word is [exactWord] is already in the exact card, so it goes.
/// A row whose word starts with [query] is partial; the rest only shares the
/// fuzzy key and is fuzzy, closest first. [query] and [exactWord] differ when
/// the user types an inflected form: the cards show its lemma, so a typed form
/// with an entry of its own lands in partial instead of nowhere.
DictLoose splitDictLoose({
  required String query,
  required String exactWord,
  required List<DictEntry> rows,
  int cap = 50,
}) {
  String fold(String s) => foldDpdQuery(s.trim().toLowerCase());
  final typed = fold(query);
  final exact = fold(exactWord);
  final typedKey = stripDiacritics(typed);
  final partial = <String, List<DictEntry>>{};
  final fuzzy = <String, List<DictEntry>>{};
  for (final row in rows) {
    final word = fold(row.word);
    if (word == exact) continue;
    (word.startsWith(typed) ? partial : fuzzy)
        .putIfAbsent(row.dictId, () => [])
        .add(row);
  }
  int byPali(DictEntry a, DictEntry b) =>
      paliSortKey(a.word).compareTo(paliSortKey(b.word));
  int closeness(DictEntry r) => fuzzyCloseness(
    query: typed,
    queryFuzzyKey: typedKey,
    candidate: r.word,
    candidateFuzzyKey: r.wordFuzzy ?? '',
  );
  for (final list in partial.values) {
    list.sort(byPali);
    if (list.length > cap) list.removeRange(cap, list.length);
  }
  for (final list in fuzzy.values) {
    list.sort((a, b) {
      final c = closeness(a).compareTo(closeness(b));
      return c != 0 ? c : byPali(a, b);
    });
    if (list.length > cap) list.removeRange(cap, list.length);
  }
  return DictLoose(partial: partial, fuzzy: fuzzy);
}

/// Shortest-first, then alphabetical (diacritic-insensitive), then exact.
/// Copied from the DPD app's `autocomplete_provider.dart`.
int suggestionComparator(String a, String b) {
  final cleanA = stripDiacritics(a).toLowerCase();
  final cleanB = stripDiacritics(b).toLowerCase();
  final lenDiff = cleanA.length - cleanB.length;
  if (lenDiff != 0) return lenDiff;
  if (cleanA != cleanB) return cleanA.compareTo(cleanB);
  return a.compareTo(b);
}

extension DpdDaoEpitaka on DpdDao {
  /// Lookup keys that start with [prefix] exactly as typed (diacritics and
  /// all), shortest first, so the typed word itself leads. The database
  /// sorts by length before the limit: in key order the first 100 keys of a
  /// wide range (`dhamm` has 6,711) miss short forms such as `dhammo`.
  Future<List<String>> searchLiteralPrefix(String prefix, {int limit = 100}) async {
    final typed = prefix.trim().toLowerCase();
    if (typed.length < 2) return [];
    final next =
        typed.substring(0, typed.length - 1) +
        String.fromCharCode(typed.codeUnitAt(typed.length - 1) + 1);
    final rows =
        await (selectOnly(lookup)
              ..addColumns([lookup.lookupKey])
              ..where(
                lookup.lookupKey.isBiggerOrEqualValue(typed) &
                    lookup.lookupKey.isSmallerThanValue(next),
              )
              ..orderBy([
                OrderingTerm.asc(lookup.lookupKey.length),
                OrderingTerm.asc(lookup.lookupKey),
              ])
              ..limit(limit))
            .get();
    return rows.map((r) => r.read(lookup.lookupKey)!).toList()
      ..sort(suggestionComparator);
  }

  /// Lookup keys whose folded form starts with [prefix] folded the same way,
  /// so `dhamm` finds `dhammā` and `satip` finds `satipaṭṭhāna`. The range
  /// runs on the indexed `fuzzy_key`. Lower-case first: `stripDiacritics`
  /// alone differs from the exporter's key on capitals.
  Future<List<String>> searchSuggestions(String prefix, {int limit = 200}) async {
    final folded = stripDiacritics(prefix.trim().toLowerCase());
    if (folded.length < 2) return [];
    final next =
        folded.substring(0, folded.length - 1) +
        String.fromCharCode(folded.codeUnitAt(folded.length - 1) + 1);
    final rows =
        await (selectOnly(lookup)
              ..addColumns([lookup.lookupKey])
              ..where(
                lookup.fuzzyKey.isBiggerOrEqualValue(folded) &
                    lookup.fuzzyKey.isSmallerThanValue(next),
              )
              ..limit(limit))
            .get();
    final keys = rows.map((r) => r.read(lookup.lookupKey)!).toList()
      ..sort(suggestionComparator);
    return keys;
  }

  /// Rows of [dictIds] whose fuzzy key starts with [query]'s, the candidates
  /// for [splitDictLoose], without their definitions: [withDefinitions] fetches
  /// those for the rows that are kept. One range per dictionary on the
  /// `(dict_id, word_fuzzy)` index: the DPD app's `word LIKE` reads all 659,819
  /// rows, about 100 ms for a rare word. The whole range is read, up to
  /// [perDict] words, because the index order is not Pāḷi order: `dhamma` has
  /// 1,152 PEU rows under its key, and any first 100 miss most of the 942 that
  /// start with it.
  Future<List<DictEntry>> searchDictLoose(
    List<String> dictIds,
    String query, {
    int perDict = 2000,
  }) async {
    final key = stripDiacritics(foldDpdQuery(query.trim().toLowerCase()));
    if (key.isEmpty) return [];
    final next =
        key.substring(0, key.length - 1) +
        String.fromCharCode(key.codeUnitAt(key.length - 1) + 1);
    final rows = <DictEntry>[];
    for (final dictId in dictIds) {
      final found =
          await (selectOnly(dictEntries)
                ..addColumns([
                  dictEntries.id,
                  dictEntries.word,
                  dictEntries.wordFuzzy,
                ])
                ..where(
                  dictEntries.dictId.equals(dictId) &
                      dictEntries.wordFuzzy.isBiggerOrEqualValue(key) &
                      dictEntries.wordFuzzy.isSmallerThanValue(next),
                )
                ..limit(perDict))
              .get();
      for (final r in found) {
        rows.add(
          DictEntry(
            id: r.read(dictEntries.id)!,
            dictId: dictId,
            word: r.read(dictEntries.word)!,
            wordFuzzy: r.read(dictEntries.wordFuzzy),
          ),
        );
      }
    }
    return rows;
  }

  /// [loose] with each row's definition filled in, order kept.
  Future<DictLoose> withDefinitions(DictLoose loose) async {
    final ids = {
      for (final list in [...loose.partial.values, ...loose.fuzzy.values])
        for (final r in list) r.id,
    };
    if (ids.isEmpty) return loose;
    final full = {
      for (final r in await (select(
        dictEntries,
      )..where((t) => t.id.isIn(ids))).get())
        r.id: r,
    };
    Map<String, List<DictEntry>> fill(Map<String, List<DictEntry>> groups) => {
      for (final e in groups.entries)
        e.key: [for (final r in e.value) full[r.id] ?? r],
    };
    return DictLoose(partial: fill(loose.partial), fuzzy: fill(loose.fuzzy));
  }
}
