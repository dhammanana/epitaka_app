import 'dart:convert';
import 'dart:io' show File;

import 'package:clipboard/clipboard.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/translation_database.dart';
import '../../../core/models/translation_version.dart'
    show TranslationFilenameParser;
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/pali_script_converter.dart' show Script;
import '../../../core/utils/pali_text_utils.dart'
    show convertPaliToScriptPreservingHtml;
import '../../../shared/utils/reading_clipboard.dart';
import '../providers/reader_provider.dart';
import '../utils/reader_quote_utils.dart'
    show buildCitationFromTemplate, firstAvailablePageNumbers;
import 'jump_service.dart';

class _CopyLine {
  final int paraId;
  final int lineId;
  final String pali;
  final Map<String, String> translations;
  final Map<String, String> pageNumbers;

  const _CopyLine({
    required this.paraId,
    required this.lineId,
    this.pali = '',
    this.translations = const {},
    this.pageNumbers = const {},
  });
}

class _CopyPara {
  final int paraId;
  final String? headingTitle;
  final int? headingLevel;
  final List<_CopyLine> lines;
  final Map<String, String> pageNumbers;

  const _CopyPara({
    required this.paraId,
    this.headingTitle,
    this.headingLevel,
    this.lines = const [],
    this.pageNumbers = const {},
  });
}

class _CommentaryBlock {
  final String bookId;
  final String bookName;
  final String type;
  final String typeLabel;
  final String? headingTitle;
  final List<_CopyLine> lines;

  const _CommentaryBlock({
    required this.bookId,
    required this.bookName,
    required this.type,
    required this.typeLabel,
    this.headingTitle,
    this.lines = const [],
  });
}

/// What happened when writing copy output, so callers can tell the user
/// when Android's clipboard size limit forced a downgrade.
enum _CopyOutcome {
  /// Full styled (rich HTML) copy, or plain on platforms without rich
  /// support — nothing was stripped for size reasons.
  full,

  /// Too large for styled copy on Android — pasted as plain text instead.
  strippedToPlain,

  /// Too large even for plain clipboard on Android — sent to share instead.
  shared,
}

class SectionCopyService {
  SectionCopyService._();

  static const int _maxCommentarySections = 30;

  /// Rich copy sends plain text + HTML (~3-4x the plain bytes) in one
  /// platform-channel transaction. The Android binder limit (~1MB) silently
  /// truncates larger payloads mid-sentence, so rich copy is only used for
  /// small content; anything bigger goes as plain text.
  static const int _richCopyMaxChars = 50000;

  /// Above this plain-text size even a plain clipboard write risks binder
  /// truncation, so the content goes straight to the system share sheet
  /// (full text, user picks the target app) instead of the clipboard.
  static const int _plainCopyMaxChars = 300000;

  static ({int start, int endExclusive}) sectionRange(
    List<ParagraphData> paragraphs,
    ParagraphHeading heading,
  ) {
    final start = heading.paraId;
    final len = heading.chapterLen ?? 0;
    if (len > 0) return (start: start, endExclusive: start + len);
    var end = start + 1;
    var foundStart = false;
    for (final p in paragraphs) {
      if (p.paraId == start) {
        foundStart = true;
        continue;
      }
      if (!foundStart) continue;
      final h = p.heading;
      if (h != null && h.level <= heading.level) {
        end = p.paraId;
        break;
      }
      end = p.paraId + 1;
    }
    return (start: start, endExclusive: end);
  }

  static List<ParagraphData> sliceParagraphs(
    List<ParagraphData> paragraphs,
    int start,
    int endExclusive,
  ) {
    return paragraphs
        .where((p) => p.paraId >= start && p.paraId < endExclusive)
        .toList();
  }

  static Future<void> copySection({
    required WidgetRef ref,
    required BuildContext context,
    required String bookId,
    required ParagraphHeading heading,
    required CopyScope scope,
    required bool withCommentaries,
  }) async {
    if (context.mounted && withCommentaries) {
      _snack(context, 'Copying with commentaries…');
    }
    try {
      final db = await ref.read(epitakaDbProvider.future);
      final settings = ref.read(settingsProvider);
      final enabledLangs = settings.enabledTranslations.isNotEmpty
          ? settings.enabledTranslations.toList()
          : (settings.showTranslation
                ? [settings.primaryTranslationLang]
                : <String>[]);
      final script = settings.paliScript;

      final range = await _resolveRangeFromDb(db, bookId, heading);
      final bookName =
          await JumpService(db).getBookName(bookId) ??
          ref.read(readerDataProvider(bookId)).bookName ??
          bookId;
      final paras = await _fetchMainRange(
        ref,
        db,
        bookId,
        range.start,
        range.endExclusive,
        enabledLangs,
      );
      if (paras.isEmpty) {
        if (context.mounted) _snack(context, 'Nothing to copy');
        return;
      }

      final citation = buildCitationFromTemplate(
        settings.quoteTemplate,
        bookId,
        bookName,
        heading,
        _firstPages(paras),
        paraId: range.start,
      );
      Color paliColor;
      Color transColor;
      try {
        final brightness = Theme.of(context).brightness;
        paliColor = settings.paliColorPair.resolve(brightness);
        transColor = settings.translationColorPair.resolve(brightness);
      } catch (_) {
        paliColor = const Color(0xFF7A2E1D);
        transColor = const Color(0xFF33312E);
      }

      if (!withCommentaries) {
        final outcome = await _copyMain(
          bookId: bookId,
          bookName: bookName,
          mainHeading: heading,
          paras: paras,
          scope: scope,
          citation: citation,
          enabledLangs: enabledLangs.toSet(),
          script: script,
          paliColor: paliColor,
          transColor: transColor,
        );
        if (context.mounted) {
          _snack(context, _copiedMessage(outcome, 'Section'));
        }
        return;
      }

      final commentaries = await _fetchCommentariesFull(
        ref,
        db,
        bookId,
        range.start,
        range.endExclusive,
        enabledLangs,
      );
      if (!context.mounted) return;
      final outcome = await _copyWithCommentaries(
        bookId: bookId,
        bookName: bookName,
        mainHeading: heading,
        paras: paras,
        commentaries: commentaries,
        scope: scope,
        citation: citation,
        enabledLangs: enabledLangs.toSet(),
        script: script,
        paliColor: paliColor,
        transColor: transColor,
      );
      if (context.mounted) {
        _snack(
          context,
          _copiedMessage(
            outcome,
            commentaries.isEmpty
                ? 'Section (no commentaries found)'
                : 'Section (+ ${commentaries.length} commentaries)',
          ),
        );
      }
    } catch (_) {
      if (context.mounted) _snack(context, 'Copy failed');
    }
  }

  static Future<void> copyWholeBook({
    required WidgetRef ref,
    required BuildContext context,
    required String bookId,
    required CopyScope scope,
  }) async {
    if (context.mounted) _snack(context, 'Copying book…');
    try {
      final db = await ref.read(epitakaDbProvider.future);
      final settings = ref.read(settingsProvider);
      final enabledLangs = settings.enabledTranslations.isNotEmpty
          ? settings.enabledTranslations.toList()
          : (settings.showTranslation
                ? [settings.primaryTranslationLang]
                : <String>[]);
      final bookName =
          await JumpService(db).getBookName(bookId) ??
          ref.read(readerDataProvider(bookId)).bookName ??
          bookId;
      final paras = await _fetchMainRange(
        ref,
        db,
        bookId,
        null,
        null,
        enabledLangs,
      );
      if (paras.isEmpty) {
        if (context.mounted) _snack(context, 'Nothing to copy');
        return;
      }
      Color paliColor;
      Color transColor;
      try {
        final brightness = Theme.of(context).brightness;
        paliColor = settings.paliColorPair.resolve(brightness);
        transColor = settings.translationColorPair.resolve(brightness);
      } catch (_) {
        paliColor = const Color(0xFF7A2E1D);
        transColor = const Color(0xFF33312E);
      }
      final notifier = ref.read(readerDataProvider(bookId).notifier);
      ParagraphHeading? nearby;
      try {
        nearby = notifier.findNearbyHeading(paras.first.paraId);
      } catch (_) {
        nearby = null;
      }
      final citation = buildCitationFromTemplate(
        settings.quoteTemplate,
        bookId,
        bookName,
        nearby,
        _firstPages(paras),
        paraId: paras.first.paraId,
      );
      final outcome = await _copyMain(
        bookId: bookId,
        bookName: bookName,
        mainHeading: nearby,
        paras: paras,
        scope: scope,
        citation: citation,
        enabledLangs: enabledLangs.toSet(),
        script: settings.paliScript,
        paliColor: paliColor,
        transColor: transColor,
      );
      if (context.mounted) {
        _snack(context, _copiedMessage(outcome, 'Book'));
      }
    } catch (_) {
      if (context.mounted) _snack(context, 'Copy failed');
    }
  }

  static Future<({int start, int endExclusive})> _resolveRangeFromDb(
    dynamic db,
    String bookId,
    ParagraphHeading heading,
  ) async {
    final start = heading.paraId;
    try {
      final rows = await db
          .customSelect(
            'SELECT chapter_len FROM headings '
            'WHERE book_id = ? AND para_id = ? LIMIT 1',
            variables: [Variable.withString(bookId), Variable.withInt(start)],
          )
          .get();
      if (rows.isNotEmpty) {
        final len = rows.first.data['chapter_len'] as int?;
        if (len != null && len > 0) {
          return (start: start, endExclusive: start + len);
        }
      }
    } catch (_) {}
    try {
      final rows = await db
          .customSelect(
            'SELECT para_id FROM headings '
            'WHERE book_id = ? AND para_id > ? AND level <= ? AND level < 10 '
            'ORDER BY para_id ASC LIMIT 1',
            variables: [
              Variable.withString(bookId),
              Variable.withInt(start),
              Variable.withInt(heading.level),
            ],
          )
          .get();
      if (rows.isNotEmpty) {
        return (start: start, endExclusive: rows.first.data['para_id'] as int);
      }
    } catch (_) {}
    try {
      final rows = await db
          .customSelect(
            'SELECT MAX(para_id) AS m FROM sentences WHERE book_id = ?',
            variables: [Variable.withString(bookId)],
          )
          .get();
      if (rows.isNotEmpty && rows.first.data['m'] != null) {
        return (start: start, endExclusive: (rows.first.data['m'] as int) + 1);
      }
    } catch (_) {}
    return (start: start, endExclusive: start + 1000000);
  }

  static Future<List<_CopyPara>> _fetchMainRange(
    WidgetRef ref,
    dynamic db,
    String bookId,
    int? start,
    int? endExclusive,
    List<String> enabledLangs,
  ) async {
    final hasRange = start != null && endExclusive != null;
    final rangeSql = hasRange ? 'AND para_id >= ? AND para_id < ?' : '';
    final List<Variable> rangeVars = [];
    if (start != null && endExclusive != null) {
      rangeVars.add(Variable.withInt(start));
      rangeVars.add(Variable.withInt(endExclusive));
    }

    final sentenceRows = await db
        .customSelect(
          'SELECT para_id, line_id, pali, vripage, ptspage, thaipage, mypage '
          'FROM sentences WHERE book_id = ? $rangeSql '
          'ORDER BY para_id, line_id',
          variables: [Variable.withString(bookId), ...rangeVars],
        )
        .get();
    if (sentenceRows.isEmpty) return [];

    var headingRows = <dynamic>[];
    try {
      headingRows = await db
          .customSelect(
            'SELECT para_id, title, level FROM headings '
            'WHERE book_id = ? $rangeSql AND level < 10 '
            'ORDER BY para_id ASC',
            variables: [Variable.withString(bookId), ...rangeVars],
          )
          .get();
    } catch (_) {}
    final headingByPara = <int, Map<String, Object?>>{};
    for (final r in headingRows) {
      headingByPara[r.data['para_id'] as int] = r.data;
    }

    final transByLang = <String, Map<int, Map<int, String>>>{};
    for (final lang in enabledLangs) {
      try {
        if (TranslationFilenameParser.isNissaya(lang)) {
          final filename = TranslationFilenameParser.build(lang);
          final ndb = await ref.read(
            nissayaDbByFilenameProvider(filename).future,
          );
          if (ndb == null) continue;
          final rows = await ndb
              .customSelect(
                'SELECT para_id, line_id, content FROM sentences '
                'WHERE book_id = ? $rangeSql ORDER BY para_id, line_id',
                variables: [Variable.withString(bookId), ...rangeVars],
              )
              .get();
          final m = <int, Map<int, String>>{};
          for (final r in rows) {
            final text = _formatNissaya(r.data['content'] as String?);
            if (text.isEmpty) continue;
            final p = r.data['para_id'] as int;
            final l = r.data['line_id'] as int;
            m.putIfAbsent(p, () => {})[l] = text;
          }
          if (m.isNotEmpty) transByLang[lang] = m;
        } else {
          final TranslationDatabase? tdb = await ref.read(
            translationDbProvider(lang).future,
          );
          if (tdb == null) continue;
          final rows = await tdb
              .customSelect(
                'SELECT para_id, line_id, translation FROM sentences '
                'WHERE book_id = ? $rangeSql ORDER BY para_id, line_id',
                variables: [Variable.withString(bookId), ...rangeVars],
              )
              .get();
          final m = <int, Map<int, String>>{};
          for (final r in rows) {
            final text = r.data['translation'] as String?;
            if (text == null || text.trim().isEmpty) continue;
            final p = r.data['para_id'] as int;
            final l = r.data['line_id'] as int;
            m.putIfAbsent(p, () => {})[l] = text;
          }
          if (m.isNotEmpty) transByLang[lang] = m;
        }
      } catch (_) {}
    }

    final paras = <_CopyPara>[];
    var curParaId = -1;
    var curLines = <_CopyLine>[];
    var curPages = <String, String>{};
    String? curTitle;
    int? curLevel;

    void flush() {
      if (curParaId < 0) return;
      paras.add(
        _CopyPara(
          paraId: curParaId,
          headingTitle: curTitle,
          headingLevel: curLevel,
          lines: List.of(curLines),
          pageNumbers: Map.of(curPages),
        ),
      );
    }

    for (final r in sentenceRows) {
      final d = r.data;
      final p = d['para_id'] as int;
      if (p != curParaId) {
        if (curParaId >= 0) flush();
        curParaId = p;
        curLines = [];
        curPages = {};
        final h = headingByPara[p];
        curTitle = (h?['title'] as String?)?.trim().isNotEmpty == true
            ? (h!['title'] as String).trim()
            : null;
        curLevel = h?['level'] as int?;
      }
      for (final e in {
        'vri': d['vripage'],
        'pts': d['ptspage'],
        'thai': d['thaipage'],
        'my': d['mypage'],
      }.entries) {
        final v = (e.value as String?)?.trim() ?? '';
        if (v.isNotEmpty) curPages[e.key] = v;
      }
      final pali = (d['pali'] as String?) ?? '';
      final lineId = d['line_id'] as int;
      final trans = <String, String>{};
      for (final lang in transByLang.keys) {
        final t = transByLang[lang]?[p]?[lineId];
        if (t != null && t.trim().isNotEmpty) trans[lang] = t;
      }
      if (pali.trim().isEmpty && trans.isEmpty) continue;
      curLines.add(
        _CopyLine(
          paraId: p,
          lineId: lineId,
          pali: pali,
          translations: trans,
          pageNumbers: const {},
        ),
      );
    }
    flush();
    return paras.where((p) => p.lines.isNotEmpty).toList();
  }

  static Future<List<_CommentaryBlock>> _fetchCommentariesFull(
    WidgetRef ref,
    dynamic db,
    String bookId,
    int start,
    int endExclusive,
    List<String> enabledLangs,
  ) async {
    try {
      final jump = JumpService(db);
      final l10rows = await db
          .customSelect(
            'SELECT para_id, title FROM headings '
            'WHERE book_id = ? AND para_id >= ? AND para_id < ? AND level = 10 '
            'ORDER BY para_id ASC',
            variables: [
              Variable.withString(bookId),
              Variable.withInt(start),
              Variable.withInt(endExclusive),
            ],
          )
          .get();
      var sectionNumbers = <int>[];
      for (final r in l10rows) {
        final n = int.tryParse((r.data['title'] as String? ?? '').trim());
        if (n != null) sectionNumbers.add(n);
      }
      if (sectionNumbers.isEmpty) {
        final single = await jump.getSectionNumber(bookId, start);
        if (single != null) sectionNumbers = [single];
      }
      if (sectionNumbers.isEmpty) return [];

      final linkedBooks = await jump.getLinkedBooks(bookId);
      if (linkedBooks.isEmpty) return [];

      final out = <_CommentaryBlock>[];
      final seen = <String>{};
      for (final sectionNumber in sectionNumbers) {
        for (final link in linkedBooks) {
          if (out.length >= _maxCommentarySections) break;
          try {
            final match = await jump.findHeadingInBook(
              link.bookId,
              sectionNumber,
              type: link.type,
            );
            if (match == null) continue;
            final key = '${match.bookId}:${match.paraId}';
            if (!seen.add(key)) continue;
            final block = await _fetchFullSection(
              ref,
              db,
              match.bookId,
              match.paraId,
              link.type,
              enabledLangs,
            );
            if (block != null && block.lines.isNotEmpty) out.add(block);
          } catch (_) {}
        }
        if (out.length >= _maxCommentarySections) break;
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<_CommentaryBlock?> _fetchFullSection(
    WidgetRef ref,
    dynamic db,
    String bookId,
    int paraId,
    String type,
    List<String> enabledLangs,
  ) async {
    final secRows = await db
        .customSelect(
          'SELECT para_id, title, level FROM headings '
          'WHERE book_id = ? AND para_id <= ? AND level = 10 '
          'ORDER BY para_id DESC LIMIT 1',
          variables: [Variable.withString(bookId), Variable.withInt(paraId)],
        )
        .get();
    final int sectionStart;
    String? headingTitle;
    if (secRows.isNotEmpty) {
      sectionStart = secRows.first.data['para_id'] as int;
      headingTitle = secRows.first.data['title'] as String?;
    } else {
      sectionStart = paraId;
    }

    int? sectionEnd;
    if (sectionStart != paraId) {
      final nextRows = await db
          .customSelect(
            'SELECT para_id FROM headings '
            'WHERE book_id = ? AND para_id > ? '
            'ORDER BY para_id ASC LIMIT 1',
            variables: [
              Variable.withString(bookId),
              Variable.withInt(sectionStart),
            ],
          )
          .get();
      if (nextRows.isNotEmpty) {
        sectionEnd = nextRows.first.data['para_id'] as int;
      }
    }
    final rangeSql = sectionEnd != null
        ? 'AND para_id >= ? AND para_id < ?'
        : 'AND para_id >= ?';
    final rangeVars = sectionEnd != null
        ? [Variable.withInt(sectionStart), Variable.withInt(sectionEnd)]
        : [Variable.withInt(sectionStart)];

    final sentenceRows = await db
        .customSelect(
          'SELECT para_id, line_id, pali FROM sentences '
          'WHERE book_id = ? $rangeSql ORDER BY para_id, line_id',
          variables: [Variable.withString(bookId), ...rangeVars],
        )
        .get();
    if (sentenceRows.isEmpty) return null;

    var paraMin = sentenceRows.first.data['para_id'] as int;
    var paraMax = paraMin;
    for (final r in sentenceRows) {
      final p = r.data['para_id'] as int;
      if (p < paraMin) paraMin = p;
      if (p > paraMax) paraMax = p;
    }

    final transByLang = <String, Map<int, Map<int, String>>>{};
    for (final lang in enabledLangs) {
      try {
        if (TranslationFilenameParser.isNissaya(lang)) {
          final filename = TranslationFilenameParser.build(lang);
          final ndb = await ref.read(
            nissayaDbByFilenameProvider(filename).future,
          );
          if (ndb == null) continue;
          final rows = await ndb
              .customSelect(
                'SELECT para_id, line_id, content FROM sentences '
                'WHERE book_id = ? AND para_id >= ? AND para_id <= ? '
                'ORDER BY para_id, line_id',
                variables: [
                  Variable.withString(bookId),
                  Variable.withInt(paraMin),
                  Variable.withInt(paraMax),
                ],
              )
              .get();
          final m = <int, Map<int, String>>{};
          for (final r in rows) {
            final text = _formatNissaya(r.data['content'] as String?);
            if (text.isEmpty) continue;
            m.putIfAbsent(
              r.data['para_id'] as int,
              () => {},
            )[r.data['line_id'] as int] = text;
          }
          if (m.isNotEmpty) transByLang[lang] = m;
        } else {
          final TranslationDatabase? tdb = await ref.read(
            translationDbProvider(lang).future,
          );
          if (tdb == null) continue;
          final rows = await tdb
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
          final m = <int, Map<int, String>>{};
          for (final r in rows) {
            final text = r.data['translation'] as String?;
            if (text == null || text.isEmpty) continue;
            m.putIfAbsent(
              r.data['para_id'] as int,
              () => {},
            )[r.data['line_id'] as int] = text;
          }
          if (m.isNotEmpty) transByLang[lang] = m;
        }
      } catch (_) {}
    }

    final bookRow = await db
        .customSelect(
          'SELECT book_name FROM books WHERE book_id = ? LIMIT 1',
          variables: [Variable.withString(bookId)],
        )
        .get();
    final bookName = bookRow.isNotEmpty
        ? (bookRow.first.data['book_name'] as String? ?? bookId)
        : bookId;

    final lines = <_CopyLine>[];
    for (final r in sentenceRows) {
      final p = r.data['para_id'] as int;
      final l = r.data['line_id'] as int;
      final trans = <String, String>{};
      for (final e in transByLang.entries) {
        final t = e.value[p]?[l];
        if (t != null) trans[e.key] = t;
      }
      lines.add(
        _CopyLine(
          paraId: p,
          lineId: l,
          pali: (r.data['pali'] as String?) ?? '',
          translations: trans,
        ),
      );
    }

    return _CommentaryBlock(
      bookId: bookId,
      bookName: bookName,
      type: type,
      typeLabel: _typeLabel(type),
      headingTitle: headingTitle,
      lines: lines,
    );
  }

  /// Returns how the output was delivered (full styled copy, plain text
  /// after Android's size limit stripped the styling, or share sheet).
  static Future<_CopyOutcome> _copyMain({
    required String bookId,
    required String bookName,
    required ParagraphHeading? mainHeading,
    required List<_CopyPara> paras,
    required CopyScope scope,
    required String citation,
    required Set<String> enabledLangs,
    required Script script,
    required Color paliColor,
    required Color transColor,
  }) async {
    final plain = StringBuffer();
    final html = StringBuffer(
      '<div style="color:${_toCss(transColor)};font-family:Georgia,serif;font-size:16px;line-height:1.6;">',
    );
    final paliStyle =
        'color:${_toCss(paliColor)};font-family:Georgia,serif;font-size:16px;font-weight:400;';

    plain.writeln('$bookName ($bookId)');
    html.writeln(
      '<h2 style="margin:0 0 4px 0;">${_escape(bookName)} (${_escape(bookId)})</h2>',
    );
    final headTitle = (mainHeading?.title ?? '').trim();
    if (headTitle.isNotEmpty) {
      plain.writeln(headTitle);
      html.writeln('<h3 style="margin:0 0 8px 0;">${_escape(headTitle)}</h3>');
    }
    plain.writeln();

    _appendCopyParas(
      plain,
      html,
      paras,
      scope,
      enabledLangs,
      script,
      paliStyle,
      skipFirstHeading: headTitle.isNotEmpty,
    );

    if (citation.isNotEmpty) {
      plain.writeln();
      plain.writeln(citation);
      html.writeln(
        '<p style="margin-top:12px;color:#888;font-style:italic;font-size:13px;">${_escape(citation)}</p>',
      );
    }
    html.writeln('</div>');
    return _writeClipboard(
      plainText: plain.toString().trim(),
      htmlBody: html.toString(),
      shareSubject: '$bookName ($bookId)',
      bookId: bookId,
    );
  }

  static Future<_CopyOutcome> _copyWithCommentaries({
    required String bookId,
    required String bookName,
    required ParagraphHeading mainHeading,
    required List<_CopyPara> paras,
    required List<_CommentaryBlock> commentaries,
    required CopyScope scope,
    required String citation,
    required Set<String> enabledLangs,
    required Script script,
    required Color paliColor,
    required Color transColor,
  }) async {
    final plain = StringBuffer();
    final html = StringBuffer(
      '<div style="color:${_toCss(transColor)};font-family:Georgia,serif;font-size:16px;line-height:1.6;">',
    );
    final paliStyle =
        'color:${_toCss(paliColor)};font-family:Georgia,serif;font-size:16px;font-weight:400;';

    plain.writeln('# $bookName ($bookId)');
    html.writeln(
      '<h2 style="margin:0 0 4px 0;">${_escape(bookName)} (${_escape(bookId)})</h2>',
    );
    final headTitle = mainHeading.title.trim();
    if (headTitle.isNotEmpty) {
      plain.writeln('## $headTitle');
      html.writeln('<h3 style="margin:0 0 8px 0;">${_escape(headTitle)}</h3>');
    }
    plain.writeln();
    plain.writeln('---');
    plain.writeln();
    html.writeln('<hr/>');

    _appendCopyParas(
      plain,
      html,
      paras,
      scope,
      enabledLangs,
      script,
      paliStyle,
      skipFirstHeading: headTitle.isNotEmpty,
    );

    for (var i = 0; i < commentaries.length; i++) {
      final c = commentaries[i];
      final label = _commentaryLabel(c, index: i + 1);
      plain.writeln();
      plain.writeln('---');
      plain.writeln();
      plain.writeln(label);
      plain.writeln();
      html.writeln(
        '<br/><hr/><h3 style="margin:12px 0 8px 0;">${_escape(label)}</h3>',
      );
      var prevPara = -1;
      for (final line in c.lines) {
        if (line.paraId != prevPara) {
          prevPara = line.paraId;
          if (line.paraId != c.lines.first.paraId) {
            plain.writeln();
            html.writeln('<br/>');
          }
        }
        if (scope != CopyScope.translation) {
          final pali = line.pali.trim();
          if (pali.isNotEmpty) {
            final converted = convertPaliToScriptPreservingHtml(pali, script);
            plain.writeln(_stripTags(converted));
            html.writeln(
              '<p style="${paliStyle}margin:0 0 4px 0;"><i>${_htmlFromTaggedText(converted)}</i></p>',
            );
          }
        }
        if (scope != CopyScope.pali) {
          final entries = enabledLangs.isNotEmpty
              ? line.translations.entries.where(
                  (e) => enabledLangs.contains(e.key),
                )
              : line.translations.entries;
          for (final e in entries) {
            final text = e.value.trim();
            if (text.isEmpty) continue;
            plain.writeln(_stripTags(text));
            html.writeln(
              '<p style="margin:0 0 2px 0;padding-left:16px;">${_htmlFromTaggedText(text)}</p>',
            );
          }
        }
      }
    }

    if (citation.isNotEmpty) {
      plain.writeln();
      plain.writeln('---');
      plain.writeln(citation);
      html.writeln(
        '<p style="margin-top:12px;color:#888;font-style:italic;font-size:13px;">${_escape(citation)}</p>',
      );
    }
    html.writeln('</div>');
    return _writeClipboard(
      plainText: plain.toString().trim(),
      htmlBody: html.toString(),
      shareSubject: '$bookName ($bookId)',
      bookId: bookId,
    );
  }

  static void _appendCopyParas(
    StringBuffer plain,
    StringBuffer html,
    List<_CopyPara> paras,
    CopyScope scope,
    Set<String> enabledLangs,
    Script script,
    String paliStyle, {
    bool skipFirstHeading = false,
  }) {
    for (int pi = 0; pi < paras.length; pi++) {
      final para = paras[pi];
      final title = (para.headingTitle ?? '').trim();
      final isFirst = pi == 0;
      if (title.isNotEmpty && !(isFirst && skipFirstHeading)) {
        plain.writeln();
        plain.writeln('### $title');
        plain.writeln();
        html.writeln('<h4 style="margin:8px 0;">${_escape(title)}</h4>');
      }
      for (final line in para.lines) {
        if (scope != CopyScope.translation) {
          final pali = line.pali.trim();
          if (pali.isNotEmpty) {
            final converted = convertPaliToScriptPreservingHtml(pali, script);
            plain.writeln(_stripTags(converted));
            html.writeln(
              '<p style="${paliStyle}margin:0 0 4px 0;"><i>${_htmlFromTaggedText(converted)}</i></p>',
            );
          }
        }
        if (scope != CopyScope.pali) {
          final entries = enabledLangs.isNotEmpty
              ? line.translations.entries.where(
                  (e) => enabledLangs.contains(e.key),
                )
              : line.translations.entries;
          for (final e in entries) {
            final text = e.value.trim();
            if (text.isEmpty) continue;
            plain.writeln(_stripTags(text));
            html.writeln(
              '<p style="margin:0 0 2px 0;padding-left:16px;">${_htmlFromTaggedText(text)}</p>',
            );
          }
        }
      }
      if (pi < paras.length - 1) {
        plain.writeln();
        html.writeln('<br/>');
      }
    }
  }

  static Map<String, String> _firstPages(List<_CopyPara> paras) {
    if (paras.isEmpty) return const {};
    if (paras.first.pageNumbers.values.any((v) => v.trim().isNotEmpty)) {
      return paras.first.pageNumbers;
    }
    for (final p in paras) {
      if (p.pageNumbers.values.any((v) => v.trim().isNotEmpty)) {
        return p.pageNumbers;
      }
    }
    final pageMap = <String, String>{};
    try {
      final asParagraphs = paras
          .map(
            (p) => ParagraphData(
              paraId: p.paraId,
              pageNumbers: p.pageNumbers,
              pageNumber: p.pageNumbers.values.firstOrNull,
            ),
          )
          .toList();
      return firstAvailablePageNumbers(asParagraphs);
    } catch (_) {
      return pageMap;
    }
  }

  static String _commentaryLabel(_CommentaryBlock c, {required int index}) {
    final title = (c.headingTitle ?? '').trim();
    final name = c.bookName.trim().isEmpty ? c.bookId : c.bookName.trim();
    final typeSuffix = c.typeLabel.trim().isEmpty
        ? ''
        : ' (${c.typeLabel.trim()})';
    if (title.isNotEmpty) {
      return '## Commentary $index: $name$typeSuffix — $title';
    }
    return '## Commentary $index: $name$typeSuffix';
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'mula':
        return 'Mūla';
      case 'attha':
        return 'Aṭṭhakathā';
      case 'tika':
        return 'Ṭīkā';
      default:
        return type == 'other' ? '' : type;
    }
  }

  static String _formatNissaya(String? content) {
    if (content == null || content.isEmpty) return '';
    final trimmed = content.trim();
    if (!trimmed.startsWith('[')) return content;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) return content;
      final parts = <String>[];
      for (final item in decoded) {
        if (item is Map) {
          final pali = (item['pali'] as String?) ?? '';
          final meaning = (item['meaning'] as String?) ?? '';
          if (pali.isEmpty && meaning.isEmpty) continue;
          if (meaning.isEmpty) {
            parts.add(pali);
          } else {
            parts.add('$pali: $meaning');
          }
        } else {
          parts.add(item.toString());
        }
      }
      return parts.join(' | ');
    } catch (_) {
      return content;
    }
  }

  /// Only Android funnels the clipboard through a ~1MB binder transaction
  /// that truncates large payloads. Other platforms copy without size caps,
  /// so they always get the full styled content.
  static bool get _sizeCapped =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static String _copiedMessage(_CopyOutcome outcome, String what) {
    switch (outcome) {
      case _CopyOutcome.full:
        return '$what copied';
      case _CopyOutcome.strippedToPlain:
        return '$what copied as plain text — too large for styled copy on Android';
      case _CopyOutcome.shared:
        return '$what too large for the Android clipboard — opened share instead';
    }
  }

  /// Writes to the clipboard. On Android the size caps apply (styled copy
  /// for small content, plain text when styling no longer fits, share sheet
  /// when even plain text no longer fits); other platforms always get the
  /// full styled copy with no stripping.
  static Future<_CopyOutcome> _writeClipboard({
    required String plainText,
    required String htmlBody,
    required String shareSubject,
    required String bookId,
  }) async {
    if (plainText.isEmpty) return _CopyOutcome.full;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
      try {
        await Clipboard.setData(ClipboardData(text: plainText));
      } catch (_) {}
      return _CopyOutcome.full;
    }
    if (_sizeCapped && plainText.length > _plainCopyMaxChars) {
      await _shareFile(text: plainText, bookId: bookId, subject: shareSubject);
      return _CopyOutcome.shared;
    }
    final useRich = !_sizeCapped || plainText.length <= _richCopyMaxChars;
    if (useRich) {
      final htmlDoc =
          '<!DOCTYPE html>\n<html>\n<head><meta charset="utf-8">'
          '<meta name="generator" content="ePitaka"></head>\n<body>\n$htmlBody\n</body>\n</html>';
      try {
        await FlutterClipboard.copyRichText(text: plainText, html: htmlDoc);
        return _CopyOutcome.full;
      } catch (_) {}
    }
    try {
      await Clipboard.setData(ClipboardData(text: plainText));
      return useRich ? _CopyOutcome.full : _CopyOutcome.strippedToPlain;
    } catch (_) {
      await _shareFile(text: plainText, bookId: bookId, subject: shareSubject);
      return _CopyOutcome.shared;
    }
  }

  /// Shares over-cap content as a `.md` file. Sharing the text inline would
  /// hit the same ~1MB binder ceiling as the clipboard; a content-URI file
  /// has no size limit, so the full text always arrives intact.
  static Future<void> _shareFile({
    required String text,
    required String bookId,
    required String subject,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final safe = bookId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File(p.join(dir.path, 'epitaka_$safe.md'));
      await file.writeAsString(text);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/markdown')],
          subject: subject,
          text: '$subject — exported from ePitaka',
        ),
      );
      return;
    } catch (_) {}
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: subject));
    } catch (_) {
      try {
        await Clipboard.setData(ClipboardData(text: text));
      } catch (_) {}
    }
  }

  static void _snack(BuildContext context, String message) {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {}
  }

  static String _toCss(Color c) {
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String _stripTags(String s) => s
      .replaceAll('<br>', '\n')
      .replaceAll('<br/>', '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n');

  static String _htmlFromTaggedText(String text) {
    String result = text
        .replaceAll('<br>', '<br/>')
        .replaceAllMapped(
          RegExp(r'<b>(.*?)</b>', caseSensitive: false, dotAll: true),
          (m) => '<strong>${m[1]}</strong>',
        )
        .replaceAllMapped(
          RegExp(r'<i>(.*?)</i>', caseSensitive: false, dotAll: true),
          (m) => '<em>${m[1]}</em>',
        )
        .replaceAllMapped(
          RegExp(r'<u>(.*?)</u>', caseSensitive: false, dotAll: true),
          (m) => '<u>${m[1]}</u>',
        );
    result = result.replaceAllMapped(RegExp(r'[^<>]+'), (m) => _escape(m[0]!));
    return result;
  }
}
