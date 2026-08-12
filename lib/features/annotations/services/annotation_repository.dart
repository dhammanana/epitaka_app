// lib/features/annotations/services/annotation_repository.dart
//
// Local-first persistence for annotations. Every mutation:
//   1. writes to the local Drift DB immediately (offline-first, instant UI),
//   2. stamps `dirty = true` + a fresh `updatedAt`,
//   3. hands the changed row to a [SyncSink] so the caller can push it to
//      Supabase in the background without the repository knowing about the
//      network.
//
// The repository never blocks on the network — sync is fire-and-forget.

import 'dart:developer' as developer;

import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../models/annotation.dart';

/// Receives rows that changed locally and should be pushed to the cloud.
/// The sync service registers itself; tests can substitute a no-op.
typedef SyncSink = void Function(Annotation annotation);

class AnnotationRepository {
  final AppDatabase _db;
  final Uuid _uuid;

  /// Set by the sync service (or a test) once to receive local mutations.
  SyncSink? onLocalMutation;

  AnnotationRepository(this._db) : _uuid = const Uuid();

  /// Create a brand-new annotation locally. The id is a client-generated
  /// UUID so the same id exists on every device (idempotent upserts).
  Future<Annotation> create({
    required AnnotationType type,
    required String bookId,
    String? bookName,
    int? paraId,
    int? lineId,
    String? segment,
    String? langCode,
    int? startOffset,
    int? endOffset,
    String? exactText,
    String? prefixText,
    String? suffixText,
    HighlightColor? color,
    String? note,
    String? name,
    String? pageNumber,
  }) async {
    final now = DateTime.now();
    final annotation = Annotation(
      id: _uuid.v4(),
      type: type,
      bookId: bookId,
      bookName: bookName,
      paraId: paraId,
      lineId: lineId,
      segment: segment,
      langCode: langCode,
      startOffset: startOffset,
      endOffset: endOffset,
      exactText: exactText,
      prefixText: prefixText,
      suffixText: suffixText,
      color: color,
      note: note,
      name: name,
      pageNumber: pageNumber,
      createdAt: now,
      updatedAt: now,
      dirty: true,
    );
    final exact = exactText ?? '';
    developer.log(
      '[ANNOT] repo.create: type=${type.wire} bookId=$bookId '
      'para=$paraId line=$lineId seg=${segment ?? '-'}/${langCode ?? '-'} '
      'off=[$startOffset,$endOffset] '
      'exact="${exact.length > 50 ? exact.substring(0, 50) : exact}" '
      'color=${color?.wire ?? '-'} hasNote=${note != null}',
      name: 'epitaka.annotations',
    );
    await _db.upsertAnnotation(annotation.toDrift());
    _notify(annotation);
    developer.log(
      '[ANNOT] repo.create OK id=${annotation.id} dirty=${annotation.dirty}',
      name: 'epitaka.annotations',
    );
    return annotation;
  }

  /// Update an existing annotation (color change, note edit, rename…).
  Future<void> update(Annotation annotation) async {
    final updated = annotation.copyWith(
      updatedAt: DateTime.now(),
      dirty: true,
    );
    await _db.upsertAnnotation(updated.toDrift());
    _notify(updated);
  }

  /// Soft-delete: the tombstone propagates through sync so every device
  /// removes the annotation without a resurrection race.
  Future<void> delete(String id) async {
    await _db.softDeleteAnnotation(id);
    final row = await _db.getAnnotation(id);
    if (row != null) {
      _notify(Annotation.fromDrift(row));
    }
  }

  /// Apply a server row locally. Used by pull + realtime merge. Respects
  /// last-write-wins: a local row that is *dirty* (unsynced local edit) wins
  /// over an older server update, and vice versa. Returns true when the local
  /// DB changed.
  Future<bool> applyServerAnnotation(Annotation remote) async {
    final local = await _db.getAnnotation(remote.id);
    if (local == null) {
      await _db.upsertAnnotation(remote.toDrift());
      return true;
    }
    // Local unsynced change → keep it (it will be pushed).
    if (local.dirty && local.updatedAt.isAfter(remote.updatedAt)) {
      return false;
    }
    // Remote is newer or equal → take the server version.
    if (!remote.updatedAt.isBefore(local.updatedAt)) {
      final merged = remote.copyWith(serverUpdatedAt: remote.updatedAt);
      await _db.upsertAnnotation(merged.toDrift());
      return true;
    }
    return false;
  }

  /// The server hard-deleted a row (realtime DELETE). Remove it locally
  /// WITHOUT marking it dirty — otherwise the next push would upsert a
  /// tombstone back and resurrect the row on the server.
  Future<void> applyServerDelete(String id) async {
    await _db.hardDeleteAnnotation(id);
  }

  Future<List<Annotation>> annotationsForBook(String bookId) async {
    final rows = await _db.getVisibleAnnotationsForBook(bookId);
    return rows.map(Annotation.fromDrift).toList();
  }

  Stream<List<Annotation>> watchAnnotationsForBook(String bookId) {
    return _db.watchVisibleAnnotationsForBook(bookId).map(
      (rows) => rows.map(Annotation.fromDrift).toList(),
    );
  }

  /// Watch (live) all visible annotations across every book, most recently
  /// updated first (global annotations screen).
  Stream<List<Annotation>> watchAllAnnotations() {
    return _db.watchAllVisibleAnnotations().map(
      (rows) => rows.map(Annotation.fromDrift).toList(),
    );
  }

  Future<List<Annotation>> allAnnotations() async {
    final rows = await _db.getAllAnnotations();
    return rows.map(Annotation.fromDrift).toList();
  }

  Future<List<Annotation>> dirtyAnnotations() async {
    final rows = await _db.getDirtyAnnotations();
    return rows.map(Annotation.fromDrift).toList();
  }

  Future<void> markSynced(String id, {DateTime? serverUpdatedAt}) {
    return _db.markAnnotationSynced(id, serverUpdatedAt: serverUpdatedAt);
  }

  Future<void> purgeTombstones(DateTime before) {
    return _db.purgeAnnotationTombstones(before);
  }

  void _notify(Annotation annotation) {
    developer.log(
      '[ANNOT] local mutation ${annotation.type.wire} id=${annotation.id}',
      name: 'epitaka.annotations',
    );
    onLocalMutation?.call(annotation);
  }
}
