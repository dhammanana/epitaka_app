import 'dart:convert';

import 'inflection_table_data.dart';

// pos values that use "Declension" button label
const _declensionPos = {
  'adj',
  'card',
  'cs',
  'fem',
  'masc',
  'nt',
  'ordin',
  'pp',
  'pron',
  'prp',
  'ptp',
  'root',
  've',
  'letter',
};

// pos values that use "Conjugation" button label
const _conjugationPos = {
  'aor',
  'cond',
  'fut',
  'imp',
  'imperf',
  'opt',
  'perf',
  'pr',
};

/// Extracts the set of all inflected word forms from a template without building
/// the full table structure. Used for targeted lookup-table occurrence checks.
Set<String> extractWordForms({required String? stem, required String templateData}) {
  if (stem == null || stem == '-') return {};
  final isIrregular = RegExp(r'^[!*]+$').hasMatch(stem);
  final cleanStem = stem.replaceAll(RegExp(r'[!*]'), '');
  final grid = jsonDecode(templateData) as List;
  final words = <String>{};
  for (int row = 1; row < grid.length; row++) {
    final rowData = grid[row] as List;
    for (int col = 1; col < rowData.length; col += 2) {
      for (final ending in rowData[col] as List) {
        final e = ending as String;
        if (e.isEmpty) continue;
        words.add(isIrregular ? e : '$cleanStem$e');
      }
    }
  }
  return words;
}

/// Builds a structured [InflectionTableData] from raw headword and template data.
///
/// Returns null for indeclinables (stem == '-').
/// If [lookupKeys] is provided, each form's [InflectionForm.isOccurring] is set
/// based on whether the word exists in the set.
InflectionTableData? buildInflectionTable({
  required String? stem,
  required String? pattern,
  required String? pos,
  required String lemma1,
  required String? templateLike,
  required String templateData,
  Set<String>? lookupKeys,
}) {
  if (stem == null || stem == '-') return null;

  final isIrregular = RegExp(r'^[!*]+$').hasMatch(stem);
  final cleanStem = stem.replaceAll(RegExp(r'[!*]'), '');

  final grid = jsonDecode(templateData) as List;

  final headerRow = grid[0] as List;
  final headers = <String>[''];
  for (int col = 1; col < headerRow.length; col += 2) {
    final cell = headerRow[col] as List;
    headers.add(cell.isNotEmpty ? cell[0] as String : '');
  }

  final rows = <(String, List<InflectionCell>)>[];
  for (int row = 1; row < grid.length; row++) {
    final rowData = grid[row] as List;
    final labelCell = rowData[0] as List;
    final rowLabel = labelCell.isNotEmpty ? labelCell[0] as String : '';

    final cells = <InflectionCell>[];
    for (int col = 1; col < rowData.length; col += 2) {
      final endingCell = rowData[col] as List;
      final tooltipCol = col + 1;
      String? tooltip;
      if (tooltipCol < rowData.length) {
        final tooltipCell = rowData[tooltipCol] as List;
        if (tooltipCell.isNotEmpty) {
          tooltip = tooltipCell[0] as String;
          if (tooltip.isEmpty) tooltip = null;
        }
      }

      final forms = <InflectionForm>[];
      for (final ending in endingCell) {
        final e = ending as String;
        if (e.isEmpty) continue;
        final word = isIrregular ? e : '$cleanStem$e';
        final isOccurring = lookupKeys == null || lookupKeys.contains(word);
        forms.add(InflectionForm(stem: cleanStem, ending: e, word: word, isOccurring: isOccurring));
      }
      cells.add(InflectionCell(forms: forms, grammarTooltip: tooltip));
    }

    rows.add((rowLabel, cells));
  }

  final buttonLabel = _conjugationPos.contains(pos)
      ? 'Conjugation'
      : _declensionPos.contains(pos)
      ? 'Declension'
      : 'Declension';

  final lemmaBase = lemma1.split(' ').first;
  final declLabel = buttonLabel == 'Conjugation' ? 'conjugation' : 'declension';
  final isLikeIrregular =
      isIrregular ||
      templateLike == null ||
      templateLike.isEmpty ||
      templateLike == 'irreg';

  return InflectionTableData(
    headers: headers,
    rows: rows,
    buttonLabel: buttonLabel,
    headingLemma: lemmaBase,
    headingPattern: pattern ?? '',
    headingDeclLabel: declLabel,
    headingLike: isLikeIrregular ? null : templateLike,
    headingIsIrregular: isLikeIrregular,
  );
}
