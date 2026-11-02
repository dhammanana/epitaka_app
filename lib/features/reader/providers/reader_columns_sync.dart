import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/paragraph_number_index.dart';
import 'reader_columns_controller.dart';
import 'reader_tabs_provider.dart';

/// Keeps locked columns at matching paragraphs while the user scrolls one.
///
/// Acts when a column's reading paragraph changes, not per pixel. Any move
/// leads, the user's scrolling and app jumps alike (contents, find,
/// read-aloud), except two: a column's first place after its list mounts,
/// and a column scrolling after this class moved it. A moved column whose
/// short target paragraph leaves the next section on top would otherwise
/// pull the column that led back to that section.
class ReaderColumnsSync {
  ReaderColumnsSync({
    required this.ref,
    required this.isMounted,
    required this.shownColumns,
    required this.scrollTo,
  });

  final WidgetRef ref;
  final bool Function() isMounted;
  final List<String> Function() shownColumns;

  /// Scrolls [bookId]'s column to [paraId]; completes when it has arrived.
  final Future<void> Function(String bookId, int paraId) scrollTo;

  /// The reading paragraph each column last reported.
  final Map<String, int> _reading = {};

  /// Columns sync is scrolling, with the paragraph each is heading to.
  final Map<String, int> _moving = {};

  /// Bumped for every move of a column, so the end of an older scroll does
  /// not release a column a newer scroll is still moving.
  final Map<String, int> _moveTokens = {};

  /// The latest target for a column that was still moving. A new scroll is
  /// never started over a running one: scrollable_positioned_list then runs
  /// the old scroll's ending after the new one has begun and cancels it
  /// halfway (0.3.8, `_scrollTo` and `_startScroll`).
  final Map<String, int> _queued = {};

  /// Loads the paragraph numbers and links the columns will match with.
  void preload(List<String> columns) {
    for (final source in columns) {
      ref.read(paragraphNumberIndexProvider(source).future).ignore();
      for (final target in columns) {
        if (target == source) continue;
        ref
            .read(
              paragraphLinksProvider((
                sourceBookId: source,
                targetBookId: target,
              )).future,
            )
            .ignore();
      }
    }
  }

  /// A column's list is mounting: its next position is a start, not a move.
  void forget(String bookId) {
    _reading.remove(bookId);
    _moving.remove(bookId);
    _queued.remove(bookId);
    _moveTokens[bookId] = (_moveTokens[bookId] ?? 0) + 1;
  }

  void onPositions(String bookId) {
    final columns = shownColumns();
    if (!columns.contains(bookId)) return;
    final reading = ref
        .read(readerColumnsControllerProvider)
        .readingParaId(bookId);
    if (reading == null) return;
    final previous = _reading[bookId];
    if (reading == previous) return;
    _reading[bookId] = reading;
    if (previous == null || _moving.containsKey(bookId)) return;
    _follow(bookId, reading, columns);
  }

  void _follow(String sourceId, int sourcePara, List<String> columns) {
    final tabs = ref.read(readerTabsProvider);
    final source = ref.read(paragraphNumberIndexProvider(sourceId)).valueOrNull;
    if (source == null) return;
    final from = columns.indexOf(sourceId);
    for (final step in const [-1, 1]) {
      for (var i = from + step; i >= 0 && i < columns.length; i += step) {
        // The split line between column i and the one nearer the source.
        if (!tabs.isSplitLocked(step < 0 ? i : i - 1)) break;
        _move(sourceId, sourcePara, source, columns[i]);
      }
    }
  }

  void _move(
    String sourceId,
    int sourcePara,
    ParagraphNumberIndex source,
    String targetId,
  ) {
    final target = ref.read(paragraphNumberIndexProvider(targetId)).valueOrNull;
    if (target == null) return;
    final links =
        ref
            .read(
              paragraphLinksProvider((
                sourceBookId: sourceId,
                targetBookId: targetId,
              )),
            )
            .valueOrNull ??
        const <ParagraphLink>[];
    final para = matchParagraph(source, sourcePara, target, links: links);
    if (para == null) return;
    final heading = _moving[targetId];
    if (heading != null) {
      if (heading == para) {
        _queued.remove(targetId);
      } else {
        _queued[targetId] = para;
      }
      return;
    }
    // A column already reading inside the matched paragraph's section stays,
    // so scrolling through one sutta keeps its commentary still.
    final current = ref
        .read(readerColumnsControllerProvider)
        .readingParaId(targetId);
    if (current != null && target.numberFor(current)?.paraId == para) return;
    _scroll(targetId, para);
  }

  void _scroll(String targetId, int para) {
    final token = (_moveTokens[targetId] ?? 0) + 1;
    _moveTokens[targetId] = token;
    _moving[targetId] = para;
    scrollTo(targetId, para).catchError((Object _) {}).whenComplete(() {
      // The scroll's last frame lays out after it completes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_moveTokens[targetId] != token || !isMounted()) return;
        final next = _queued.remove(targetId);
        if (next != null) {
          _scroll(targetId, next);
          return;
        }
        _moving.remove(targetId);
        final reading = ref
            .read(readerColumnsControllerProvider)
            .readingParaId(targetId);
        if (reading != null) _reading[targetId] = reading;
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }
}
