import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/nissaya_database.dart';
import '../../../core/models/translation_version.dart';
import '../../../core/providers/database_provider.dart';

/// Provider that returns the nissaya database for a given version.
final nissayaDbProvider =
    FutureProvider.family<NissayaDatabase?, TranslationVersion>(
        (ref, version) async {
  if (!version.isNissaya || !version.isAvailable) return null;
  return ref.watch(nissayaDbByFilenameProvider(version.filename).future);
});

/// Provider that returns nissaya sentences for a given (bookId, paraId).
final nissayaSentencesProvider = FutureProvider.family<
    List<NissayaSentenceLine>,
    ({
      String bookId,
      int paraId,
      TranslationVersion version
    })>((ref, params) async {
  final db = await ref.watch(nissayaDbProvider(params.version).future);
  if (db == null) return [];

  try {
    return await db.getSentences(params.bookId, params.paraId);
  } catch (_) {
    return [];
  }
});
