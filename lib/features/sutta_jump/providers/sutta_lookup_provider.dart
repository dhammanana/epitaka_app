import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../services/sutta_code_service.dart';

/// The codes-only headings lookup that a link and the "Open in ePitaka" row
/// resolve against. Auto-disposing, so the rows leave memory once the open is
/// done.
final suttaLookupProvider = FutureProvider.autoDispose<SuttaLookupCache>((
  ref,
) async {
  final db = await ref.watch(epitakaDbProvider.future);
  return loadSuttaCodeLookup(db);
});
