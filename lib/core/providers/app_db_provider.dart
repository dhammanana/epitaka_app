import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../../features/annotations/models/annotation.dart';

/// Provider for the app database (bookmarks, reading history).
final appDbProvider = FutureProvider<AppDatabase>((ref) async {
  final db = await AppDatabase.open();
  return db;
});

/// Provider that fetches all bookmarks.
///
/// Bookmarks live in the unified `annotations` table (type = 'bookmark') so
/// they sync to Supabase alongside highlights and notes. The legacy
/// `bookmarks` Drift table still exists for migration data but is no longer
/// written to.
final bookmarksProvider = FutureProvider<List<Annotation>>((ref) async {
  final db = await ref.watch(appDbProvider.future);
  final rows = await db.getAllAnnotations();
  return rows
      .where((a) => a.type == 'bookmark' && a.deletedAt == null)
      .map(Annotation.fromDrift)
      .toList();
});

/// Provider that fetches reading history.
final historyProvider = FutureProvider<List<ReadingHistoryData>>((ref) async {
  final db = await ref.watch(appDbProvider.future);
  return db.getAllHistory();
});

/// Provider that fetches listening history (books played with TTS).
final listeningHistoryProvider =
    FutureProvider<List<ListeningHistoryData>>((ref) async {
  final db = await ref.watch(appDbProvider.future);
  return db.getAllListeningHistory();
});
