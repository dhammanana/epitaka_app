/// A fixed-size binary min-heap that keeps the top-K scored items.
///
/// When the heap is full and a new item has a score higher than the
/// smallest (root), the root is replaced and sifted down.  This gives
/// O(n log K) overall, which is essentially linear for small K.
///
/// The heap is a MIN-heap by score, so the smallest score is at the root
/// and can be evicted quickly.  Items are sorted score-descending on
/// extraction.
library;

import 'result.dart';

/// Fixed-size min-heap for tracking the top-K [ScoredMatch] items.
class TopKHeap {
  final int _k;
  final List<ScoredMatch> _heap;

  /// Build a heap that keeps at most [k] items.
  TopKHeap(int k)
      : _k = k,
        _heap = [];

  /// Current number of items in the heap.
  int get size => _heap.length;

  /// Try to insert a scored match.
  ///
  /// Returns true if the item was accepted (heap was not yet full or
  /// the item outscored the current worst).
  bool add(ScoredMatch match) {
    if (_heap.length < _k) {
      _heap.add(match);
      _siftUp(_heap.length - 1);
      return true;
    }

    // Full — replace root only if the new score is higher.
    if (match.score <= _heap[0].score) return false;

    _heap[0] = match;
    _siftDown(0);
    return true;
  }

  /// Extract all items in descending score order.
  ///
  /// Ties are broken by the original candidate index, so equal-scoring
  /// candidates keep their insertion order (Dart's `List.sort` is not
  /// stable on its own).
  List<ScoredMatch> toSortedList() {
    final result = List<ScoredMatch>.from(_heap);
    result.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.index.compareTo(b.index);
    });
    return result;
  }

  // ── Heap internals ──────────────────────────────────────────────────

  void _siftUp(int i) {
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_heap[i].score >= _heap[parent].score) break;
      _swap(i, parent);
      i = parent;
    }
  }

  void _siftDown(int i) {
    while (true) {
      int smallest = i;
      final left = (i << 1) + 1;
      final right = left + 1;

      if (left < _heap.length && _heap[left].score < _heap[smallest].score) {
        smallest = left;
      }
      if (right < _heap.length && _heap[right].score < _heap[smallest].score) {
        smallest = right;
      }
      if (smallest == i) break;
      _swap(i, smallest);
      i = smallest;
    }
  }

  void _swap(int i, int j) {
    final tmp = _heap[i];
    _heap[i] = _heap[j];
    _heap[j] = tmp;
  }
}
