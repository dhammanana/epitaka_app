import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';

/// What an annotation represents.
enum AnnotationType {
  /// A colored text highlight.
  highlight,

  /// A markdown note anchored to a text range (renders like a highlight,
  /// with an icon marker when it carries a body).
  note,

  /// A saved reading position (legacy bookmarks are migrated here).
  bookmark;

  /// Stable string used in the DB and on the wire.
  String get wire => name;

  static AnnotationType fromWire(String? value) {
    return AnnotationType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => AnnotationType.highlight,
    );
  }
}

/// A highlight color key. Keys are stored (not raw ARGB values) so the app
/// can resolve them against either light or dark themes and future palettes
/// can be extended without data migration.
enum HighlightColor {
  yellow,
  green,
  blue,
  pink,
  purple,
  orange,
  red,
  teal,
  indigo,
  cyan,
  lime,
  brown,
  amber,
  deepPurple;

  String get wire => name;

  static HighlightColor fromWire(String? value) {
    return HighlightColor.values.firstWhere(
      (c) => c.name == value,
      orElse: () => HighlightColor.yellow,
    );
  }

  /// The short palette shown inline next to a selection (quick access).
  /// Every other color is reachable through the picker ("More colors").
  static const List<HighlightColor> quick = [
    HighlightColor.yellow,
    HighlightColor.green,
    HighlightColor.blue,
    HighlightColor.pink,
    HighlightColor.purple,
    HighlightColor.orange,
  ];

  /// A color that reads well as a translucent background in both themes.
  Color color(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    switch (this) {
      case HighlightColor.yellow:
        return dark ? const Color(0x66776B00) : const Color(0x55FFEB3B);
      case HighlightColor.green:
        return dark ? const Color(0x664C7A34) : const Color(0x554CAF50);
      case HighlightColor.blue:
        return dark ? const Color(0x663B6FB0) : const Color(0x552196F3);
      case HighlightColor.pink:
        return dark ? const Color(0x66A63D6C) : const Color(0x55EC407A);
      case HighlightColor.purple:
        return dark ? const Color(0x66744FA8) : const Color(0x559C27B0);
      case HighlightColor.orange:
        return dark ? const Color(0x6680551D) : const Color(0x55FF9800);
      case HighlightColor.red:
        return dark ? const Color(0x66B71C1C) : const Color(0x55F44336);
      case HighlightColor.teal:
        return dark ? const Color(0x66004D40) : const Color(0x55009688);
      case HighlightColor.indigo:
        return dark ? const Color(0x66303F9F) : const Color(0x553F51B5);
      case HighlightColor.cyan:
        return dark ? const Color(0x6600838F) : const Color(0x5500BCD4);
      case HighlightColor.lime:
        return dark ? const Color(0x66827717) : const Color(0x55CDDC39);
      case HighlightColor.brown:
        return dark ? const Color(0x664E342E) : const Color(0x55795548);
      case HighlightColor.amber:
        return dark ? const Color(0x66A67C00) : const Color(0x55FFB300);
      case HighlightColor.deepPurple:
        return dark ? const Color(0x664A148C) : const Color(0x55673AB7);
    }
  }

  /// Solid swatch shown in the palette / panel (independent of text bg).
  Color get swatch {
    switch (this) {
      case HighlightColor.yellow:
        return const Color(0xFFFFEB3B);
      case HighlightColor.green:
        return const Color(0xFF4CAF50);
      case HighlightColor.blue:
        return const Color(0xFF2196F3);
      case HighlightColor.pink:
        return const Color(0xFFEC407A);
      case HighlightColor.purple:
        return const Color(0xFF9C27B0);
      case HighlightColor.orange:
        return const Color(0xFFFF9800);
      case HighlightColor.red:
        return const Color(0xFFF44336);
      case HighlightColor.teal:
        return const Color(0xFF009688);
      case HighlightColor.indigo:
        return const Color(0xFF3F51B5);
      case HighlightColor.cyan:
        return const Color(0xFF00BCD4);
      case HighlightColor.lime:
        return const Color(0xFFCDDC39);
      case HighlightColor.brown:
        return const Color(0xFF795548);
      case HighlightColor.amber:
        return const Color(0xFFFFB300);
      case HighlightColor.deepPurple:
        return const Color(0xFF673AB7);
    }
  }
}

/// A client-side annotation. Mirrors the `annotations` Drift table so it can
/// be persisted locally, pushed to Supabase, and reconstructed from either.
class Annotation {
  final String id;
  final AnnotationType type;
  final String bookId;
  final String? bookName;
  final int? paraId;
  final int? lineId;

  /// 'pali' | 'translation' | null for bookmarks.
  final String? segment;
  final String? langCode;

  /// Character offsets in the segment's stripped text (structural anchor).
  final int? startOffset;
  final int? endOffset;

  /// Text-quote selector for re-anchoring (robust across script/font
  /// changes): the exact selected text + surrounding context.
  final String? exactText;
  final String? prefixText;
  final String? suffixText;

  final HighlightColor? color;
  final String? note;

  /// Bookmark-only fields.
  final String? name;
  final String? pageNumber;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool dirty;
  final DateTime? serverUpdatedAt;

  const Annotation({
    required this.id,
    required this.type,
    required this.bookId,
    this.bookName,
    this.paraId,
    this.lineId,
    this.segment,
    this.langCode,
    this.startOffset,
    this.endOffset,
    this.exactText,
    this.prefixText,
    this.suffixText,
    this.color,
    this.note,
    this.name,
    this.pageNumber,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.dirty = false,
    this.serverUpdatedAt,
  });

  bool get isDeleted => deletedAt != null;
  bool get isBookmark => type == AnnotationType.bookmark;
  bool get isHighlight => type == AnnotationType.highlight;
  bool get hasNote =>
      type == AnnotationType.note || (note != null && note!.trim().isNotEmpty);

  /// A short display label (bookmark name, note preview, or quote text).
  String displayLabel() {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    if (note != null && note!.trim().isNotEmpty) {
      final lines = note!.trim().split('\n').where((l) => l.trim().isNotEmpty);
      final first = lines.isEmpty ? '' : lines.first.trim();
      return first.length > 60 ? '${first.substring(0, 60)}…' : first;
    }
    if (exactText != null && exactText!.trim().isNotEmpty) {
      final t = exactText!.trim();
      return t.length > 60 ? '${t.substring(0, 60)}…' : t;
    }
    return bookId;
  }

  Annotation copyWith({
    AnnotationType? type,
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
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeleted = false,
    bool? dirty,
    DateTime? serverUpdatedAt,
  }) {
    return Annotation(
      id: id,
      type: type ?? this.type,
      bookId: bookId,
      bookName: bookName ?? this.bookName,
      paraId: paraId ?? this.paraId,
      lineId: lineId ?? this.lineId,
      segment: segment ?? this.segment,
      langCode: langCode ?? this.langCode,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      exactText: exactText ?? this.exactText,
      prefixText: prefixText ?? this.prefixText,
      suffixText: suffixText ?? this.suffixText,
      color: color ?? this.color,
      note: note ?? this.note,
      name: name ?? this.name,
      pageNumber: pageNumber ?? this.pageNumber,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeleted ? null : (deletedAt ?? this.deletedAt),
      dirty: dirty ?? this.dirty,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
    );
  }

  /// Convert to the Drift row class for local persistence.
  AnnotationRow toDrift() {
    return AnnotationRow(
      id: id,
      type: type.wire,
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
      color: color?.wire,
      note: note,
      name: name,
      pageNumber: pageNumber,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      dirty: dirty,
      serverUpdatedAt: serverUpdatedAt,
    );
  }

  /// Build from a Drift row.
  factory Annotation.fromDrift(AnnotationRow row) {
    return Annotation(
      id: row.id,
      type: AnnotationType.fromWire(row.type),
      bookId: row.bookId,
      bookName: row.bookName,
      paraId: row.paraId,
      lineId: row.lineId,
      segment: row.segment,
      langCode: row.langCode,
      startOffset: row.startOffset,
      endOffset: row.endOffset,
      exactText: row.exactText,
      prefixText: row.prefixText,
      suffixText: row.suffixText,
      color: row.color != null ? HighlightColor.fromWire(row.color) : null,
      note: row.note,
      name: row.name,
      pageNumber: row.pageNumber,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      dirty: row.dirty,
      serverUpdatedAt: row.serverUpdatedAt,
    );
  }

  /// Supabase row → domain (server uses snake_case columns).
  factory Annotation.fromSupabase(Map<String, dynamic> row) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v.toUtc();
      return DateTime.tryParse(v.toString())?.toUtc();
    }

    return Annotation(
      id: row['id'] as String,
      type: AnnotationType.fromWire(row['type'] as String?),
      bookId: row['book_id'] as String? ?? '',
      bookName: row['book_name'] as String?,
      paraId: (row['para_id'] as num?)?.toInt(),
      lineId: (row['line_id'] as num?)?.toInt(),
      segment: row['segment'] as String?,
      langCode: row['lang_code'] as String?,
      startOffset: (row['start_offset'] as num?)?.toInt(),
      endOffset: (row['end_offset'] as num?)?.toInt(),
      exactText: row['exact_text'] as String?,
      prefixText: row['prefix_text'] as String?,
      suffixText: row['suffix_text'] as String?,
      color: row['color'] != null ? HighlightColor.fromWire(row['color'] as String) : null,
      note: row['note'] as String?,
      name: row['name'] as String?,
      pageNumber: row['page_number'] as String?,
      createdAt: parseTs(row['created_at']) ?? DateTime.now().toUtc(),
      updatedAt: parseTs(row['updated_at']) ?? DateTime.now().toUtc(),
      deletedAt: parseTs(row['deleted_at']),
      serverUpdatedAt: parseTs(row['updated_at']),
    );
  }

  /// Domain → Supabase row (snake_case columns). [userId] is supplied by the
  /// sync service at upload time (RLS requires auth.uid() = user_id).
  Map<String, dynamic> toSupabase({String? userId}) {
    return {
      'id': id,
      'user_id': ?userId,
      'type': type.wire,
      'book_id': bookId,
      'book_name': bookName,
      'para_id': paraId,
      'line_id': lineId,
      'segment': segment,
      'lang_code': langCode,
      'start_offset': startOffset,
      'end_offset': endOffset,
      'exact_text': exactText,
      'prefix_text': prefixText,
      'suffix_text': suffixText,
      'color': color?.wire,
      'note': note,
      'name': name,
      'page_number': pageNumber,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  /// Build a companion for Drift upserts (reusing the domain instance).
  AnnotationsCompanion toCompanion() {
    return AnnotationsCompanion(
      id: Value(id),
      type: Value(type.wire),
      bookId: Value(bookId),
      bookName: Value(bookName),
      paraId: Value(paraId),
      lineId: Value(lineId),
      segment: Value(segment),
      langCode: Value(langCode),
      startOffset: Value(startOffset),
      endOffset: Value(endOffset),
      exactText: Value(exactText),
      prefixText: Value(prefixText),
      suffixText: Value(suffixText),
      color: Value(color?.wire),
      note: Value(note),
      name: Value(name),
      pageNumber: Value(pageNumber),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: Value(deletedAt),
      dirty: Value(dirty),
      serverUpdatedAt: Value(serverUpdatedAt),
    );
  }
}
