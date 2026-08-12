// lib/features/annotations/providers/annotations_provider.dart
//
// Riverpod wiring for the annotations feature.
//
//   authProvider            — sign-in state (Google OAuth).
//   annotationRepositoryProvider — local-first repository (singleton).
//   annotationSyncProvider  — sync service: debounced push of local
//                             mutations, pull + realtime on sign-in, and the
//                             hook SyncLifecycleObserver calls to catch up
//                             on app resume.
//   annotationsProvider(bookId)  — live list of visible annotations for a book.
//   paragraphAnnotationsProvider(bookId) — same list grouped by paragraph id
//                                          (consumed by the reader).
//
// Sync lifecycle: on sign-in the sync service pulls + merges, subscribes to
// realtime, and pushes pending local rows. SyncLifecycleObserver (app.dart)
// triggers another pull when the app returns to the foreground, because
// realtime can miss events while the OS suspends the network in the
// background. Everything runs in the background and is fully optional — all
// annotation features work offline.

import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../../core/providers/app_db_provider.dart';
import '../models/annotation.dart';
import '../services/annotation_repository.dart';
import '../services/annotation_sync_service.dart';
import '../services/auth_service.dart';

/// The auth service singleton (available without Riverpod too, but exposing
/// it as a provider keeps `ref.read` idiomatic).
final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService.instance,
);

/// Live auth state. Not autoDispose: settings/reader panels read it at will.
final authProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

/// Current signed-in user (null when signed out). Convenience for widgets
/// that just need the user object.
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).valueOrNull?.user;
});

/// Singleton local-first repository, built once per app run once the local
/// database is available. UI code reads this directly to create/update/
/// delete annotations — the repository writes to Drift instantly and hands
/// changed rows to the sync service via [AnnotationRepository.onLocalMutation].
final annotationRepositoryProvider = FutureProvider<AnnotationRepository>((
  ref,
) async {
  final db = await ref.watch(appDbProvider.future);
  return AnnotationRepository(db);
});

/// Singleton sync service + background orchestration:
///   • wires local mutations into a debounced push,
///   • on sign-in pulls + merges and subscribes to realtime,
///   • on sign-out tears the realtime channel down.
/// SyncLifecycleObserver keeps this provider alive for the whole app run and
/// calls [AnnotationSyncService.pullAndMerge] whenever the app returns to the
/// foreground, so changes made elsewhere (Supabase dashboard, another device)
/// always show up even if realtime events were missed while backgrounded.
final annotationSyncProvider = FutureProvider<AnnotationSyncService>((
  ref,
) async {
  final repository = await ref.watch(annotationRepositoryProvider.future);
  final sync = AnnotationSyncService(repository);
  sync.start();

  ref.listen(authProvider, (prev, next) {
    next.whenData((state) {
      if (state.isSignedIn) {
        developer.log(
          '[SYNC] signed in — pulling + subscribing',
          name: 'epitaka.sync',
        );
        sync.pullAndMerge();
        sync.subscribeRealtime();
      } else {
        sync.dispose();
        sync.start();
      }
    });
  });

  ref.onDispose(() {
    sync.dispose();
  });

  return sync;
});

/// Live visible annotations for a book, newest first.
final annotationsProvider = StreamProvider.family<List<Annotation>, String>((
  ref,
  bookId,
) async* {
  final repo = await ref.watch(annotationRepositoryProvider.future);
  await for (final list in repo.watchAnnotationsForBook(bookId)) {
    developer.log(
      '[PANEL] ${list.length} visible annotations for bookId=$bookId '
      'types=[${list.map((a) => a.type.wire).join(',')}]',
      name: 'epitaka.annotations',
    );
    yield list;
  }
});

/// Live visible annotations across ALL books, most recently updated first
/// (global annotations screen). Watches the unified table so highlights,
/// notes and bookmarks all appear as they change.
final allAnnotationsProvider = StreamProvider<List<Annotation>>((ref) async* {
  final repo = await ref.watch(annotationRepositoryProvider.future);
  await for (final list in repo.watchAllAnnotations()) {
    yield list;
  }
});

/// Annotations grouped by paragraph id, for the reader's paragraph list.
final paragraphAnnotationsProvider =
    Provider.family<Map<int, List<Annotation>>, String>((ref, bookId) {
      final annotations =
          ref.watch(annotationsProvider(bookId)).valueOrNull ?? [];
      final map = <int, List<Annotation>>{};
      for (final a in annotations) {
        final paraId = a.paraId;
        if (paraId == null) continue;
        (map[paraId] ??= []).add(a);
      }
      return map;
    });
