import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/dpd_database.dart';
import 'dpd_database_provider.dart';

/// Loads all inflection templates into memory keyed by pattern for O(1) lookup.
final templateCacheProvider =
    FutureProvider<Map<String, InflectionTemplate>>((ref) async {
      final dao = await ref.watch(dpdDaoProvider.future);
      final templates = await dao.getAllInflectionTemplates();
      return {for (final t in templates) t.pattern: t};
    });
