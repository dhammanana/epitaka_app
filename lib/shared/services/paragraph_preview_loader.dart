/// Shared loader for paragraph-excerpt previews.
///
/// Both the AI-citation quickview (Vīmaṃsā) and the outline section quickview
/// show a passage as Pāli + translation lines before the user commits to
/// opening the reader — this single loader keeps that logic in one place so
/// the two features never drift apart.
library;

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/translation_version.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../widgets/preview_content.dart';

/// Excerpt data for one paragraph (or a range of paragraphs).
class ParagraphPreviewData {
  /// Nearest heading title at or before the start paragraph.
  final String headingTitle;

  /// Pāli + translation lines, in document order.
  final List<PreviewLineData> lines;

  /// The translation language whose lines were loaded (null = Pāli only).
  final String? activeLang;

  const ParagraphPreviewData({
    this.headingTitle = '',
    this.lines = const [],
    this.activeLang,
  });
}

/// Loads the excerpt (Pāli + translation lines) for the paragraph range
/// `[paraId, paraEnd]` (inclusive) from the local databases, plus the
/// nearest heading title — the shared loader behind both the AI-citation
/// quickview and the outline section quickview.
///
/// When [targetParaId]/[targetLineId] identify the jump target inside the
/// loaded range, the rows are trimmed to a line window around it (at most
/// [maxLinesBefore] lines before and [maxLinesAfter] lines after it), so a
/// huge paragraph never floods the sheet. When either side then holds fewer
/// than [minSideLines] lines, [extraLines] neighbour lines are loaded beyond
/// the range on that side, so a 1-line paragraph still shows context.
Future<ParagraphPreviewData> loadParagraphPreview(
  WidgetRef ref, {
  required String bookId,
  required int paraId,
  int? paraEnd,
  int? titleParaId,
  int? targetParaId,
  int? targetLineId,
  int maxLinesBefore = 20,
  int maxLinesAfter = 30,
  int minSideLines = 5,
  int extraLines = 10,
}) async {
  final epitakaDb = await ref.read(epitakaDbProvider.future);
  final settings = ref.read(settingsProvider);
  final activeLang = settings.enabledTranslations.isNotEmpty
      ? settings.enabledTranslations.first
      : (settings.showTranslation ? settings.primaryTranslationLang : null);

  final end = paraEnd ?? paraId;

  final headingTitle =
      (await epitakaDb.getHeadingTitleAtPara(
        bookId,
        titleParaId ?? paraId,
        includeLevel10: true,
      )) ??
      '';

  var sentenceRows = await epitakaDb
      .customSelect(
        'SELECT para_id, line_id, pali FROM sentences '
        'WHERE book_id = ? AND para_id >= ? AND para_id <= ? '
        'ORDER BY para_id, line_id',
        variables: [
          Variable.withString(bookId),
          Variable.withInt(paraId),
          Variable.withInt(end),
        ],
      )
      .get();

  // ── Line window around the jump target ─────────────────────────────
  // Trim over-long sides to the cap, then extend under-filled sides with
  // neighbour lines from outside the paragraph range.
  // Only window around an explicit jump target (citation quickview). Other
  // callers (e.g. outline sections) load their full range untouched.
  final hasTarget = targetParaId != null || targetLineId != null;
  final anchorPara = targetParaId ?? paraId;
  var anchorIdx = -1;
  if (hasTarget && sentenceRows.isNotEmpty) {
    if (targetLineId != null) {
      anchorIdx = sentenceRows.indexWhere(
        (r) =>
            r.data['para_id'] == anchorPara &&
            r.data['line_id'] == targetLineId,
      );
    } else {
      anchorIdx = sentenceRows.indexWhere(
        (r) => r.data['para_id'] == anchorPara,
      );
    }
  }
  if (anchorIdx >= 0) {
    var start = anchorIdx - maxLinesBefore;
    if (start < 0) start = 0;
    var stop = anchorIdx + 1 + maxLinesAfter;
    if (stop > sentenceRows.length) stop = sentenceRows.length;
    sentenceRows = sentenceRows.sublist(start, stop);
    anchorIdx -= start;

    if (anchorIdx < minSideLines && extraLines > 0) {
      final first = sentenceRows.first.data;
      final extraBefore = await epitakaDb
          .customSelect(
            'SELECT para_id, line_id, pali FROM sentences '
            'WHERE book_id = ? AND (para_id < ? OR (para_id = ? AND line_id < ?)) '
            'ORDER BY para_id DESC, line_id DESC LIMIT ?',
            variables: [
              Variable.withString(bookId),
              Variable.withInt(first['para_id'] as int),
              Variable.withInt(first['para_id'] as int),
              Variable.withInt(first['line_id'] as int),
              Variable.withInt(extraLines),
            ],
          )
          .get();
      if (extraBefore.isNotEmpty) {
        sentenceRows = [...extraBefore.reversed, ...sentenceRows];
        anchorIdx += extraBefore.length;
      }
    }
    if (sentenceRows.length - anchorIdx - 1 < minSideLines && extraLines > 0) {
      final last = sentenceRows.last.data;
      final extraAfter = await epitakaDb
          .customSelect(
            'SELECT para_id, line_id, pali FROM sentences '
            'WHERE book_id = ? AND (para_id > ? OR (para_id = ? AND line_id > ?)) '
            'ORDER BY para_id, line_id LIMIT ?',
            variables: [
              Variable.withString(bookId),
              Variable.withInt(last['para_id'] as int),
              Variable.withInt(last['para_id'] as int),
              Variable.withInt(last['line_id'] as int),
              Variable.withInt(extraLines),
            ],
          )
          .get();
      if (extraAfter.isNotEmpty) {
        sentenceRows = [...sentenceRows, ...extraAfter];
      }
    }
  }

  // Scope translations to the paragraphs actually shown (the window may
  // have been trimmed or extended beyond [paraId, end] above).
  var paraMin = paraId;
  var paraMax = end;
  if (sentenceRows.isNotEmpty) {
    paraMin = sentenceRows.first.data['para_id'] as int;
    paraMax = paraMin;
    for (final r in sentenceRows) {
      final p = r.data['para_id'] as int;
      if (p < paraMin) paraMin = p;
      if (p > paraMax) paraMax = p;
    }
  }

  final translationMap = <String, Map<String, String>>{};
  if (activeLang != null) {
    try {
      if (TranslationFilenameParser.isNissaya(activeLang)) {
        final filename = TranslationFilenameParser.build(activeLang);
        final nissayaDb = await ref.read(
          nissayaDbByFilenameProvider(filename).future,
        );
        if (nissayaDb != null) {
          for (int p = paraMin; p <= paraMax; p++) {
            final sentences = await nissayaDb.getSentences(bookId, p);
            for (final s in sentences) {
              final key = '${s.paraId}:${s.lineId}';
              final formatted = s.formattedText;
              if (formatted.isNotEmpty) {
                translationMap.putIfAbsent(key, () => {})[activeLang] =
                    formatted;
              }
            }
          }
        }
      } else {
        final transDb = await ref.read(
          translationDbProvider(activeLang).future,
        );
        if (transDb != null) {
          final transRows = await transDb
              .customSelect(
                'SELECT para_id, line_id, translation FROM sentences '
                'WHERE book_id = ? AND para_id >= ? AND para_id <= ? '
                'ORDER BY para_id, line_id',
                variables: [
                  Variable.withString(bookId),
                  Variable.withInt(paraMin),
                  Variable.withInt(paraMax),
                ],
              )
              .get();
          for (final row in transRows) {
            final key = '${row.data['para_id']}:${row.data['line_id']}';
            final t = row.data['translation'] as String?;
            if (t != null && t.isNotEmpty) {
              translationMap.putIfAbsent(key, () => {})[activeLang] = t;
            }
          }
        }
      }
    } catch (_) {
      // A broken translation DB must not break the preview.
    }
  }

  final previewLines = sentenceRows.map((r) {
    final key = '${r.data['para_id']}:${r.data['line_id']}';
    return PreviewLineData(
      paraId: r.data['para_id'] as int,
      lineId: r.data['line_id'] as int,
      pali: r.data['pali'] as String? ?? '',
      translations: translationMap[key] ?? {},
    );
  }).toList();

  return ParagraphPreviewData(
    headingTitle: headingTitle,
    lines: previewLines,
    activeLang: activeLang,
  );
}
