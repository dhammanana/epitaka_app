import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';
import '../../../core/models/translation_version.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../data/book_link_data.dart';
import '../services/book_link_service.dart';

/// One row from a translation database's `translation_remarks` table.
///
/// Carries the full remark record — the AI's conflict note, its supporting
/// Pāli / translation, and metadata — so the reader's remark dialog can
/// display and edit everything, not just the free-text note.
class TranslationRemark {
  /// Row id in `translation_remarks` (null for a not-yet-saved row).
  final int? id;
  final int paraId;
  final int lineId;
  final String pali;
  final String translation;
  final String conflict;
  final String note;
  final String? sourceId;
  final String? createdAt;

  const TranslationRemark({
    this.id,
    required this.paraId,
    required this.lineId,
    this.pali = '',
    this.translation = '',
    this.conflict = '',
    this.note = '',
    this.sourceId,
    this.createdAt,
  });

  /// Whether this remark has any editable content (so the reader only
  /// marks lines whose remark is worth showing).
  bool get hasContent =>
      pali.trim().isNotEmpty ||
      translation.trim().isNotEmpty ||
      conflict.trim().isNotEmpty ||
      note.trim().isNotEmpty;
}

/// A single line within a paragraph (Pāli + translations per line).
class LineData {
  final int lineId;
  final String? paliText;
  final Map<String, String> translations;

  /// Page numbers for THIS line, keyed by system code: 'vri', 'pts',
  /// 'thai', 'my'. Typically only the line where a page begins carries a
  /// value (the sentence row that opens the page). Used to render the page
  /// badge at the start of the page-break line instead of only at paragraph
  /// boundaries.
  final Map<String, String> pageNumbers;

  /// Pre-computed diacritic-normalized text for fast in-book search.
  /// Combines Pāli + all translations, stripped of HTML/brackets/punctuation
  /// and with diacritics normalized (ā→a, ṭ→t, ṃ→m, etc.).
  final String normalizedText;

  /// Translation remarks for this line, keyed by language code (e.g. 'en').
  /// Each language holds a list because a line can carry several remark
  /// rows (e.g. one per conflict the AI flagged). Filled from the
  /// translation database's `translation_remarks` table and rendered as a
  /// small note mark under the line's translation; tapping the mark opens
  /// the full remark editor. Empty when the language has no remark for
  /// this line or the table doesn't exist.
  final Map<String, List<TranslationRemark>> remarks;

  const LineData({
    required this.lineId,
    this.paliText,
    this.translations = const {},
    this.pageNumbers = const {},
    required this.normalizedText,
    this.remarks = const {},
  });
}

/// Heading info displayed inline in the reader before a paragraph.
class ParagraphHeading {
  final String title;
  final int level;
  final int paraId;

  const ParagraphHeading({
    required this.title,
    required this.level,
    required this.paraId,
  });
}

/// A paragraph with multiple lines and optional page numbers.
class ParagraphData {
  final int paraId;
  final List<LineData> lines;

  /// The primary page number (from settings' preferred page numbering system).
  final String? pageNumber;

  /// All page numbers keyed by system code: 'vri', 'pts', 'thai', 'my'.
  final Map<String, String> pageNumbers;

  /// True if this paragraph starts a new page (page number differs from previous).
  final bool isPageStart;

  /// Optional heading that applies to this paragraph (exact match by paraId).
  final ParagraphHeading? heading;

  const ParagraphData({
    required this.paraId,
    this.lines = const [],
    this.pageNumber,
    this.pageNumbers = const {},
    this.isPageStart = false,
    this.heading,
  });

  ParagraphData copyWith({
    int? paraId,
    List<LineData>? lines,
    String? pageNumber,
    Map<String, String>? pageNumbers,
    bool? isPageStart,
    ParagraphHeading? heading,
  }) {
    return ParagraphData(
      paraId: paraId ?? this.paraId,
      lines: lines ?? this.lines,
      pageNumber: pageNumber ?? this.pageNumber,
      pageNumbers: pageNumbers ?? this.pageNumbers,
      isPageStart: isPageStart ?? this.isPageStart,
      heading: heading ?? this.heading,
    );
  }
}

/// State held by [ReaderDataNotifier] for a single book reader.
class ReaderDataState {
  final String bookId;
  final String? bookName;
  final String? bookDescription;
  final List<ParagraphData> paragraphs;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isLoaded;
  final bool hasMore;
  final String? error;

  /// Book links grouped by paraId then lineId.
  final BookLinksMap bookLinks;

  const ReaderDataState({
    required this.bookId,
    this.bookName,
    this.bookDescription,
    this.paragraphs = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isLoaded = false,
    this.hasMore = true,
    this.error,
    this.bookLinks = const {},
  });

  ReaderDataState copyWith({
    String? bookId,
    String? bookName,
    String? bookDescription,
    List<ParagraphData>? paragraphs,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isLoaded,
    bool? hasMore,
    String? error,
    BookLinksMap? bookLinks,
  }) {
    return ReaderDataState(
      bookId: bookId ?? this.bookId,
      bookName: bookName ?? this.bookName,
      bookDescription: bookDescription ?? this.bookDescription,
      paragraphs: paragraphs ?? this.paragraphs,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isLoaded: isLoaded ?? this.isLoaded,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      bookLinks: bookLinks ?? this.bookLinks,
    );
  }
}

/// StateNotifier that loads ALL paragraphs for a book at once.
///
/// Previously this loaded in pages of 200 paragraphs (lazy pagination)
/// triggered by scroll position. Now it loads everything in a single
/// query for simplicity and to enable the draggable scroll thumb (which
/// needs to know the total item count).
class ReaderDataNotifier extends StateNotifier<ReaderDataState> {
  final Ref _ref;
  final String _bookId;
  int? _scrollToParaId;

  /// All headings for this book (loaded once).
  List<HeadingInfo>? _headings;

  /// Monotonically increasing generation counter.  Incremented before
  /// every async [_loadBook] call.  When the async load completes, the
  /// captured generation is compared against the current counter.  If
  /// they differ, a newer load has started and this stale result is
  /// discarded.  This prevents race conditions when settings change
  /// rapidly (e.g. enabling a language then immediately selecting the
  /// nissaya version in settings).
  int _loadGeneration = 0;

  ReaderDataNotifier(this._ref, this._bookId, {this._scrollToParaId})
    : super(ReaderDataState(bookId: _bookId)) {
    _loadBook();

    // Listen for settings changes (e.g. version selection, language enable/
    // disable) that may require re-loading translation data (including nissaya
    // databases).  We must watch both [translationVersionMap] (which version
    // of a translation to use) AND [enabledTranslations] (which languages are
    // actually shown).  Without this, enabling a language for which a version
    // was already selected will not trigger a reload, and the translation
    // won't appear.
    _ref.listen(settingsProvider, (AppSettings? prev, AppSettings next) {
      if (prev != null) {
        final prevHash = Object.hashAll([
          Object.hashAll(prev.translationVersionMap.entries),
          Object.hashAll(prev.enabledTranslations),
          prev.pageNumberingSystem,
        ]);
        final nextHash = Object.hashAll([
          Object.hashAll(next.translationVersionMap.entries),
          Object.hashAll(next.enabledTranslations),
          next.pageNumberingSystem,
        ]);
        if (prevHash != nextHash) {
          _headings = null; // Reset headings to force clean reload
          _loadBook();
        }
      }
    });
  }

  int? get scrollTarget => _scrollToParaId;

  void clearScrollTarget() {
    _scrollToParaId = null;
  }

  /// Wait until the full book data finishes loading.
  Future<void> waitUntilLoaded() async {
    if (state.isLoaded) return;
    await stream.firstWhere((s) => s.isLoaded);
  }

  Future<void> _loadBook() async {
    // Capture the generation at the start so we can discard stale results.
    final gen = ++_loadGeneration;

    final sw = Stopwatch()..start();
    developer.log(
      '[LOAD] Starting full book load for bookId=$_bookId gen=$gen',
      name: 'epitaka.reader',
    );

    state = state.copyWith(isLoading: true);
    try {
      // Load headings once
      if (_headings == null) {
        await _loadHeadings();
        developer.log(
          '[LOAD] Headings loaded for bookId=$_bookId (${_headings?.length ?? 0} headings)',
          name: 'epitaka.reader',
        );
      }

      final result = await _loadAllParagraphs();

      // ── Guard: discard if a newer load has started ────────────────
      if (gen != _loadGeneration) {
        developer.log(
          '[LOAD] Stale load for bookId=$_bookId gen=$gen '
          '(current=$_loadGeneration) — discarded',
          name: 'epitaka.reader',
        );
        return;
      }

      // Apply the result only after the generation check passes.
      if (result != null) {
        state = state.copyWith(
          paragraphs: result.paragraphs,
          bookLinks: result.bookLinks,
          isLoading: false,
          isLoaded: true,
          hasMore: false,
          error: null,
        );
      }

      sw.stop();
      developer.log(
        '[LOAD] Full book load complete for bookId=$_bookId '
        'paraCount=${state.paragraphs.length} elapsedMs=${sw.elapsedMilliseconds}',
        name: 'epitaka.reader',
      );
    } catch (e, stack) {
      sw.stop();
      developer.log(
        '[LOAD] Error loading bookId=$_bookId elapsedMs=${sw.elapsedMilliseconds}: $e\n$stack',
        name: 'epitaka.reader',
      );
      // Only set error state if this is still the latest generation
      if (gen == _loadGeneration) {
        state = state.copyWith(
          isLoading: false,
          isLoaded: true,
          error: e.toString(),
        );
      }
    }
  }

  Future<void> _loadHeadings() async {
    final db = await _ref.read(epitakaDbProvider.future);

    final sw = Stopwatch()..start();

    final rows =
        await (db.select(db.headings)
              ..where(
                (h) =>
                    h.bookId.equals(_bookId) &
                    h.level.isSmallerThan(const Constant(10)),
              )
              ..orderBy([(h) => OrderingTerm(expression: h.paraId)]))
            .get();

    sw.stop();
    developer.log(
      '[LOAD] Headings SQL: ${sw.elapsedMilliseconds}ms rows=${rows.length}',
      name: 'epitaka.reader',
    );

    final buildSw = Stopwatch()..start();

    _headings = rows
        .map(
          (row) => HeadingInfo(
            bookId: row.bookId,
            paraId: row.paraId,
            level: row.level,
            title: row.title,
            chapterLen: row.chapterLen,
            parent: row.parent,
            scId: row.scId,
          ),
        )
        .toList();

    buildSw.stop();
    developer.log(
      '[LOAD] Headings build: ${buildSw.elapsedMilliseconds}ms',
      name: 'epitaka.reader',
    );
  }

  /// Find the heading that exactly matches [paraId], if any.
  ParagraphHeading? _headingForPara(int paraId) {
    if (_headings == null) return null;
    for (final h in _headings!) {
      if (h.paraId == paraId) {
        return ParagraphHeading(
          title: h.title ?? '',
          level: h.level ?? 1,
          paraId: h.paraId,
        );
      }
    }
    return null;
  }

  /// Find the nearest heading whose paraId <= [paraId].
  /// Returns null if no heading exists before or at this position.
  ParagraphHeading? findNearbyHeading(int paraId) {
    if (_headings == null || _headings!.isEmpty) return null;
    ParagraphHeading? best;
    for (final h in _headings!) {
      if (h.paraId <= paraId) {
        best = ParagraphHeading(
          title: h.title ?? '',
          level: h.level ?? 1,
          paraId: h.paraId,
        );
      } else {
        break; // headings are ordered by paraId ascending
      }
    }
    return best;
  }

  /// Load ALL paragraphs for this book in one shot (no pagination) and
  /// build the full [ParagraphData] list with translations.
  ///
  /// Returns `null` when the paragraphs were already emitted (e.g. no
  /// content found).  Otherwise returns the loaded paragraphs and book
  /// links.  The caller ([_loadBook]) is responsible for calling
  /// [state.copyWith] only after the generation check passes.
  Future<({List<ParagraphData> paragraphs, BookLinksMap bookLinks})?>
  _loadAllParagraphs() async {
    final db = await _ref.read(epitakaDbProvider.future);
    final settings = _ref.read(settingsProvider);

    final pageColumn = _pageColumnName(settings.pageNumberingSystem);

    final enabledLangs = settings.enabledTranslations.isNotEmpty
        ? settings.enabledTranslations.toList()
        : (settings.showTranslation
              ? [settings.primaryTranslationLang]
              : <String>[]);

    // ── Get book info ────────────────────────────────────────────────
    final bookSw = Stopwatch()..start();
    final books =
        await (db.select(db.books)
              ..where((b) => b.bookId.equals(_bookId))
              ..limit(1))
            .get();
    final book = books.isNotEmpty ? books.first : null;
    bookSw.stop();
    developer.log(
      '[LOAD] Book info query: ${bookSw.elapsedMilliseconds}ms, '
      'name="${book?.bookName ?? '-'}"',
      name: 'epitaka.reader',
    );

    if (book != null) {
      state = state.copyWith(
        bookName: book.bookName,
        bookDescription: book.description,
      );
    }

    // ── Get all distinct para_ids (no LIMIT/OFFSET) ──────────────────
    final paraSw = Stopwatch()..start();
    final paraRows = await db
        .customSelect(
          'SELECT para_id FROM sentences WHERE book_id = ? '
          'GROUP BY para_id ORDER BY para_id',
          variables: [Variable(_bookId)],
        )
        .get();
    final paraIds = paraRows.map((r) => r.data['para_id'] as int).toList();
    paraSw.stop();
    developer.log(
      '[LOAD] para_id query: ${paraSw.elapsedMilliseconds}ms, '
      'paraCount=${paraIds.length}',
      name: 'epitaka.reader',
    );

    if (paraIds.isEmpty) {
      developer.log(
        '[LOAD] No paragraphs found for bookId=$_bookId',
        name: 'epitaka.reader',
      );
      state = state.copyWith(
        isLoading: false,
        isLoaded: true,
        hasMore: false,
        error: null,
      );
      return null;
    }

    // ── Get sentences for all para_ids ───────────────────────────────
    final sentSw = Stopwatch()..start();
    // Query by book_id only (indexed). The paraIds we computed above are
    // exactly the distinct para_ids for this book, so an extra
    // `para_id IN (...)` (2477 entries) clause only slows SQLite down.
    final sentences =
        await (db.select(db.sentences)
              ..where((s) => s.bookId.equals(_bookId))
              ..orderBy([
                (s) => OrderingTerm(expression: s.paraId),
                (s) => OrderingTerm(expression: s.lineId),
              ]))
            .get();
    sentSw.stop();
    developer.log(
      '[LOAD] Sentence query: ${sentSw.elapsedMilliseconds}ms, '
      'sentenceCount=${sentences.length}',
      name: 'epitaka.reader',
    );

    // ── Group into paraId -> lines ───────────────────────────────────
    // Read all four page number columns from each sentence row, not just
    // the one matching the selected page system. This way the quote citation
    // can use ANY page system (e.g. {pts_page} gets the real PTS page, not
    // a copy of VRI page).
    final groupSw = Stopwatch()..start();
    final paraLines = <int, List<_RawLine>>{};
    for (final s in sentences) {
      final pageNumbers = <String, String>{
        'vri': (s as dynamic).vripage as String? ?? '',
        'pts': (s as dynamic).ptspage as String? ?? '',
        'thai': (s as dynamic).thaipage as String? ?? '',
        'my': (s as dynamic).mypage as String? ?? '',
      };
      // Remove empty entries
      pageNumbers.removeWhere((_, v) => v.isEmpty);

      // The primary page number from the user's preferred system
      final preferredPage =
          pageNumbers[pageColumn == 'vripage'
              ? 'vri'
              : pageColumn == 'ptspage'
              ? 'pts'
              : pageColumn == 'thaipage'
              ? 'thai'
              : pageColumn == 'mypage'
              ? 'my'
              : 'vri'];

      paraLines.putIfAbsent(s.paraId, () => []);
      if (s.pali != null && s.pali!.trim().isNotEmpty) {
        paraLines[s.paraId]!.add(
          _RawLine(
            lineId: s.lineId,
            paliText: s.pali!,
            pageNumbers: pageNumbers,
          ),
        );
      } else if (preferredPage != null && preferredPage.isNotEmpty) {
        if (paraLines[s.paraId]!.isEmpty) {
          paraLines[s.paraId]!.add(
            _RawLine(
              lineId: s.lineId,
              paliText: null,
              pageNumbers: pageNumbers,
            ),
          );
        }
      }
    }
    groupSw.stop();
    developer.log(
      '[LOAD] Grouping sentences: ${groupSw.elapsedMilliseconds}ms',
      name: 'epitaka.reader',
    );

    // ── Load all enabled translations in parallel ────────────────────
    final transSw = Stopwatch()..start();
    final transByLang = <String, Map<int, Map<int, String>>>{};

    // Translation remarks per language: lang -> paraId -> lineId -> rows.
    final remarksByLang =
        <String, Map<int, Map<int, List<TranslationRemark>>>>{};
    await Future.wait(
      enabledLangs.map((langCode) async {
        final settings = _ref.read(settingsProvider);
        final versionSuffix = settings.translationVersionMap[langCode];
        final isNissaya =
            versionSuffix != null &&
            TranslationFilenameParser.isNissaya(versionSuffix);

        if (isNissaya) {
          // ── Load from nissaya database ────────────────────────────
          final filename = TranslationFilenameParser.build(
            langCode,
            suffix: versionSuffix,
          );
          final nissayaDb = await _ref.read(
            nissayaDbByFilenameProvider(filename).future,
          );
          if (nissayaDb == null) return;

          try {
            final nissayaData = await nissayaDb.getBookSentencesFormatted(
              _bookId,
            );
            if (nissayaData.isNotEmpty) {
              transByLang[langCode] = nissayaData;
            }
          } catch (e) {
            developer.log(
              '[LOAD] Nissaya error ($langCode): $e',
              name: 'epitaka.reader',
            );
          }
        } else {
          // ── Load from standard translation database ───────────────
          final translationDb = await _ref.read(
            translationDbProvider(langCode).future,
          );
          if (translationDb == null) return;

          // NOTE: We intentionally query by `book_id` ONLY (the
          // `(book_id, para_id, line_id)` index covers it) instead of
          // adding `para_id IN (...)` with every paragraph id. A 2477-element
          // IN clause forces SQLite to build a huge statement and do a slow
          // membership check — that alone accounted for ~1s of the load.
          // We filter out any stray para_ids with an O(1) Set lookup below.
          final paraIdSet = paraIds is Set<int>
              ? paraIds as Set<int>
              : paraIds.toSet();
          final tSw = Stopwatch()..start();
          final transSentences = await (translationDb.select(
            translationDb.translationSentences,
          )..where((t) => t.bookId.equals(_bookId))).get();
          tSw.stop();

          final langMap = <int, Map<int, String>>{};
          for (final t in transSentences) {
            if (t.translation == null) continue;
            // Skip para_ids that aren't part of this book's Pāli text.
            if (!paraIdSet.contains(t.paraId)) continue;
            langMap.putIfAbsent(t.paraId, () => {});
            langMap[t.paraId]!.update(
              t.lineId,
              (existing) => '$existing ${t.translation}',
              ifAbsent: () => t.translation!,
            );
          }
          transByLang[langCode] = langMap;

          // ── Translation remarks for this book ─────────────────────
          // The `translation_remarks` table exists in every translation DB
          // (may be absent in older files — tolerate that). Remarks are
          // sparse, keyed by (para_id, line_id); a line can carry several
          // rows, so each line keeps a list.
          try {
            final rSw = Stopwatch()..start();
            final remarkRows = await translationDb
                .customSelect(
                  'SELECT id, para_id, line_id, pali, translation, conflict, '
                  'note, source_id, created_at FROM translation_remarks '
                  'WHERE book_id = ?',
                  variables: [Variable(_bookId)],
                )
                .get();
            rSw.stop();
            if (remarkRows.isNotEmpty) {
              final remarksByLine = <int, Map<int, List<TranslationRemark>>>{};
              for (final r in remarkRows) {
                final paraId = r.data['para_id'] as int;
                final lineId = r.data['line_id'] as int;
                final remark = _remarkFromRow(r.data);
                if (!remark.hasContent) continue;
                remarksByLine.putIfAbsent(paraId, () => {});
                remarksByLine[paraId]!
                    .putIfAbsent(lineId, () => [])
                    .add(remark);
              }
              remarksByLang[langCode] = remarksByLine;
            }
            developer.log(
              '[LOAD] Remarks ($langCode): ${rSw.elapsedMilliseconds}ms, '
              'rows=${remarkRows.length}',
              name: 'epitaka.reader',
            );
          } catch (e) {
            developer.log(
              '[LOAD] Remarks error ($langCode): $e',
              name: 'epitaka.reader',
            );
          }

          developer.log(
            '[LOAD] Translation ($langCode): ${tSw.elapsedMilliseconds}ms, '
            'sentences=${transSentences.length}',
            name: 'epitaka.reader',
          );
        }
      }),
    );
    transSw.stop();
    developer.log(
      '[LOAD] All translations loaded: ${transSw.elapsedMilliseconds}ms total, '
      'langs=${enabledLangs.length}',
      name: 'epitaka.reader',
    );

    // ── Build paragraphs with lines ──────────────────────────────────
    final buildSw = Stopwatch()..start();
    final paragraphs = <ParagraphData>[];
    String? previousPageNumber;
    // Page numbers (all systems) in effect from the previous paragraph. The
    // DB stores page numbers only on the sentence that opens a page, so
    // without carry-forward most paragraphs would have no page numbers at all.
    Map<String, String> previousPageNumbers = const {};

    for (final entry in paraLines.entries) {
      final paraId = entry.key;
      final rawLines = entry.value;

      // Seed with the carry-forward so paragraphs without a page-break line
      // still know which page they are on.
      final mergedPageNumbers = <String, String>{...previousPageNumbers};
      String? pageNumber;
      for (final rl in rawLines) {
        mergedPageNumbers.addAll(rl.pageNumbers);
        // Primary page number from the user's preferred system. Read from
        // THIS paragraph's own page-break lines only (not the seed) so
        // isPageStart detection below stays correct.
        if (pageNumber == null && rl.pageNumbers.isNotEmpty) {
          final preferredCode = pageColumn == 'vripage'
              ? 'vri'
              : pageColumn == 'ptspage'
              ? 'pts'
              : pageColumn == 'thaipage'
              ? 'thai'
              : pageColumn == 'mypage'
              ? 'my'
              : 'vri';
          pageNumber = rl.pageNumbers[preferredCode];
        }
      }

      final isPageStart =
          pageNumber != null &&
          previousPageNumber != null &&
          pageNumber != previousPageNumber;

      // Match with heading
      final heading = _headingForPara(paraId);

      final lines = <LineData>[];
      for (final rl in rawLines) {
        final lineTranslations = <String, String>{};
        final lineRemarks = <String, List<TranslationRemark>>{};
        for (final lang in transByLang.keys) {
          final text = transByLang[lang]?[paraId]?[rl.lineId];
          if (text != null) lineTranslations[lang] = text;
          final remarks = remarksByLang[lang]?[paraId]?[rl.lineId];
          if (remarks != null && remarks.isNotEmpty) {
            lineRemarks[lang] = remarks;
          }
        }
        // Normalized text for in-book search is now computed on-demand
        // during search (see reader_search_notifier.dart), not eagerly during
        // book load. This saves ~590ms on opening a book with 8863 lines.
        lines.add(
          LineData(
            lineId: rl.lineId,
            paliText: rl.paliText,
            translations: lineTranslations,
            normalizedText: '',
            pageNumbers: rl.pageNumbers,
            remarks: lineRemarks,
          ),
        );
      }

      paragraphs.add(
        ParagraphData(
          paraId: paraId,
          lines: lines,
          pageNumber: pageNumber ?? previousPageNumber,
          pageNumbers: Map.unmodifiable(mergedPageNumbers),
          isPageStart: isPageStart,
          heading: heading,
        ),
      );

      if (pageNumber != null) {
        previousPageNumber = pageNumber;
      }
      previousPageNumbers = mergedPageNumbers;
    }
    buildSw.stop();
    developer.log(
      '[LOAD] Building paragraph objects: ${buildSw.elapsedMilliseconds}ms',
      name: 'epitaka.reader',
    );

    // ── Load book links ────────────────────────────────────────────
    final linkSw = Stopwatch()..start();
    BookLinksMap bookLinks = const {};
    try {
      final service = BookLinkService(db);
      bookLinks = await service.getLinksForBook(_bookId);
    } catch (e) {
      developer.log('[LOAD] Book links error: $e', name: 'epitaka.reader');
    }
    linkSw.stop();
    developer.log(
      '[LOAD] Book links loaded: ${linkSw.elapsedMilliseconds}ms, '
      'paraCount=${bookLinks.length}',
      name: 'epitaka.reader',
    );

    // ── Return data for the caller to emit (after generation check) ──
    return (paragraphs: paragraphs, bookLinks: bookLinks);
  }

  /// Re-read `translation_remarks` for [langCode] and patch the loaded
  /// paragraphs' remarks in place (no full book reload), so the remark
  /// editor's saved edits show up as soon as the dialog closes.
  Future<void> refreshRemarks(String langCode) async {
    final settings = _ref.read(settingsProvider);
    final versionSuffix = settings.translationVersionMap[langCode];
    final isNissaya =
        versionSuffix != null &&
        TranslationFilenameParser.isNissaya(versionSuffix);
    if (isNissaya) return; // Nissaya DBs have no remarks table.

    final translationDb = await _ref.read(
      translationDbProvider(langCode).future,
    );
    if (translationDb == null) return;

    try {
      final remarkRows = await translationDb
          .customSelect(
            'SELECT id, para_id, line_id, pali, translation, conflict, '
            'note, source_id, created_at FROM translation_remarks '
            'WHERE book_id = ?',
            variables: [Variable(_bookId)],
          )
          .get();
      final remarksByLine = <int, Map<int, List<TranslationRemark>>>{};
      for (final r in remarkRows) {
        final paraId = r.data['para_id'] as int;
        final lineId = r.data['line_id'] as int;
        final remark = _remarkFromRow(r.data);
        if (!remark.hasContent) continue;
        remarksByLine.putIfAbsent(paraId, () => {});
        remarksByLine[paraId]!.putIfAbsent(lineId, () => []).add(remark);
      }

      // Patch each paragraph's lines' remarks maps for this language.
      final patched = state.paragraphs.map((p) {
        final paraRemarks = remarksByLine[p.paraId];
        if (paraRemarks == null) return p;
        final lines = p.lines.map((l) {
          final list = paraRemarks[l.lineId];
          if (list == null || list.isEmpty) return l;
          final updated = Map<String, List<TranslationRemark>>.from(l.remarks)
            ..[langCode] = list;
          return LineData(
            lineId: l.lineId,
            paliText: l.paliText,
            translations: l.translations,
            normalizedText: l.normalizedText,
            pageNumbers: l.pageNumbers,
            remarks: updated,
          );
        }).toList();
        return p.copyWith(lines: lines);
      }).toList();
      state = state.copyWith(paragraphs: patched);
    } catch (e) {
      developer.log(
        '[LOAD] Remarks refresh error ($langCode): $e',
        name: 'epitaka.reader',
      );
    }
  }
}

/// Build a [TranslationRemark] from one `translation_remarks` row map.
TranslationRemark _remarkFromRow(Map<String, Object?> data) {
  return TranslationRemark(
    id: data['id'] as int?,
    paraId: data['para_id'] as int,
    lineId: data['line_id'] as int,
    pali: (data['pali'] as String?) ?? '',
    translation: (data['translation'] as String?) ?? '',
    conflict: (data['conflict'] as String?) ?? '',
    note: (data['note'] as String?) ?? '',
    sourceId: data['source_id'] as String?,
    createdAt: data['created_at'] as String?,
  );
}

/// Internal raw line data before merging translations.
class _RawLine {
  final int lineId;
  final String? paliText;

  /// All page numbers for this line, keyed by system code.
  final Map<String, String> pageNumbers;

  const _RawLine({
    required this.lineId,
    this.paliText,
    this.pageNumbers = const {},
  });
}

/// Provider that loads reader data for a given book (all paragraphs at once).
final readerDataProvider =
    StateNotifierProvider.family<ReaderDataNotifier, ReaderDataState, String>(
      (ref, bookId) => ReaderDataNotifier(ref, bookId),
    );

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Get the column name for the selected page numbering system.
String _pageColumnName(String system) {
  switch (system) {
    case 'vri':
      return 'vripage';
    case 'pts':
      return 'ptspage';
    case 'thai':
      return 'thaipage';
    case 'my':
      return 'mypage';
    default:
      return 'vripage';
  }
}
