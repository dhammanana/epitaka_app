// lib/features/reader/widgets/translation_remark_dialog.dart
//
// The full translation-remark editor. The old remark dialog only showed the
// free-text note; this one displays EVERY field a `translation_remarks` row
// carries (Pāli, translation, conflict, note, source, created) in a card per
// remark, lets the user edit them, add a new remark, delete a row, and save
// everything back into the translation database.

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/utils/app_localizations.dart';
import '../../translator/services/translator_engine.dart' show ensureTranslatorTables;
import '../providers/reader_provider.dart' show TranslationRemark, readerDataProvider;

/// Open the translation remark editor for one line.
///
/// [initialRemarks] carries the rows the reader already loaded (avoiding a
/// second query); when omitted (e.g. opened from the context menu) the dialog
/// loads them from the translation DB itself.
Future<void> showTranslationRemarkDialog(
  BuildContext context, {
  required String bookId,
  required String langCode,
  required int paraId,
  required int lineId,
  List<TranslationRemark>? initialRemarks,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => TranslationRemarkDialog(
      bookId: bookId,
      langCode: langCode,
      paraId: paraId,
      lineId: lineId,
      initialRemarks: initialRemarks,
    ),
  );
}

class TranslationRemarkDialog extends ConsumerStatefulWidget {
  final String bookId;
  final String langCode;
  final int paraId;
  final int lineId;
  final List<TranslationRemark>? initialRemarks;

  const TranslationRemarkDialog({
    super.key,
    required this.bookId,
    required this.langCode,
    required this.paraId,
    required this.lineId,
    this.initialRemarks,
  });

  @override
  ConsumerState<TranslationRemarkDialog> createState() =>
      _TranslationRemarkDialogState();
}

/// One editable remark row in the dialog.
class _RemarkRow {
  int? id;
  final TextEditingController pali;
  final TextEditingController translation;
  final TextEditingController conflict;
  final TextEditingController note;
  final String? sourceId;
  final String? createdAt;
  bool deleted;

  _RemarkRow({
    this.id,
    required String pali,
    required String translation,
    required String conflict,
    required String note,
    this.sourceId,
    this.createdAt,
  })  : deleted = false,
        pali = TextEditingController(text: pali),
        translation = TextEditingController(text: translation),
        conflict = TextEditingController(text: conflict),
        note = TextEditingController(text: note);

  void dispose() {
    pali.dispose();
    translation.dispose();
    conflict.dispose();
    note.dispose();
  }

  bool get hasContent =>
      pali.text.trim().isNotEmpty ||
      translation.text.trim().isNotEmpty ||
      conflict.text.trim().isNotEmpty ||
      note.text.trim().isNotEmpty;
}

class _TranslationRemarkDialogState extends ConsumerState<TranslationRemarkDialog> {
  List<_RemarkRow> _rows = [];
  bool _loading = true;
  bool _dbMissing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rows = (widget.initialRemarks ?? const [])
        .map(
          (r) => _RemarkRow(
            id: r.id,
            pali: r.pali,
            translation: r.translation,
            conflict: r.conflict,
            note: r.note,
            sourceId: r.sourceId,
            createdAt: r.createdAt,
          ),
        )
        .toList();
    _loading = widget.initialRemarks == null;
    if (_loading) _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    final db = await ref.read(translationDbProvider(widget.langCode).future);
    if (db == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _dbMissing = true;
        });
      }
      return;
    }
    try {
      final rows = await db.customSelect(
        'SELECT id, para_id, line_id, pali, translation, conflict, '
        'note, source_id, created_at FROM translation_remarks '
        'WHERE book_id = ? AND para_id = ? AND line_id = ?',
        variables: [
          Variable.withString(widget.bookId),
          Variable.withInt(widget.paraId),
          Variable.withInt(widget.lineId),
        ],
      ).get();
      if (!mounted) return;
      setState(() {
        _rows = rows.map((r) {
          return _RemarkRow(
            id: r.data['id'] as int?,
            pali: (r.data['pali'] as String?) ?? '',
            translation: (r.data['translation'] as String?) ?? '',
            conflict: (r.data['conflict'] as String?) ?? '',
            note: (r.data['note'] as String?) ?? '',
            sourceId: r.data['source_id'] as String?,
            createdAt: r.data['created_at'] as String?,
          );
        }).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _dbMissing = true;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _rows.add(
        _RemarkRow(pali: '', translation: '', conflict: '', note: ''),
      );
    });
  }

  void _deleteRow(int index) {
    final row = _rows[index];
    setState(() {
      if (row.id != null) {
        row.deleted = true; // mark for DELETE on save
      } else {
        _rows.removeAt(index);
      }
    });
  }

  Future<void> _save() async {
    final db = await ref.read(translationDbProvider(widget.langCode).future);
    if (db == null) {
      _showSnack(_dbMissingText());
      return;
    }
    setState(() => _saving = true);
    try {
      await ensureTranslatorTables(db);
      for (final row in _rows) {
        if (row.deleted) {
          if (row.id != null) {
            await db.customUpdate(
              'DELETE FROM translation_remarks WHERE id = ?',
              variables: [Variable.withInt(row.id!)],
            );
          }
          continue;
        }
        if (row.id != null) {
          await db.customUpdate(
            'UPDATE translation_remarks SET pali = ?, translation = ?, '
            'conflict = ?, note = ? WHERE id = ?',
            variables: [
              Variable.withString(row.pali.text.trim()),
              Variable.withString(row.translation.text.trim()),
              Variable.withString(row.conflict.text.trim()),
              Variable.withString(row.note.text.trim()),
              Variable.withInt(row.id!),
            ],
          );
        } else if (row.hasContent) {
          await db.customInsert(
            'INSERT INTO translation_remarks '
            '(book_id, para_id, line_id, pali, translation, conflict, '
            'note, source_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            variables: [
              Variable.withString(widget.bookId),
              Variable.withInt(widget.paraId),
              Variable.withInt(widget.lineId),
              Variable.withString(row.pali.text.trim()),
              Variable.withString(row.translation.text.trim()),
              Variable.withString(row.conflict.text.trim()),
              Variable.withString(row.note.text.trim()),
              Variable.withString('user'),
            ],
          );
        }
      }

      // Refresh the reader's in-memory remarks for this language.
      ref
          .read(readerDataProvider(widget.bookId).notifier)
          .refreshRemarks(widget.langCode);
      ref.invalidate(translationDbProvider(widget.langCode));

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showSnack('${AppLocalizations.of(context).error}: $e');
      }
    }
  }

  String _dbMissingText() {
    final loc = AppLocalizations.of(context);
    return '${loc.translationRemark}: ${loc.noTranslationDatabases}';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 8, 0),
      title: Row(
        children: [
          Icon(Icons.rate_review_outlined, size: 20, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              loc.translationRemark,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => Navigator.of(context).pop(),
            color: colors.onSurfaceVariant,
            tooltip: loc.close,
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Line context + language chip.
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(
                    '${loc.paragraph} ${widget.paraId} · ${loc.line} ${widget.lineId}',
                    style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: colors.surfaceContainerHighest,
                ),
                Chip(
                  label: Text(
                    widget.langCode.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: colors.primaryContainer,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_dbMissing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _dbMissingText(),
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              )
            else ...[
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (var i = 0; i < _rows.length; i++)
                        if (!_rows[i].deleted) ...[
                          _RemarkCard(
                            row: _rows[i],
                            colors: colors,
                            loc: loc,
                            onDelete: () => _deleteRow(i),
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add, size: 18),
                label: Text(loc.addRemark),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(loc.cancel),
        ),
        FilledButton(
          onPressed: _saving || _dbMissing ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(loc.save),
        ),
      ],
    );
  }
}

/// One remark row as a card of editable fields + metadata.
class _RemarkCard extends StatelessWidget {
  final _RemarkRow row;
  final ColorScheme colors;
  final AppLocalizations loc;
  final VoidCallback onDelete;

  const _RemarkCard({
    required this.row,
    required this.colors,
    required this.loc,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final metaBits = <String>[
      if (row.sourceId != null && row.sourceId!.isNotEmpty) row.sourceId!,
      if (row.createdAt != null && row.createdAt!.isNotEmpty) row.createdAt!,
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(
              label: loc.pali,
              controller: row.pali,
              colors: colors,
              maxLines: 1,
            ),
            _field(
              label: loc.translationWord,
              controller: row.translation,
              colors: colors,
              maxLines: 1,
            ),
            _field(
              label: loc.conflict,
              controller: row.conflict,
              colors: colors,
              maxLines: 3,
            ),
            _field(
              label: loc.note,
              controller: row.note,
              colors: colors,
              maxLines: 4,
            ),
            if (metaBits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 2, top: 2),
                child: Text(
                  metaBits,
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required ColorScheme colors,
    required int maxLines,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: 1,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        style: TextStyle(fontSize: 13, color: colors.onSurface),
      ),
    );
  }
}
