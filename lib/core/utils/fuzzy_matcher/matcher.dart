/// Core matching algorithm: greedy forward scan + backward optimisation.
///
/// This is a port of fzf's `FuzzyMatchV2` forward/backward passes,
/// adapted for Dart.  The algorithm is O(n) per candidate with respect
/// to the candidate length.
///
/// **Forward pass** – walk through the query left-to-right, finding the
/// earliest occurrence of each query character in the candidate text.
/// If any query character cannot be found the candidate is rejected.
///
/// **Backward pass** – walk the matched positions in reverse, tightening
/// each one as much as possible without breaking later matches.  This
/// makes the matched substring more compact, which improves the score.
library;

/// Matches [query] against [text] and returns the optimal matched
/// character positions, or `null` if no match is possible.
///
/// Both [query] and [text] should already be normalised (lowercased,
/// diacritics stripped) before calling this function.
///
/// The returned list is sorted in ascending order.
List<int>? fuzzyMatch(String query, String text) {
  if (query.isEmpty) return <int>[];
  if (text.isEmpty) return null;

  // ── Greedy forward pass ────────────────────────────────────────────
  final fw = List<int>.filled(query.length, -1);
  int ti = 0;

  for (int qi = 0; qi < query.length; qi++) {
    final qc = query.codeUnitAt(qi);

    // Skip spaces in the query (they should not affect matching).
    if (qc == 0x20) {
      // Propagate the position from the previous non-space char.
      if (qi > 0) fw[qi] = fw[qi - 1];
      continue;
    }

    while (ti < text.length && text.codeUnitAt(ti) != qc) {
      ti++;
    }
    if (ti >= text.length) return null; // character not found
    fw[qi] = ti;
    ti++;
  }

  // ── Backward optimisation ──────────────────────────────────────────
  // Walk backwards and tighten each match to the latest possible
  // position that still leaves room for earlier characters.
  final bw = List<int>.from(fw);
  ti = text.length - 1;

  for (int qi = query.length - 1; qi >= 0; qi--) {
    final qc = query.codeUnitAt(qi);

    // Skip spaces again.
    if (qc == 0x20) {
      if (qi < query.length - 1) bw[qi] = bw[qi + 1];
      continue;
    }

    final bound = (qi < query.length - 1) ? bw[qi + 1] : text.length;
    // Tighten as far right as we can, but stay left of `bound` so
    // later (actually "earlier" in reverse) chars still have room.
    ti = ti.clamp(0, bound - 1);
    while (ti >= 0 && text.codeUnitAt(ti) != qc) {
      ti--;
    }
    if (ti < 0) {
      // This shouldn't happen after a successful forward pass, but
      // guard just in case.
      return fw; // fall back to forward positions
    }
    bw[qi] = ti;
    ti--;
  }

  // Filter out positions for spaces (which we skipped).
  final result = <int>[];
  for (int qi = 0; qi < query.length; qi++) {
    if (query.codeUnitAt(qi) != 0x20) {
      result.add(bw[qi]);
    }
  }
  result.sort();
  return result;
}
