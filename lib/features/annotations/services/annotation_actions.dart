// lib/features/annotations/services/annotation_actions.dart
//
// User-facing actions that create annotations from the current reader
// selection. Kept OUT of reader_screen.dart so the screen stays thin:
//
//   showHighlightPalette(context, ref, …)  — selection toolbar "Highlight"
//   showNoteEditor(context, ref, …)        — selection toolbar "Note"
//
// Both resolve the selection into anchors via [SelectionAnchorBuilder], then
// persist through the local-first repository (sync happens in the
// background via the sync service).

import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/app_localizations.dart';
import '../../reader/providers/reader_provider.dart';
import '../models/annotation.dart';
import '../providers/annotations_provider.dart';
import '../widgets/highlight_palette.dart';
import '../widgets/note_editor_sheet.dart';
import 'selection_anchor_builder.dart';

class AnnotationActions {
  AnnotationActions._();

  /// Resolve the current selection into anchor(s). Returns an empty list when
  /// the selection can't be matched to paragraph text.
  static List<SelectionAnchor> resolveSelection({
    required WidgetRef ref,
    required String bookId,
    required SelectedContent? selection,
    required int visibleStartIndex,
    required int visibleEndIndex,
  }) {
    final plainText = selection?.plainText.trim() ?? '';
    if (plainText.isEmpty) return const [];

    final readerState = ref.read(readerDataProvider(bookId));
    if (readerState.paragraphs.isEmpty) return const [];

    final settings = ref.read(settingsProvider);
    final enabledLangs = settings.enabledTranslations.isNotEmpty
        ? settings.enabledTranslations.toSet()
        : <String>{};

    try {
      return SelectionAnchorBuilder.buildAnchors(
        paragraphs: readerState.paragraphs,
        plainText: plainText,
        script: settings.paliScript,
        enabledLangCodes: enabledLangs,
        visibleStartIndex: visibleStartIndex,
        visibleEndIndex: visibleEndIndex,
      );
    } catch (e) {
      // A failure here used to crash highlight/note creation silently (no
      // palette, no editor, nothing saved). Surface it as a "no anchor"
      // snackbar instead so the user at least sees feedback and we can
      // diagnose from the log.
      developer.log(
        '[ANNOT] anchor resolution failed: $e',
        name: 'epitaka.annotations',
      );
      return const [];
    }
  }

  /// Show the highlight color palette. Picking a color creates a highlight
  /// anchored to the current selection.
  static Future<void> showHighlightPalette({
    required BuildContext context,
    required WidgetRef ref,
    required String bookId,
    required String bookName,
    required SelectedContent? selection,
    required int visibleStartIndex,
    required int visibleEndIndex,
    required Offset anchor,
  }) async {
    final anchors = resolveSelection(
      ref: ref,
      bookId: bookId,
      selection: selection,
      visibleStartIndex: visibleStartIndex,
      visibleEndIndex: visibleEndIndex,
    );
    developer.log(
      '[ANNOT] highlight flow: resolved ${anchors.length} anchors'
      '${anchors.isEmpty ? '' : ' first=[para=${anchors.first.paraId} line=${anchors.first.lineId} seg=${anchors.first.segment}/${anchors.first.langCode} off=[${anchors.first.startOffset},${anchors.first.endOffset}] exact="${anchors.first.exactText}"]'}',
      name: 'epitaka.annotations',
    );
    if (anchors.isEmpty) {
      _showNoAnchorSnack(context);
      return;
    }

    // Capture the messenger + strings while the context is still mounted:
    // the selection toolbar is disposed as soon as the palette opens
    // (clearSelection), so by the time the user picks a color
    // context.mounted is false and ScaffoldMessenger.of(context) would
    // throw. Using the captured messenger keeps save feedback working.
    final messenger = ScaffoldMessenger.of(context);
    final loc = AppLocalizations.of(context);

    final color = await showHighlightColorPalette(
      context,
      anchor: anchor,
      // If the whole selection is already one color, pre-select it.
      initialColor: _selectionColor(anchors, ref, bookId),
    );
    developer.log(
      '[ANNOT] highlight flow: palette closed color=$color '
      'mounted=${context.mounted}',
      name: 'epitaka.annotations',
    );
    // NOTE: do NOT gate the save on context.mounted. This context belongs
    // to the selection toolbar, which is disposed the moment the selection
    // is cleared (right after the palette opens), so mounted is false by
    // the time the user picks a color — gating here made every highlight
    // silently disappear on Android. The save only needs `ref`, which stays
    // valid; the snackbar below is still guarded separately.
    if (color == null) return;

    final ok = await _createFromAnchors(
      ref: ref,
      bookId: bookId,
      bookName: bookName,
      anchors: anchors,
      color: color,
    );
    developer.log(
      '[ANNOT] highlight flow: save ok=$ok anchors=${anchors.length}',
      name: 'epitaka.annotations',
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? loc.highlightAdded : loc.failedToSave('')),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show the markdown note editor for the current selection. Saving creates
  /// a highlight (with the chosen color) carrying the note.
  static Future<void> showNoteEditor({
    required BuildContext context,
    required WidgetRef ref,
    required String bookId,
    required String bookName,
    required SelectedContent? selection,
    required int visibleStartIndex,
    required int visibleEndIndex,
    String? existingNote,
    String? annotationId,
  }) async {
    final anchors = existingNote != null
        ? const <SelectionAnchor>[]
        : resolveSelection(
            ref: ref,
            bookId: bookId,
            selection: selection,
            visibleStartIndex: visibleStartIndex,
            visibleEndIndex: visibleEndIndex,
          );

    if (existingNote == null && anchors.isEmpty) {
      _showNoAnchorSnack(context);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final loc = AppLocalizations.of(context);

    final result = await showNoteEditorSheet(
      context,
      initialNote: existingNote ?? '',
    );
    // Same rule as the highlight flow: do not gate on context.mounted — the
    // selection-toolbar context is disposed while the sheet is open, so the
    // save would be skipped every time on Android. `ref` stays valid.
    if (result == null) return;

    if (annotationId != null) {
      // Editing an existing annotation's note.
      final repo = await ref.read(annotationRepositoryProvider.future);
      final current = await _findAnnotation(ref, annotationId);
      if (current == null) return;
      try {
        await repo.update(
          current.copyWith(
            note: result.note,
            color: result.color,
            type: AnnotationType.note,
          ),
        );
      } catch (e) {
        developer.log('[ANNOT] note update failed: $e', name: 'epitaka.annotations');
        _showSaveFailedSnack(context);
      }
      return;
    }

    developer.log(
      '[ANNOT] note flow: creating from ${anchors.length} anchors '
      'color=${result.color} noteLen=${result.note.length}',
      name: 'epitaka.annotations',
    );
    final ok = await _createFromAnchors(
      ref: ref,
      bookId: bookId,
      bookName: bookName,
      anchors: anchors,
      color: result.color,
      note: result.note,
      type: AnnotationType.note,
    );
    developer.log(
      '[ANNOT] note flow: save ok=$ok anchors=${anchors.length}',
      name: 'epitaka.annotations',
    );
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(loc.failedToSave('')),
          duration: const Duration(milliseconds: 1600),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Create annotations from resolved anchors. Multiple anchors (selection
  /// spanning several lines) create one annotation per anchor. Returns
  /// false when any save failed (the caller surfaces it to the user).
  static Future<bool> _createFromAnchors({
    required WidgetRef ref,
    required String bookId,
    required String bookName,
    required List<SelectionAnchor> anchors,
    HighlightColor color = HighlightColor.yellow,
    String? note,
    AnnotationType type = AnnotationType.highlight,
  }) async {
    try {
      final repo = await ref.read(annotationRepositoryProvider.future);
      for (final anchor in anchors) {
        developer.log(
          '[ANNOT] createFromAnchors: type=${type.wire} bookId=$bookId '
          'para=${anchor.paraId} line=${anchor.lineId} '
          'seg=${anchor.segment}/${anchor.langCode} '
          'off=[${anchor.startOffset},${anchor.endOffset}] '
          'exact="${anchor.exactText}" color=${color.wire} '
          'hasNote=${note != null}',
          name: 'epitaka.annotations',
        );
        await repo.create(
          type: type,
          bookId: bookId,
          bookName: bookName,
          paraId: anchor.paraId,
          lineId: anchor.lineId,
          segment: anchor.segment,
          langCode: anchor.langCode,
          startOffset: anchor.startOffset,
          endOffset: anchor.endOffset,
          exactText: anchor.exactText,
          prefixText: anchor.prefixText,
          suffixText: anchor.suffixText,
          color: color,
          note: note,
        );
      }
      return true;
    } catch (e, st) {
      developer.log(
        '[ANNOT] save failed: $e\n$st',
        name: 'epitaka.annotations',
      );
      return false;
    }
  }

  static void _showSaveFailedSnack(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).failedToSave('')),
        duration: const Duration(milliseconds: 1600),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// If the whole selection is covered by a single highlight color, return
  /// it (used to pre-select the palette).
  static HighlightColor? _selectionColor(
    List<SelectionAnchor> anchors,
    WidgetRef ref,
    String bookId,
  ) {
    if (anchors.isEmpty) return null;
    final annotations = ref.read(paragraphAnnotationsProvider(bookId));
    HighlightColor? first;
    for (final anchor in anchors) {
      final list = annotations[anchor.paraId] ?? const [];
      final match = list.where(
        (a) =>
            a.lineId == anchor.lineId &&
            a.segment == anchor.segment &&
            a.langCode == anchor.langCode &&
            a.startOffset == anchor.startOffset &&
            a.endOffset == anchor.endOffset &&
            a.color != null,
      );
      if (match.isEmpty) return null;
      final c = match.first.color;
      if (first == null) {
        first = c;
      } else if (first != c) {
        return null;
      }
    }
    return first;
  }

  static Future<Annotation?> _findAnnotation(WidgetRef ref, String id) async {
    final repo = await ref.read(annotationRepositoryProvider.future);
    final all = await repo.allAnnotations();
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  static void _showNoAnchorSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).annotationNoAnchor),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
