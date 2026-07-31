/// Data models for the fuzzy matcher library.
///
/// These are designed to be simplistic and reusable across projects.
library;

/// A single fuzzy match result.
///
/// Contains the score (higher is better), the positions of matched
/// characters within the candidate string, and the original candidate
/// index so the caller can map back to their own data structures.
class ScoredMatch {
  /// 0-based index of the candidate in the original input list.
  final int index;

  /// Match score (higher = better match).
  final int score;

  /// Sorted list of character positions within the candidate string
  /// that matched the query.  Can be used for UI highlighting.
  final List<int> positions;

  const ScoredMatch({
    required this.index,
    required this.score,
    required this.positions,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScoredMatch &&
          index == other.index &&
          score == other.score;

  @override
  int get hashCode => Object.hash(index, score);

  @override
  String toString() => 'ScoredMatch(idx=$index, score=$score, pos=$positions)';
}
