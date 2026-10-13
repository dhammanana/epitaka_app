import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/dpd_dao_epitaka.dart';
import '../database/dpd_database.dart';
import '../database/dpd_headword_extensions.dart';
import 'dpd_database_provider.dart';
import 'secondary_results_provider.dart';

/// Everything DPD knows about one typed word: headwords, roots and the
/// secondary sources (deconstructor, grammar, EPD and the rest).
class DpdLookup {
  DpdLookup({
    required this.query,
    required this.headwords,
    required this.roots,
    required this.secondary,
    required this.timer,
    this.unavailable,
  });

  final String query;
  final List<DpdHeadwordWithRoot> headwords;
  final List<RootWithFamilies> roots;
  final List<Object> secondary;

  /// Started when the lookup began, read at the first frame after it draws.
  final Stopwatch timer;

  /// Set when there is no readable DPD database. The other dictionaries still
  /// answer, so this is data and not an error.
  final DpdUnavailable? unavailable;

  bool get hasMatch =>
      headwords.isNotEmpty || roots.isNotEmpty || secondary.isNotEmpty;

  /// The word the other dictionaries are searched with: the first headword's
  /// lemma without its homograph number, else what the user typed.
  String get searchWord =>
      headwords.isEmpty ? query : headwords.first.headword.lemmaClean;
}

final dpdLookupProvider = FutureProvider.autoDispose
    .family<DpdLookup, String>((ref, query) async {
      final timer = Stopwatch()..start();
      final DpdDao dao;
      try {
        dao = await ref.watch(dpdDaoProvider.future);
      } on DpdUnavailable catch (e) {
        return DpdLookup(
          query: query,
          headwords: const [],
          roots: const [],
          secondary: const [],
          timer: timer,
          unavailable: e,
        );
      }
      if (query.trim().isEmpty) {
        return DpdLookup(
          query: query,
          headwords: const [],
          roots: const [],
          secondary: const [],
          timer: timer,
        );
      }
      final literal = await dao.searchExact(query);
      // A word with no literal hit may still match once diacritics, aspirates
      // and doubled consonants are folded (`kammam` for `kammaṃ`).
      final headwords = literal.isEmpty
          ? await dao.searchFuzzyExact(query)
          : literal;
      final roots = await dao.searchRoots(query);
      final row = await dao.getLookupRow(query);
      final secondary = row == null
          ? const <Object>[]
          : SecondaryResultsProvider.parse(row.lookupKey, row);
      return DpdLookup(
        query: query,
        headwords: headwords,
        roots: roots,
        secondary: secondary,
        timer: timer,
      );
    });

/// Words that start like the typed text, for the suggestion list.
final dpdSuggestionsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, prefix) async {
      if (prefix.trim().length < 2) return [];
      final dao = await ref.watch(dpdDaoProvider.future);
      return dao.searchSuggestions(prefix);
    });
