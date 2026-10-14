import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/dpd_dao_epitaka.dart';
import '../database/dpd_database.dart';
import '../database/dpd_headword_extensions.dart';
import 'dictionary_list_provider.dart';
import 'dpd_database_provider.dart';
import 'dpd_settings_provider.dart';
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
    this.partial = const [],
    this.fuzzy = const [],
  });

  final String query;
  final List<DpdHeadwordWithRoot> headwords;
  final List<RootWithFamilies> roots;
  final List<Object> secondary;

  /// Headwords that start with the query, when the setting is on. Never holds
  /// a headword that is in [headwords].
  final List<DpdHeadwordWithRoot> partial;

  /// Headwords that sound like the query, when the setting is on. Never holds
  /// a headword that is in [headwords] or [partial].
  final List<DpdHeadwordWithRoot> fuzzy;

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
      final (wantPartial, wantFuzzy) = ref.watch(
        dpdSettingsProvider.select(
          (s) => (s.showPartialResults, s.showFuzzyResults),
        ),
      );
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
      final roots = await dao.searchRoots(query);
      final row = await dao.getLookupRow(query);
      final secondary = row == null
          ? const <Object>[]
          : SecondaryResultsProvider.parse(row.lookupKey, row);
      // A word with no hit at all may still match once diacritics, aspirates
      // and doubled consonants are folded (`kammam` for `kammaṃ`). A word that
      // has a deconstruction or a variant is not misspelt: folding it would
      // add strangers (`abba` gets `abbha`) and send the other dictionaries
      // to the wrong word.
      final headwords =
          literal.isEmpty && roots.isEmpty && secondary.isEmpty
          ? await dao.searchFuzzyExact(query)
          : literal;
      final exactIds = {for (final h in headwords) h.headword.id};
      // The fuzzy tier leaves out partial hits too, so the partial list is
      // fetched when either tier is on.
      final partialAll = wantPartial || wantFuzzy
          ? [
              for (final h in await dao.searchPartial(query))
                if (!exactIds.contains(h.headword.id)) h,
            ]
          : const <DpdHeadwordWithRoot>[];
      final partialIds = {for (final h in partialAll) h.headword.id};
      final fuzzy = wantFuzzy
          ? [
              for (final h in await dao.searchFuzzy(query))
                if (!exactIds.contains(h.headword.id) &&
                    !partialIds.contains(h.headword.id))
                  h,
            ]
          : const <DpdHeadwordWithRoot>[];
      return DpdLookup(
        query: query,
        headwords: headwords,
        roots: roots,
        secondary: secondary,
        timer: timer,
        partial: wantPartial ? partialAll : const [],
        fuzzy: fuzzy,
      );
    });

/// What to offer when nothing matches the typed word: the nearest lookup keys,
/// found by trimming the word from the end (DPD `searchClosestMatches`).
final dpdClosestMatchesProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, query) async {
      final dao = await ref.watch(dpdDaoProvider.future);
      return dao.searchClosestMatches(query);
    });

/// Words that start like the typed text, for the suggestion list.
///
/// The first group that is not empty ends the search: the DPD list below, then
/// the enabled external dictionaries, then the lookup keys. Inside the DPD
/// list the words that start with exactly what the user typed come first, then
/// the exact fuzzy-key matches (a typed `-` or a missing macron), then the
/// rest of the fuzzy prefix range. A late answer cannot reach the screen: the
/// family is keyed by the draft, and the shell stops watching a draft once the
/// user submits it.
final dpdSuggestionsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, prefix) async {
      if (prefix.trim().length < 2) return [];
      final dao = await ref.watch(dpdDaoProvider.future);

      final dpd = <String>{
        ...await dao.searchLiteralPrefix(prefix),
        ...await dao.searchFuzzyExactKeyMatches(prefix),
        ...await dao.searchSuggestions(prefix),
      };
      if (dpd.isNotEmpty) return dpd.toList();

      final enabled = ref.watch(dictionaryListProvider).valueOrNull ?? const [];
      final dictIds = [
        for (final e in enabled)
          if (e.enabled && e.item.kind == DictionaryItemKind.external)
            e.item.id,
      ];
      final dictWords = await dao.searchDictWordsPrefix(dictIds, prefix);
      if (dictWords.isNotEmpty) {
        return dictWords..sort(suggestionComparator);
      }

      final keys = await dao.searchLookupKeysPrefix(prefix);
      return keys..sort(suggestionComparator);
    });
