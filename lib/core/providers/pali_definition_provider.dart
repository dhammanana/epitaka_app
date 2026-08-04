import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/pali_stemmer.dart';
import 'database_provider.dart';
import 'settings_provider.dart';

// ── Search prefix ─────────────────────────────────────────────────────────

/// Pāli vowels (short + long). Used to trim the search word into a prefix.
const String _paliVowels = 'aāiīuūeo';

/// Maximum number of distinct matched words kept for a search (closest
/// words first). Variant forms (e.g. the sandhi "gacchatīti") are guaranteed
/// a slot even when the exact word has hundreds of occurrences.
const int _maxPaliDefinitionWords = 25;

/// Maximum number of canon occurrences shown per distinct word.
const int _maxPaliDefinitionPerWord = 5;

/// Build the prefix used to search `pali_definition.word` for [word].
///
/// The canon may spell a word slightly differently from the searched
/// lemma (e.g. the sandhi form "gacchatīti" for "gacchati"). To catch
/// those variants we stem the word, then — when the result is longer than
/// 5 characters — drop the trailing vowel so a prefix search (`gacchat%`)
/// also matches closely-related forms.
String paliDefinitionSearchPrefix(String word) {
  var prefix = PaliStemmer.getStem(word.trim().toLowerCase());
  if (prefix.length > 5 && _paliVowels.contains(prefix[prefix.length - 1])) {
    prefix = prefix.substring(0, prefix.length - 1);
  }
  return prefix;
}

// ── Data models ────────────────────────────────────────────────────────────

/// A single row from the `pali_definition` table.
///
/// NOTE: The `pali_definition` table shipped in the core DB has the columns
/// `book_id, para_id, line_id, word, plain, ending` — there is NO `stem`
/// column. Selecting a non-existent column makes the whole query fail
/// (`no such column: stem`), which the section widget silently swallows,
/// hiding the Bold Definition results entirely.
class PaliDefinitionEntry {
  final String bookId;
  final int paraId;
  final int lineId;
  final String word;
  final String plain;
  final String? ending;

  const PaliDefinitionEntry({
    required this.bookId,
    required this.paraId,
    required this.lineId,
    required this.word,
    required this.plain,
    this.ending,
  });

  factory PaliDefinitionEntry.fromRow(Map<String, dynamic> row) {
    return PaliDefinitionEntry(
      bookId: row['book_id'] as String,
      paraId: row['para_id'] as int,
      lineId: row['line_id'] as int,
      word: row['word'] as String,
      plain: row['plain'] as String,
      ending: row['ending'] as String?,
    );
  }
}

/// A `pali_definition` entry linked to its source sentence (Pāli + the
/// translation of the first activated language) plus optional context lines.
class PaliDefinitionResult {
  final PaliDefinitionEntry entry;

  /// The Pāli sentence that contains this definition.
  final String pali;

  /// The translation of [pali] in the first activated language.
  final String? translation;

  /// Context lines (Pāli) immediately before/after [pali], included only
  /// when [pali] is shorter than [_shortPaliThreshold].
  final List<String> beforeLines;
  final List<String> afterLines;

  const PaliDefinitionResult({
    required this.entry,
    required this.pali,
    this.translation,
    this.beforeLines = const [],
    this.afterLines = const [],
  });
}

// ── Provider ───────────────────────────────────────────────────────────────

/// Pāli length below which we pull the surrounding context lines.
const int _shortPaliThreshold = 100;

/// Looks up a word in the `pali_definition` table and links each match to its
/// source sentence in `epitaka.sentences` (Pāli) and the first activated
/// translation database (translation).
final paliDefinitionProvider = FutureProvider.autoDispose
    .family<List<PaliDefinitionResult>, String>((ref, word) async {
      final trimmed = word.trim().toLowerCase();
      if (trimmed.isEmpty) return [];

      final db = await ref.read(epitakaDbProvider.future);
      final settings = ref.read(settingsProvider);

      // The ordered list of activated translation languages. We show the
      // translation of the FIRST language (in this order) that actually has
      // a translation for a given line.
      final langCodes = settings.enabledTranslations.isNotEmpty
          ? settings.enabledTranslations.toList()
          : [settings.primaryTranslationLang];

      // Prefix search (not exact) so the word is found even when the canon
      // spells it differently (e.g. searching "gacchati" also matches the
      // sandhi form "gacchatīti"). Rows are picked shortest-first so the
      // closest words survive the row limit: we rank distinct words by
      // (length, word) and keep at most [_maxPaliDefinitionWords] of them,
      // each with up to [_maxPaliDefinitionPerWord] canon occurrences.
      final prefix = paliDefinitionSearchPrefix(trimmed);
      if (prefix.isEmpty) return [];

      final rows = await db
          .customSelect(
            'WITH ranked AS ( '
            '  SELECT book_id, para_id, line_id, word, plain, ending, '
            '         DENSE_RANK() OVER ('
            '           ORDER BY length(word), word) AS word_rank, '
            '         ROW_NUMBER() OVER ('
            '           PARTITION BY word ORDER BY book_id, para_id, line_id) AS rn '
            '  FROM pali_definition WHERE word LIKE ? '
            ') '
            'SELECT book_id, para_id, line_id, word, plain, ending '
            'FROM ranked '
            // The exact word is always included even when it is long enough
            // to fall outside the closest-words cap (e.g. searching the
            // sandhi form itself); variants fill the remaining slots.
            'WHERE (word_rank <= ? OR word = ?) AND rn <= ? '
            'ORDER BY length(word), word, book_id, para_id, line_id',
            variables: [
              Variable.withString('$prefix%'),
              Variable.withInt(_maxPaliDefinitionWords),
              Variable.withString(trimmed),
              Variable.withInt(_maxPaliDefinitionPerWord),
            ],
          )
          .get();

      if (rows.isEmpty) return [];

      final entries = rows
          .map((r) => PaliDefinitionEntry.fromRow(r.data))
          .toList();

      // Group entries by (bookId, paraId) so we can fetch sentences in bulk
      // per paragraph rather than per line.
      final byBookPara = <String, Map<int, List<PaliDefinitionEntry>>>{};
      for (final e in entries) {
        byBookPara.putIfAbsent(e.bookId, () => {});
        byBookPara[e.bookId]!.putIfAbsent(e.paraId, () => []).add(e);
      }

      final results = <PaliDefinitionResult>[];

      for (final bookEntry in byBookPara.entries) {
        final bookId = bookEntry.key;
        final paraIds = bookEntry.value.keys.toList();

        // Pāli sentences for this book/paragraph.
        final paliRows = await db
            .customSelect(
              'SELECT para_id, line_id, pali FROM sentences '
              'WHERE book_id = ? AND para_id IN (${paraIds.map((_) => '?').join(',')})',
              variables: [
                Variable.withString(bookId),
                for (final p in paraIds) Variable.withInt(p),
              ],
            )
            .get();
        final paliByPara = <int, Map<int, String>>{};
        for (final r in paliRows) {
          final pid = r.data['para_id'] as int;
          final lid = r.data['line_id'] as int;
          final pali = (r.data['pali'] as String?) ?? '';
          paliByPara.putIfAbsent(pid, () => {})[lid] = pali;
        }

        // Translation sentences, tried per enabled language in order.
        // Keyed by (para_id, line_id) so we pick the first language that
        // actually provides a translation for each line.
        final translationByLine = <String, String>{};
        for (final code in langCodes) {
          final transDb = await ref.read(
            translationDbProvider(code).future,
          );
          if (transDb == null) continue;
          final transRows = await transDb
              .customSelect(
                'SELECT para_id, line_id, translation FROM sentences '
                'WHERE book_id = ? AND para_id IN (${paraIds.map((_) => '?').join(',')})',
                variables: [
                  Variable.withString(bookId),
                  for (final p in paraIds) Variable.withInt(p),
                ],
              )
              .get();
          for (final r in transRows) {
            final pid = r.data['para_id'] as int;
            final lid = r.data['line_id'] as int;
            final text = (r.data['translation'] as String?) ?? '';
            if (text.trim().isEmpty) continue;
            final key = '$pid:$lid';
            // Keep the first (highest-priority) language's translation.
            translationByLine.putIfAbsent(key, () => text);
          }
        }

        for (final paraEntry in bookEntry.value.entries) {
          final paraId = paraEntry.key;
          final lineMap = paliByPara[paraId] ?? {};
          for (final entry in paraEntry.value) {
            final pali = lineMap[entry.lineId] ?? '';
            final translation = translationByLine['$paraId:${entry.lineId}'];

            final beforeLines = <String>[];
            final afterLines = <String>[];
            if (pali.length < _shortPaliThreshold) {
              final sortedLines = lineMap.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key));
              final idx = sortedLines.indexWhere((e) => e.key == entry.lineId);
              if (idx > 0) beforeLines.add(sortedLines[idx - 1].value);
              if (idx >= 0 && idx < sortedLines.length - 1) {
                afterLines.add(sortedLines[idx + 1].value);
              }
            }

            results.add(
              PaliDefinitionResult(
                entry: entry,
                pali: pali,
                translation: translation,
                beforeLines: beforeLines,
                afterLines: afterLines,
              ),
            );
          }
        }
      }

      // Closest words first: exact matches, then by word length (shortest =
      // nearest to the searched term — e.g. "gacchatīti" before the
      // two-word combination "gacchati buddhaṃ"), then alphabetically,
      // then canon location.
      results.sort((a, b) {
        final aExact = a.entry.word == trimmed ? 0 : 1;
        final bExact = b.entry.word == trimmed ? 0 : 1;
        if (aExact != bExact) return aExact - bExact;
        final lenCmp = a.entry.word.length.compareTo(b.entry.word.length);
        if (lenCmp != 0) return lenCmp;
        final wordCmp = a.entry.word.compareTo(b.entry.word);
        if (wordCmp != 0) return wordCmp;
        final bookCmp = a.entry.bookId.compareTo(b.entry.bookId);
        if (bookCmp != 0) return bookCmp;
        if (a.entry.paraId != b.entry.paraId) {
          return a.entry.paraId - b.entry.paraId;
        }
        return a.entry.lineId - b.entry.lineId;
      });

      return results;
    });
