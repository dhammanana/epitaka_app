// lib/features/annotations/services/annotation_sync_service.dart
//
// Bidirectional sync between the local Drift store and Supabase.
//
//   • Push — dirty local rows are upserted (id is a client UUID, so upserts
//     are idempotent). Soft-deleted tombstones are upserted too, so other
//     devices learn about deletions; old tombstones are purged afterwards.
//   • Pull — on sign-in the user's full annotation set is fetched and merged
//     with last-write-wins on `updated_at`.
//   • Realtime — a `postgres_changes` subscription streams remote mutations
//     to other devices and applies the same LWW merge.
//
// All network calls are guarded: when Supabase isn't available (init failed,
// signed out) they no-op so sync can never crash the app.

import 'dart:async';
import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../models/annotation.dart';
import 'annotation_repository.dart';

class AnnotationSyncService {
  final AnnotationRepository _repository;

  RealtimeChannel? _realtimeSub;
  bool _pushing = false;

  /// Guards against overlapping pulls (auth listener + app-resume observer
  /// can both fire around startup). Merges are idempotent, but a concurrent
  /// fetch would double the network load for no benefit.
  bool _pullInFlight = false;

  AnnotationSyncService(this._repository);

  bool get _available {
    try {
      Supabase.instance.client.auth.currentUser;
      return true;
    } catch (_) {
      return false;
    }
  }

  String? get _userId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// Wire the repository's local mutations straight into a debounced push.
  void start() {
    _repository.onLocalMutation = (_) => _schedulePush();
    developer.log('[SYNC] Sync service started', name: 'epitaka.sync');
  }

  void dispose() {
    _repository.onLocalMutation = null;
    _debounce?.cancel();
    _debounce = null;
    _realtimeSub?.unsubscribe();
    _realtimeSub = null;
  }

  // ── Push ──────────────────────────────────────────────────────────────

  Timer? _debounce;
  void _schedulePush() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () => push());
  }

  /// Upload every dirty local row. Called on a debounce after mutations and
  /// once after sign-in. Never throws.
  Future<void> push() async {
    if (!_available || _pushing) return;
    final userId = _userId;
    if (userId == null) return;
    _pushing = true;
    try {
      final dirty = await _repository.dirtyAnnotations();
      if (dirty.isEmpty) return;

      final client = Supabase.instance.client;
      for (final annotation in dirty) {
        try {
          final payload = annotation.toSupabase(userId: userId);
          await client
              .from(SupabaseConfig.annotationsTable)
              .upsert(payload, onConflict: 'id');
          await _repository.markSynced(
            annotation.id,
            serverUpdatedAt: annotation.updatedAt,
          );
        } catch (e) {
          developer.log(
            '[SYNC] push failed for ${annotation.id}: $e',
            name: 'epitaka.sync',
          );
        }
      }

      // Drop tombstones older than a week now that they've propagated.
      await _repository.purgeTombstones(
        DateTime.now().toUtc().subtract(const Duration(days: 7)),
      );
    } catch (e) {
      developer.log('[SYNC] push error: $e', name: 'epitaka.sync');
    } finally {
      _pushing = false;
    }
  }

  // ── Pull ──────────────────────────────────────────────────────────────

  /// Fetch the user's full annotation set and LWW-merge it locally, then
  /// push anything local that's newer. Called on sign-in / app foreground.
  Future<void> pullAndMerge() async {
    if (!_available || _pullInFlight) return;
    final userId = _userId;
    if (userId == null) return;
    _pullInFlight = true;
    try {
      final rows = await Supabase.instance.client
          .from(SupabaseConfig.annotationsTable)
          .select()
          .eq('user_id', userId)
          .order('updated_at');
      final remote = <String, Annotation>{};
      for (final row in rows) {
        final a = Annotation.fromSupabase(row);
        if (a.id.isNotEmpty) remote[a.id] = a;
      }
      for (final remoteAnnotation in remote.values) {
        await _repository.applyServerAnnotation(remoteAnnotation);
      }
      await push();
      developer.log(
        '[SYNC] pull+merge complete: ${remote.length} remote rows',
        name: 'epitaka.sync',
      );
    } catch (e) {
      developer.log('[SYNC] pull error: $e', name: 'epitaka.sync');
    } finally {
      _pullInFlight = false;
    }
  }

  // ── Realtime ──────────────────────────────────────────────────────────

  /// Subscribe to remote changes. Newer remote rows are applied with LWW;
  /// when a row is deleted on the server we locally soft-delete it.
  void subscribeRealtime() {
    if (!_available || _realtimeSub != null) return;
    try {
      _realtimeSub = Supabase.instance.client
          .channel('annotations-sync')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: SupabaseConfig.annotationsTable,
            callback: (payload) => _onRealtime(payload),
          )
          .subscribe();
    } catch (e) {
      developer.log(
        '[SYNC] realtime subscribe failed: $e',
        name: 'epitaka.sync',
      );
    }
  }

  Future<void> _onRealtime(PostgresChangePayload payload) async {
    if (!_available) return;
    final userId = _userId;
    if (userId == null) return;
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.all:
        // The subscription uses .all; the actual event arrives with a
        // specific type (insert/update/delete), so this case is unreachable
        // in practice — treat it as an insert/update for safety.
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          final record = payload.newRecord;
          if (record['user_id'] != userId) return;
          final remote = Annotation.fromSupabase(record);
          if (remote.id.isEmpty) return;
          await _repository.applyServerAnnotation(remote);
        case PostgresChangeEvent.delete:
          final old = payload.oldRecord;
          final id = old['id'] as String?;
          if (id == null) return;
          // Server-side hard delete → remove locally WITHOUT marking dirty
          // (a tombstone here would be pushed back and resurrect the row).
          await _repository.applyServerDelete(id);
      }
    } catch (e) {
      developer.log('[SYNC] realtime apply failed: $e', name: 'epitaka.sync');
    }
  }
}
