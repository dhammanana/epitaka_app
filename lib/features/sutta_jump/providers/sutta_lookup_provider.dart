import 'dart:developer' as developer;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../services/sutta_code_service.dart';

/// The code cells shipped in `assets/sutta_code_cells.tsv`, read once. Null
/// when the asset cannot be read, which leaves the database's own codes in use.
final suttaCodeCellsProvider = FutureProvider<SuttaCodeCells?>((ref) async {
  try {
    return SuttaCodeCells.parse(
      await rootBundle.loadString('assets/sutta_code_cells.tsv'),
    );
  } catch (e) {
    developer.log(
      '[GO TO SUTTA] Code cells could not be read: $e',
      name: 'epitaka.sutta_jump',
    );
    return null;
  }
});

/// The codes-only headings lookup that a link and the "Open in ePitaka" row
/// resolve against. Auto-disposing, so the rows leave memory once the open is
/// done.
final suttaLookupProvider = FutureProvider.autoDispose<SuttaLookupCache>((
  ref,
) async {
  final db = await ref.watch(epitakaDbProvider.future);
  final cells = await ref.watch(suttaCodeCellsProvider.future);
  return loadSuttaCodeLookup(db, cells: cells);
});
