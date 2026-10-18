import 'lookup_results.dart';

/// The `kDpdSources` id of a secondary result, or null for one that has no
/// source of its own.
String? dpdSourceIdOf(Object result) => switch (result) {
  AbbreviationResult() => 'dpd_abbreviations',
  AbbreviationOtherResult() => 'dpd_abbreviations_other',
  DeconstructorResult() => 'dpd_deconstructor',
  GrammarDictResult() => 'dpd_grammar',
  HelpResult() => 'dpd_help',
  EpdResult() => 'dpd_epd',
  VariantResult() => 'dpd_variants',
  SpellingResult() => 'dpd_spelling',
  SeeResult() => 'dpd_see',
  _ => null,
};
