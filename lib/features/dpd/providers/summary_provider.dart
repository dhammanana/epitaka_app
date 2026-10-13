import '../database/dpd_database.dart';
import '../database/dpd_headword_extensions.dart';
import '../models/lookup_results.dart';
import '../models/dpd_source_id.dart';
import '../models/summary_entry.dart';

/// The summary lines for the DPD part of one lookup. With no [sources],
/// headwords, then roots, then the secondary sources in the order the lookup
/// gives them. With [sources], only those, in that order, as the DPD app's
/// `buildSummaryEntries` does with the user's list.
///
/// With [withTargets] each line names the card it scrolls to
/// (`hw_<id>`, `root_<root>`, `sec_<source>#<n>`); the Saṅkhitta level has no
/// cards, so its lines have no target.
List<SummaryEntry> buildSummaryEntries(
  List<DpdHeadwordWithRoot> headwords,
  List<RootWithFamilies> roots,
  List<Object> secondary, {
  bool showConstruction = true,
  List<String>? sources,
  bool withTargets = false,
}) {
  final ids = sources ??
      [
        'dpd_headwords',
        'dpd_roots',
        ...{for (final r in secondary) ?dpdSourceIdOf(r)},
      ];
  final out = <SummaryEntry>[];
  for (final id in ids) {
    if (id == 'dpd_headwords') {
      for (final hw in headwords) {
        out.add(
          _buildHeadwordEntry(hw, showConstruction).withTarget(
            withTargets ? 'hw_${hw.headword.id}' : '',
          ),
        );
      }
    } else if (id == 'dpd_roots') {
      for (final rwf in roots) {
        out.add(
          _buildRootEntry(rwf).withTarget(
            withTargets ? 'root_${rwf.root.root}' : '',
          ),
        );
      }
    } else {
      var n = 0;
      for (final result in secondary) {
        if (dpdSourceIdOf(result) != id) continue;
        final entry = _buildSecondaryEntry(result);
        if (entry != null) {
          out.add(entry.withTarget(withTargets ? secondaryTarget(id, n) : ''));
        }
        n++;
      }
    }
  }
  return out;
}

/// The anchor id of the [n]th result of a secondary source.
String secondaryTarget(String sourceId, int n) => 'sec_$sourceId#$n';

const _dictShortNames = {
  'cone': 'Cone',
  'cpd': 'CPD',
  'dppn': 'DPPN',
  'mw': 'MW',
  'peu': 'PEU',
  'bhs': 'BHS',
  'apte': 'Apte',
  'wordnet': 'WordNet',
  'nyanatiloka': 'Nyanatiloka',
  'pts': 'PTS',
};

/// A one-word name for an external dictionary, from the DPD app's
/// `dictShortName`: the capitalised id for one that is not in the map.
String dictShortName(String dictId) {
  final known = _dictShortNames[dictId];
  if (known != null) return known;
  if (dictId.isEmpty) return dictId;
  return dictId[0].toUpperCase() + dictId.substring(1);
}

/// The summary line of one dictionary that has an entry for the word:
/// [shortName] is what the dictionary is called, [word] the entry's headword,
/// and [targetId] the card it scrolls to.
SummaryEntry dictionarySummaryLine({
  required String shortName,
  required String word,
  required String targetId,
}) => SummaryEntry(
  type: SummaryEntryType.dict,
  label: word,
  typeLabel: '$shortName.',
  meaning: '',
  targetId: targetId,
);

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
