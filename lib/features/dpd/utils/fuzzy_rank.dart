/// Ranks a fuzzy-search candidate by closeness to the user's query.
///
/// Lower scores are closer. Tier 0 (an exact `fuzzy_key` match) always ranks
/// above tier 1 (a mere prefix extension). Within a tier, candidates are
/// ordered by how much their length differs from the query's — since the
/// fuzzy key folds away diacritics, aspirate `h`, and doubled consonants,
/// an equal-length tier-0 candidate differs from the query by diacritics
/// alone, which is exactly the mistake a user makes omitting a macron.
int fuzzyCloseness({
  required String query,
  required String queryFuzzyKey,
  required String candidate,
  required String candidateFuzzyKey,
}) {
  final tier = candidateFuzzyKey == queryFuzzyKey ? 0 : 1;
  final delta = (candidate.length - query.length).abs().clamp(0, 999);
  return tier * 1000 + delta;
}
