/// Shared loader for paragraph-excerpt previews.
///
/// Both the AI-citation quickview (vimaṃsa) and the outline section quickview
/// show a passage as Pāli + translation lines before the user commits to
/// opening the reader — this single loader keeps that logic in one place so
/// the two features never drift apart.
library;

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
Future<ParagraphPreviewData> loadParagraphPreview(
  WidgetRef ref, {
  required String bookId,
  required int paraId,
  int? paraEnd,
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
            paraId,
            includeLevel10: true,
          )) ??
      '';

  final sentenceRows = await epitakaDb
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

  final translationMap = <String, Map<String, String>>{};
  if (activeLang != null) {
    try {
      final transDb = await ref.read(translationDbProvider(activeLang).future);
      if (transDb != null) {
        final transRows = await transDb
            .customSelect(
              'SELECT para_id, line_id, translation FROM sentences '
              'WHERE book_id = ? AND para_id >= ? AND para_id <= ? '
              'ORDER BY para_id, line_id',
              variables: [
                Variable.withString(bookId),
                Variable.withInt(paraId),
                Variable.withInt(end),
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
