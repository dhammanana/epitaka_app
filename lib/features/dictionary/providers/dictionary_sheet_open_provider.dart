import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Counts how many modal sheets are currently open on top of the reader.
///
/// Set by the dictionary sheet and the book-link section sheet — the two
/// sheets that can appear while the reader is on screen. Each open sheet
/// increments the counter and decrements it on close, so nested sheets
/// (e.g. the book-link sheet opening the dictionary sheet from within) keep
/// the reader guarded until the *last* sheet closes.
///
/// The reader screen watches this so it can exclude its (very deep)
/// [ScrollablePositionedList] semantics subtree from collection and skip
/// position-writes/re-layout while a sheet is open. Collecting the reader's
/// huge tree at the same time as the sheet's own semantics triggers
/// re-entrant [flushSemantics] and the framework's
/// '!semantics.parentDataDirty' / '!conflict' assertions, and the extra
/// layout work makes scrolling the sheet janky.
final dictionarySheetOpenProvider = StateProvider<int>((ref) => 0);
