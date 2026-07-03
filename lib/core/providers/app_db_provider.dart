import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';

/// Provider for the app database (bookmarks, reading history).
final appDbProvider = FutureProvider<AppDatabase>((ref) async {
  final db = await AppDatabase.open();
  return db;
});

/// Provider that fetches all bookmarks.
final bookmarksProvider = FutureProvider<List<Bookmark>>((ref) async {
  final db = await ref.watch(appDbProvider.future);
  return db.getAllBookmarks();
});

/// Provider that fetches reading history.
final historyProvider = FutureProvider<List<ReadingHistoryData>>((ref) async {
  final db = await ref.watch(appDbProvider.future);
  return db.getAllHistory();
});

