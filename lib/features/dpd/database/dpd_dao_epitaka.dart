import 'package:drift/drift.dart';

import '../utils/diacritics.dart';
import 'dpd_database.dart';

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
}
