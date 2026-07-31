/// Scoring algorithm for fuzzy match results.
///
/// Heavily inspired by nucleo-matcher (Rust) and fzf (Go).
///
/// For each matched character we add a base score and then apply a
/// series of bonuses and penalties:
///
/// | Factor                | Value | Trigger                         |
/// |-----------------------|-------|---------------------------------|
/// | Consecutive (per char)| +40   | Matches are adjacent            |
/// | Segment start         | +35   | Char after `/`                  |
/// | Word start            | +30   | Char after `-`, `_`, ` `, `.`   |
/// | Prefix match          | +25   | Match at position 0             |
/// | Gap start             | −5    | First gap character between two matched chars |
/// | Per-gap extension     | −1    | Each subsequent unmatched char in a gap |
/// | Trailing penalty      | −0.2/char | Unmatched chars after the last match |
///
/// The final score is an integer (we multiply by 10 so we can store
/// the trailing penalty as a fraction).  We also give a small bonus
/// for shorter candidate texts (shorter = better).
library;

import 'chars.dart' show charClass, CharClass;

// ── Scoring constants ────────────────────────────────────────────────

/// Base reward for every matched character.
const int _baseScore = 16;

/// Bonus per consecutive matched character (streak).
const int _bonusConsecutive = 40;

/// Match starts a new path segment (after `/`).
const int _bonusSegmentStart = 35;

/// Match starts a new word (after `-`, `_`, ` `, `.`).
const int _bonusWordStart = 30;

/// Match is at the very beginning of the text.
const int _bonusPrefix = 25;

/// Penalty for the first unmatched character in a gap.
const int _penaltyGapStart = 5;

/// Penalty for each subsequent unmatched character in a gap.
const int _penaltyGapExtension = 1;

/// Multiplier applied per trailing (unmatched) character.
///
/// Stored as tenths so we can work in integers until the final
/// division.  0.2 → 2/10.
const int _trailingPenaltyPerChar = 2;
const int _trailingDenom = 10;

/// Bonus for matching an entire path segment from start to end.
const int _bonusSegmentMatch = 45;

/// Bonus for a query that is an exact prefix of the text.
const int _bonusExactPrefix = 55;

// ── Scoring function ─────────────────────────────────────────────────

/// Score a fuzzy match result.
///
/// [text] is the full candidate text (normalised).  [positions] are the
/// matched character indices in ascending order, as returned by
/// [fuzzyMatch].
///
/// Returns a positive integer; higher is better.
int scoreMatch(String text, List<int> positions) {
  if (positions.isEmpty) return 0;

  final textLen = text.length;
  final matchLen = positions.length;

  // ── Pre-compute character classes ──────────────────────────────────
  // We only need classes for positions up to the last match, plus a
  // small lookbehind.
  final int maxClassLen;
  if (positions.last + 1 < textLen) {
    maxClassLen = positions.last + 2;
  } else {
    maxClassLen = textLen;
  }
  final classes = List<CharClass>.generate(maxClassLen, (i) => charClass(text, i));

  // ── Walk matched positions and accumulate score ────────────────────
  int total = 0;
  int streak = 0; // number of consecutive matched chars (including current)
  int prevMatchEnd = -1; // position of the previous match

  for (int mi = 0; mi < matchLen; mi++) {
    final pos = positions[mi];
    total += _baseScore;

    // ── Bonuses ────────────────────────────────────────────────────

    // Consecutive bonus: if this match is directly after the previous one.
    if (prevMatchEnd >= 0 && pos == prevMatchEnd + 1) {
      streak++;
      total += _bonusConsecutive;
      if (streak >= 2) {
        // Extra bonus for each additional consecutive char in the streak.
        total += _bonusConsecutive ~/ 2;
      }
    } else {
      streak = 1;
    }

    // Boundary bonuses based on the character BEFORE the matched position.
    if (pos == 0) {
      total += _bonusPrefix;
      total += _bonusWordStart;
      total += _bonusSegmentStart;
    } else {
      final prevClass = (pos - 1 < maxClassLen) ? classes[pos - 1] : CharClass.lower;

      if (prevClass == CharClass.separator) {
        total += _bonusSegmentStart;
        total += _bonusWordStart;

        // Check if this match completes an entire path segment.
        // We look backward from pos to find the start of the segment,
        // then see if all chars in that segment are matched.
        if (_isFullSegmentMatch(text, positions, pos)) {
          total += _bonusSegmentMatch;
        }
      } else if (prevClass == CharClass.wordSep) {
        total += _bonusWordStart;
      }
    }

    // ── Gap penalty ────────────────────────────────────────────────
    if (prevMatchEnd >= 0) {
      final gap = pos - prevMatchEnd - 1;
      if (gap > 0) {
        total -= _penaltyGapStart;
        total -= _penaltyGapExtension * (gap - 1);
      }
    }

    prevMatchEnd = pos;
  }

  // ── Exact prefix bonus ───────────────────────────────────────────
  // If the query is a prefix of the text, give a big bonus.
  if (positions.first == 0 && positions.length == text.length) {
    total += _bonusExactPrefix * 2;
  } else if (positions.first == 0) {
    total += _bonusExactPrefix;
  }

  // ── Trailing penalty ─────────────────────────────────────────────
  // Penalise characters after the last match that are not part of
  // the matched set.
  final trailing = textLen - positions.last - 1;
  if (trailing > 0) {
    // Multiply by _trailingDenom so we keep integer arithmetic.
    total = (total * _trailingDenom) - (_trailingPenaltyPerChar * trailing);
    // Divide back, rounding toward zero.
    total = total ~/ _trailingDenom;
  }

  // ── Short text bonus ─────────────────────────────────────────────
  // Shorter texts are preferred (all else being equal).
  total += (200 - textLen).clamp(0, 200);

  return total > 0 ? total : 1;
}

/// Check whether the matched positions cover an entire path segment
/// that starts right before [pos].
bool _isFullSegmentMatch(String text, List<int> positions, int pos) {
  // Find the start of the segment (character after the last `/` or
  // start of string before `pos`).
  int segStart = 0;
  for (int i = pos - 1; i >= 0; i--) {
    if (text.codeUnitAt(i) == 0x2F) {
      // 0x2F = '/'
      segStart = i + 1;
      break;
    }
  }

  // Find the end of the segment (next `/` or end of string).
  int segEnd = text.length;
  for (int i = pos; i < text.length; i++) {
    if (text.codeUnitAt(i) == 0x2F) {
      segEnd = i;
      break;
    }
  }

  if (segEnd <= segStart) return false;

  // Check if every character in [segStart, segEnd) is matched.
  // We need to verify this efficiently using the positions list.
  int pi = positions.indexOf(segStart); // finding the first position >= segStart
  if (pi < 0) {
    // Binary search for first position >= segStart
    pi = _lowerBound(positions, segStart);
    if (pi >= positions.length) return false;
  }

  int matchedIdx = pi;
  for (int i = segStart; i < segEnd; i++) {
    if (matchedIdx >= positions.length || positions[matchedIdx] != i) {
      return false;
    }
    matchedIdx++;
  }

  return true;
}

/// Find the first index in sorted [list] where value >= [target].
int _lowerBound(List<int> list, int target) {
  int lo = 0, hi = list.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (list[mid] < target) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}
