import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/pali_definition_provider.dart'
    show canonBookNamesProvider;
import '../services/book_family_service.dart';
import '../services/paragraph_number_index.dart';
import 'reader_keyboard_bridge.dart';
import 'reader_provider.dart';
import 'reader_tabs_provider.dart';

/// Opens and closes the mūla / aṭṭhakathā / ṭīkā columns.
///
/// The m a ṭ buttons and the right-click entry both call
/// [openFamilyColumn], so the two routes always change the same state.
class ReaderColumnsController {
  ReaderColumnsController(this._ref);

  final Ref _ref;

  /// Opens still loading their data, as `source>target`. A second press
  /// before the first finishes would otherwise open and close the column.
  final Set<String> _opening = {};

  /// The paragraph the reader is looking at in [bookId]: the first one that
  /// reaches below the top tenth of the view, or the tab's saved place.
  ///
  /// A jump puts its paragraph just below the top edge, so the paragraph
  /// touching the edge is usually the tail of the one before (AN 5.36 would
  /// open the commentary on sutta 35).
  int? readingParaId(String bookId) {
    final positions = _ref
        .read(readerKeyboardBridgeProvider)
        .positionsListenerFor(bookId)
        ?.itemPositions
        .value;
    final paragraphs = _ref.read(readerDataProvider(bookId)).paragraphs;
    final reading =
        positions?.where((p) => p.itemTrailingEdge > 0.1).toList() ?? [];
    if (reading.isEmpty || paragraphs.isEmpty) {
      return _ref
          .read(readerTabsProvider)
          .tabs
          .where((t) => t.bookId == bookId)
          .firstOrNull
          ?.currentParaId;
    }
    reading.sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
    final index = reading.first.index;
    return index < paragraphs.length ? paragraphs[index].paraId : null;
  }

  /// Shows [targetBookId] beside [sourceBookId] at the paragraph matching
  /// [sourceParaId] (default: [readingParaId]), or takes it out when it
  /// already shows there.
  Future<void> openFamilyColumn(
    String targetBookId, {
    required String sourceBookId,
    int? sourceParaId,
  }) async {
    final key = '$sourceBookId>$targetBookId';
    if (!_opening.add(key)) return;
    try {
      await _open(targetBookId, sourceBookId, sourceParaId);
    } finally {
      _opening.remove(key);
    }
  }

  Future<void> _open(
    String targetBookId,
    String sourceBookId,
    int? sourceParaId,
  ) async {
    final family = await _ref.read(bookFamilyProvider(sourceBookId).future);
    if (family == null) return;

    final columns = _ref.read(readerTabsProvider).columns;
    final closing =
        columns.contains(sourceBookId) && columns.contains(targetBookId);
    sourceParaId ??= readingParaId(sourceBookId);
    int? targetParaId;
    if (!closing && sourceParaId != null) {
      final source = await _ref.read(
        paragraphNumberIndexProvider(sourceBookId).future,
      );
      final target = await _ref.read(
        paragraphNumberIndexProvider(targetBookId).future,
      );
      final links = await _ref.read(
        paragraphLinksProvider((
          sourceBookId: sourceBookId,
          targetBookId: targetBookId,
        )).future,
      );
      targetParaId = matchParagraph(source, sourceParaId, target, links: links);
    }
    final names = await _ref.read(canonBookNamesProvider.future);

    _ref
        .read(readerTabsProvider.notifier)
        .toggleFamilyColumn(
          ReaderTabInfo(
            bookId: targetBookId,
            bookName: names[targetBookId] ?? targetBookId,
            initialParaId: targetParaId,
          ),
          sourceBookId: sourceBookId,
          family: family,
        );
  }
}

/// Whether the reader is wide enough to show columns (set by the reader
/// after each layout). The m a ṭ buttons hide while it is false.
final readerColumnsAvailableProvider = StateProvider<bool>((ref) => false);

final readerColumnsControllerProvider = Provider<ReaderColumnsController>(
  (ref) => ReaderColumnsController(ref),
);
