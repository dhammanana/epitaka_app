import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/root_matrix_builder.dart';
import 'dpd_database_provider.dart';

/// Every compound-family key, to decide which headwords get the button.
final compoundFamilyKeysProvider = FutureProvider<Set<String>>((ref) async {
  final dao = await ref.watch(dpdDaoProvider.future);
  return dao.getAllCompoundFamilyKeys();
});

/// Every idiom key, to decide which headwords get the button.
final idiomKeysProvider = FutureProvider<Set<String>>((ref) async {
  final dao = await ref.watch(dpdDaoProvider.future);
  return dao.getAllIdiomKeys();
});

final basesForRootProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, rootKey) async {
      final dao = await ref.watch(dpdDaoProvider.future);
      return dao.getBasesForRoot(rootKey);
    });

final rootMatrixProvider = FutureProvider.autoDispose
    .family<RootMatrixData, String>((ref, rootKey) async {
      final dao = await ref.watch(dpdDaoProvider.future);
      return buildRootMatrix(await dao.getHeadwordsForRootMatrix(rootKey));
    });
