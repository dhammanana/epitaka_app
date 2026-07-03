import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Filter options for the library browser.
enum LibraryFilter {
  all('All'),
  mula('Mūla'),
  atthakatha('Aṭṭhakathā'),
  tika('Ṭīkā'),
  anna('Añña');

  final String label;
  const LibraryFilter(this.label);
}

/// Provider for the active library filter.
final libraryFilterProvider = StateProvider<LibraryFilter>((ref) {
  return LibraryFilter.all;
});
