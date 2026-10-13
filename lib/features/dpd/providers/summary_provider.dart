import '../database/dpd_database.dart';
import '../database/dpd_headword_extensions.dart';
import '../models/lookup_results.dart';
import '../models/summary_entry.dart';

/// The summary lines for one lookup: headwords, then roots, then the
/// secondary sources in the order the lookup gives them. Built from the DPD
/// app's `buildSummaryEntries`; the source-visibility filter and the
/// other-dictionaries lines come with the settings page (Phase 4).
List<SummaryEntry> buildSummaryEntries(
  List<DpdHeadwordWithRoot> headwords,
  List<RootWithFamilies> roots,
  List<Object> secondary, {
  bool showConstruction = true,
}) {
  return [
    for (final hw in headwords) _buildHeadwordEntry(hw, showConstruction),
    for (final rwf in roots) _buildRootEntry(rwf),
    for (final result in secondary) ?_buildSecondaryEntry(result),
  ];
}

SummaryEntry _buildHeadwordEntry(
  DpdHeadwordWithRoot hw,
  bool showConstruction,
) {
  final (meaning, hasBold) = _buildHeadwordSummaryMeaning(
    hw.headword,
    showConstruction: showConstruction,
  );
  return SummaryEntry(
    type: SummaryEntryType.headword,
    label: hw.headword.lemma1,
    typeLabel: hw.headword.pos?.isNotEmpty == true ? '${hw.headword.pos}.' : '',
    meaning: meaning,
    meaningHasBold: hasBold,
  );
}

SummaryEntry _buildRootEntry(RootWithFamilies rwf) {
  final rootClean = rwf.root.root.replaceFirst('√', '');
  return SummaryEntry(
    type: SummaryEntryType.root,
    label: rwf.root.root,
    typeLabel: 'root.',
    meaning: '$rootClean (${rwf.root.rootMeaning})',
  );
}

SummaryEntry? _buildSecondaryEntry(Object result) {
  switch (result) {
    case SeeResult r:
      return SummaryEntry(
        type: SummaryEntryType.see,
        label: r.headword,
        typeLabel: 'see headword.',
        meaning: '',
      );
    case GrammarDictResult r:
      return SummaryEntry(
        type: SummaryEntryType.grammar,
        label: r.headword,
        typeLabel: 'grammar.',
        meaning: '',
      );
    case SpellingResult r:
      return SummaryEntry(
        type: SummaryEntryType.spelling,
        label: r.headword,
        typeLabel: 'spelling mistake.',
        meaning: '',
      );
    case VariantResult r:
      return SummaryEntry(
        type: SummaryEntryType.variant,
        label: r.headword,
        typeLabel: 'variants.',
        meaning: '',
      );
    case AbbreviationResult r:
      return SummaryEntry(
        type: SummaryEntryType.abbreviation,
        label: r.headword,
        typeLabel: 'abbreviation.',
        meaning: r.meaning,
      );
    case AbbreviationOtherResult r:
      return SummaryEntry(
        type: SummaryEntryType.abbreviationOther,
        label: r.headword,
        typeLabel: 'other abbreviations.',
        meaning: '',
      );
    case EpdResult r:
      return SummaryEntry(
        type: SummaryEntryType.epd,
        label: r.headword,
        typeLabel: 'English.',
        meaning: '',
      );
    case DeconstructorResult r:
      return SummaryEntry(
        type: SummaryEntryType.deconstructor,
        label: r.headword,
        typeLabel: 'deconstructor.',
        meaning: '',
      );
    case HelpResult r:
      return SummaryEntry(
        type: SummaryEntryType.help,
        label: r.headword,
        typeLabel: 'help.',
        meaning: '',
      );
    default:
      return null;
  }
}

(String, bool) _buildHeadwordSummaryMeaning(
  DpdHeadword headword, {
  bool showConstruction = true,
}) {
  final usesMeaning1 = headword.meaning1?.isNotEmpty == true;
  final meaning = usesMeaning1 ? headword.meaning1! : headword.meaning2 ?? '';
  final summary = headword.constructionSummary;

  if (!showConstruction) return (meaning, usesMeaning1);
  if (summary.isEmpty) return (meaning, usesMeaning1);
  if (meaning.isEmpty) return ('[$summary]', false);
  return ('$meaning [$summary]', usesMeaning1);
}
