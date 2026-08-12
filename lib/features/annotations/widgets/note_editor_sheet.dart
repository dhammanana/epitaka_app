// lib/features/annotations/widgets/note_editor_sheet.dart
//
// Markdown note editor shown when the user picks "Note" from the selection
// toolbar (or edits an existing annotation's note). Editing + live preview
// toggle; saving returns the note body + chosen highlight color.

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../core/utils/app_localizations.dart';
import '../models/annotation.dart';
import 'highlight_palette.dart' show HighlightColorPickerSwatch;

class NoteEditorResult {
  final String note;
  final HighlightColor color;

  const NoteEditorResult({required this.note, required this.color});
}

/// Show the note editor as a modal bottom sheet. Returns the result or null
/// when cancelled.
Future<NoteEditorResult?> showNoteEditorSheet(
  BuildContext context, {
  String initialNote = '',
  HighlightColor initialColor = HighlightColor.yellow,
}) {
  return showModalBottomSheet<NoteEditorResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _NoteEditorSheet(
      initialNote: initialNote,
      initialColor: initialColor,
    ),
  );
}

class _NoteEditorSheet extends StatefulWidget {
  final String initialNote;
  final HighlightColor initialColor;

  const _NoteEditorSheet({
    required this.initialNote,
    required this.initialColor,
  });

  @override
  State<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<_NoteEditorSheet> {
  late final TextEditingController _controller;
  HighlightColor _color = HighlightColor.yellow;
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
    _color = widget.initialColor;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final note = _controller.text.trim();
    if (note.isEmpty) {
      Navigator.of(context).pop(
        NoteEditorResult(note: '', color: _color),
      );
      return;
    }
    Navigator.of(context).pop(NoteEditorResult(note: note, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.notes, size: 20, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.addNote,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: loc.close,
                    icon: const Icon(Icons.close, size: 20),
                    color: colors.onSurfaceVariant,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Color row ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Text(
                    loc.highlightColor,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Quick palette — the full extended set lives behind the
                  // rainbow picker swatch at the end of the row.
                  for (final c in HighlightColor.quick) ...[
                    GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 26,
                        height: 26,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: c.swatch,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c == _color
                                ? colors.onSurface
                                : colors.outlineVariant,
                            width: c == _color ? 2.5 : 1,
                          ),
                        ),
                        child: c == _color
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.black87)
                            : null,
                      ),
                    ),
                  ],
                  HighlightColorPickerSwatch(
                    initialColor: _color,
                    size: 26,
                    onColorPicked: (c) => setState(() => _color = c),
                  ),
                  const SizedBox(width: 8),
                  const Spacer(),
                  // Edit / preview toggle
                  if (_controller.text.trim().isNotEmpty)
                    TextButton.icon(
                      onPressed: () => setState(() => _preview = !_preview),
                      icon: Icon(
                        _preview ? Icons.edit : Icons.visibility_outlined,
                        size: 16,
                      ),
                      label: Text(_preview ? loc.editNote : loc.previewNote),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.primary,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),

            // ── Editor / preview ───────────────────────────────────
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: _preview
                    ? Card(
                        elevation: 0,
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: MarkdownBody(
                            data: _controller.text.isEmpty
                                ? '_Empty_'
                                : _controller.text,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: colors.onSurface,
                              ),
                              listBullet: TextStyle(color: colors.primary),
                              blockquoteDecoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      )
                    : TextField(
                        controller: _controller,
                        autofocus: true,
                        maxLines: null,
                        minLines: 4,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: colors.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: loc.noteHint,
                          hintStyle: TextStyle(
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          filled: true,
                          fillColor: colors.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colors.primary),
                          ),
                        ),
                      ),
              ),
            ),

            // ── Footer ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Text(
                    loc.markdownSupported,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(loc.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(loc.save),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
