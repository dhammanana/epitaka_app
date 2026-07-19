import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_models.dart';
import 'database_provider.dart';
import 'settings_provider.dart';

// ── Data models ────────────────────────────────────────────────────────────

/// A single row from the `pali_definition` table.
class PaliDefinitionEntry {
  final String bookId;
  final int paraId;
  final int lineId;
  final String word;
  final String plain;
  final String? ending;
  final String stem;

  const PaliDefinitionEntry({
    required this.bookId,
    required this.paraId,
    required this.lineId,
    required this.word,
    required this.plain,
    this.ending,
    required this.stem,
  });

  factory PaliDefinitionEntry.fromRow(Map<String, dynamic> row) {
    return PaliDefinitionEntry(
      bookId: row['book_id'] as String,
      paraId: row['para_id'] as int,
      lineId: row['line_id'] as int,
      word: row['word'] as String,
      plain: row['plain'] as String,
      ending: row['ending'] as String?,
      stem: row['stem'] as String,
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

      final rows = await db
          .customSelect(
            'SELECT book_id, para_id, line_id, word, plain, ending, stem '
            'FROM pali_definition WHERE word = ? LIMIT 20',
            variables: [Variable.withString(trimmed)],
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
            translationDbProvider(TranslationLanguage.fromCode(code)).future,
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
            final key = '$pid' + ':' + '$lid';
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

      return results;
    });
