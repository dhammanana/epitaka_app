import '../database/dpd_database.dart';
import '../models/lookup_results.dart';

/// Parses a [LookupData] row into an ordered list of secondary result objects.
///
/// Results are ordered: abbreviations → deconstructor → grammar → help →
/// EPD → variant → spelling → see → other abbreviations.
/// Null or empty columns produce no entry.
class SecondaryResultsProvider {
  static List<Object> parse(String headword, LookupData row) {
    final results = <Object>[];

    final abbrev = AbbreviationResult.fromJson(headword, row.abbrev);
    if (abbrev != null) results.add(abbrev);

    final deconstructor = DeconstructorResult.fromJson(
      headword,
      row.deconstructor,
    );
    if (deconstructor != null) results.add(deconstructor);

    final grammar = GrammarDictResult.fromJson(headword, row.grammar);
    if (grammar != null) results.add(grammar);

    final help = HelpResult.fromJson(headword, row.help);
    if (help != null) results.add(help);

    final epd = EpdResult.fromJson(headword, row.epd);
    if (epd != null) results.add(epd);

    final variant = VariantResult.fromJson(headword, row.variant);
    if (variant != null) results.add(variant);

    final spelling = SpellingResult.fromJson(headword, row.spelling);
    if (spelling != null) results.add(spelling);

    final see = SeeResult.fromJson(headword, row.see);
    if (see != null) results.add(see);

    final abbrevOther = AbbreviationOtherResult.fromJson(
      headword,
      row.abbrevOther,
    );
    if (abbrevOther != null) results.add(abbrevOther);

    return results;
  }
}
