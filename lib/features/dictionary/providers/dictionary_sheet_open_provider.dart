import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether the dictionary bottom sheet is currently open.
///
/// The reader screen watches this so it can exclude its (very deep)
/// [ScrollablePositionedList] semantics subtree from collection while the
/// modal sheet is open. Collecting the reader's huge tree at the same time as
/// the sheet's own semantics triggers re-entrant [flushSemantics] and the
/// framework's '!semantics.parentDataDirty' / '!conflict' assertions.
final dictionarySheetOpenProvider = StateProvider<bool>((ref) => false);
