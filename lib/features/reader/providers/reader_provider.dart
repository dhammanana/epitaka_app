import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';
import '../../../core/models/translation_version.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../data/book_link_data.dart';
import '../services/book_link_service.dart';

/// A single line within a paragraph (Pāli + translations per line).
class LineData {
  final int lineId;
  final String? paliText;
  final Map<String, String> translations;

  const LineData({
    required this.lineId,
    this.paliText,
    this.translations = const {},
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

/// A paragraph with multiple lines and optional page number.
class ParagraphData {
  final int paraId;
  final List<LineData> lines;

  /// The page number (e.g. VRI page) for this paragraph.
  final String? pageNumber;

  /// True if this paragraph starts a new page (page number differs from previous).
  final bool isPageStart;

  /// Optional heading that applies to this paragraph (exact match by paraId).
  final ParagraphHeading? heading;

  const ParagraphData({
    required this.paraId,
    this.lines = const [],
    this.pageNumber,
    this.isPageStart = false,
    this.heading,
  });

  ParagraphData copyWith({
    int? paraId,
    List<LineData>? lines,
    String? pageNumber,
    bool? isPageStart,
    ParagraphHeading? heading,
  }) {
    return ParagraphData(
      paraId: paraId ?? this.paraId,
      lines: lines ?? this.lines,
      pageNumber: pageNumber ?? this.pageNumber,
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

  ReaderDataNotifier(this._ref, this._bookId, {this._scrollToParaId})
      : super(ReaderDataState(bookId: _bookId)) {
    _loadBook();
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
    final sw = Stopwatch()..start();
    developer.log(
      '[LOAD] Starting full book load for bookId=$_bookId',
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

      await _loadAllParagraphs();

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
      state = state.copyWith(
        isLoading: false,
        isLoaded: true,
        error: e.toString(),
      );
    }
  }

  Future<void> _loadHeadings() async {
    final db = await _ref.read(epitakaDbProvider.future);
    final rows = await (db.select(db.headings)
          ..where((h) =>
              h.bookId.equals(_bookId) & h.level.isSmallerThan(const Constant(10)))
          ..orderBy([(h) => OrderingTerm(expression: h.paraId)]))
        .get();
    _headings = rows
        .map((row) => HeadingInfo(
              bookId: row.bookId,
              paraId: row.paraId,
              level: row.level,
              title: row.title,
              chapterLen: row.chapterLen,
              parent: row.parent,
              scId: row.scId,
            ))
        .toList();
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
      if (h.paraId! <= paraId) {
        best = ParagraphHeading(
          title: h.title ?? '',
          level: h.level ?? 1,
          paraId: h.paraId!,
        );
      } else {
        break; // headings are ordered by paraId ascending
      }
    }
    return best;
  }

  /// Load ALL paragraphs for this book in one shot (no pagination) and
  /// build the full [ParagraphData] list with translations.
  Future<void> _loadAllParagraphs() async {
    final db = await _ref.read(epitakaDbProvider.future);
    final settings = _ref.read(settingsProvider);

    final pageColumn = _pageColumnName(settings.pageNumberingSystem);

    final enabledLangs = settings.enabledTranslations.isNotEmpty
        ? settings.enabledTranslations.toList()
        : (settings.showTranslation ? [settings.primaryTranslationLang] : <String>[]);

    // ── Get book info ────────────────────────────────────────────────
    final bookSw = Stopwatch()..start();
    final books = await (db.select(db.books)
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
    final paraRows = await db.customSelect(
      'SELECT para_id FROM sentences WHERE book_id = ? '
      'GROUP BY para_id ORDER BY para_id',
      variables: [Variable(_bookId)],
    ).get();
    final paraIds =
        paraRows.map((r) => r.data['para_id'] as int).toList();
    paraSw.stop();
    developer.log(
      '[LOAD] para_id query: ${paraSw.elapsedMilliseconds}ms, '
      'paraCount=${paraIds.length}',
      name: 'epitaka.reader',
    );

    if (paraIds.isEmpty) {
      developer.log('[LOAD] No paragraphs found for bookId=$_bookId', name: 'epitaka.reader');
      state = state.copyWith(
        isLoading: false,
        isLoaded: true,
        hasMore: false,
        error: null,
      );
      return;
    }

    // ── Get sentences for all para_ids ───────────────────────────────
    final sentSw = Stopwatch()..start();
    final sentences = await (db.select(db.sentences)
          ..where(
              (s) => s.bookId.equals(_bookId) & s.paraId.isIn(paraIds))
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
    final groupSw = Stopwatch()..start();
    final paraLines = <int, List<_RawLine>>{};
    for (final s in sentences) {
      final pageValue = _getPageValue(s, pageColumn);
      paraLines.putIfAbsent(s.paraId, () => []);
      if (s.pali != null && s.pali!.trim().isNotEmpty) {
        paraLines[s.paraId]!.add(_RawLine(
          lineId: s.lineId,
          paliText: s.pali!,
          pageNumber: pageValue,
        ));
      } else if (pageValue != null && pageValue.isNotEmpty) {
        if (paraLines[s.paraId]!.isEmpty) {
          paraLines[s.paraId]!.add(_RawLine(
            lineId: s.lineId,
            paliText: null,
            pageNumber: pageValue,
          ));
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
    await Future.wait(enabledLangs.map((langCode) async {
      final settings = _ref.read(settingsProvider);
      final versionSuffix = settings.translationVersionMap[langCode];
      final isNissaya = versionSuffix != null &&
          TranslationFilenameParser.isNissaya(versionSuffix);

      if (isNissaya) {
        // ── Load from nissaya database ────────────────────────────
        final filename = TranslationFilenameParser.build(
          langCode,
          suffix: versionSuffix,
        );
        final nissayaDb =
            await _ref.read(nissayaDbByFilenameProvider(filename).future);
        if (nissayaDb == null) return;

        try {
          final nissayaData =
              await nissayaDb.getBookSentencesFormatted(_bookId);
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
        final lang = TranslationLanguage.fromCode(langCode);
        final translationDb =
            await _ref.read(translationDbProvider(lang).future);
        if (translationDb == null) return;

        final tSw = Stopwatch()..start();
        final transSentences = await (translationDb
                .select(translationDb.translationSentences)
              ..where((t) =>
                  t.bookId.equals(_bookId) & t.paraId.isIn(paraIds)))
            .get();
        tSw.stop();

        final langMap = <int, Map<int, String>>{};
        for (final t in transSentences) {
          if (t.translation == null) continue;
          langMap.putIfAbsent(t.paraId, () => {});
          langMap[t.paraId]!.update(
            t.lineId,
            (existing) => '$existing ${t.translation}',
            ifAbsent: () => t.translation!,
          );
        }
        transByLang[langCode] = langMap;

        developer.log(
          '[LOAD] Translation ($langCode): ${tSw.elapsedMilliseconds}ms, '
          'sentences=${transSentences.length}',
          name: 'epitaka.reader',
        );
      }
    }));
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

    for (final entry in paraLines.entries) {
      final paraId = entry.key;
      final rawLines = entry.value;

      String? pageNumber;
      for (final rl in rawLines) {
        if (rl.pageNumber != null && rl.pageNumber!.isNotEmpty) {
          pageNumber = rl.pageNumber;
          break;
        }
      }

      final isPageStart = pageNumber != null &&
          previousPageNumber != null &&
          pageNumber != previousPageNumber;

      // Match with heading
      final heading = _headingForPara(paraId);

      final lines = <LineData>[];
      for (final rl in rawLines) {
        final lineTranslations = <String, String>{};
        for (final lang in transByLang.keys) {
          final text = transByLang[lang]?[paraId]?[rl.lineId];
          if (text != null) lineTranslations[lang] = text;
        }
        lines.add(LineData(
          lineId: rl.lineId,
          paliText: rl.paliText,
          translations: lineTranslations,
        ));
      }

      paragraphs.add(ParagraphData(
        paraId: paraId,
        lines: lines,
        pageNumber: pageNumber ?? previousPageNumber,
        isPageStart: isPageStart,
        heading: heading,
      ));

      if (pageNumber != null) {
        previousPageNumber = pageNumber;
      }
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

    // ── Emit final state ─────────────────────────────────────────────
    state = state.copyWith(
      paragraphs: paragraphs,
      bookLinks: bookLinks,
      isLoading: false,
      isLoaded: true,
      hasMore: false, // no more pages — everything loaded
      error: null,
    );
  }
}

/// Internal raw line data before merging translations.
class _RawLine {
  final int lineId;
  final String? paliText;
  final String? pageNumber;

  const _RawLine({
    required this.lineId,
    this.paliText,
    this.pageNumber,
  });
}

/// Provider that loads reader data for a given book (all paragraphs at once).
final readerDataProvider = StateNotifierProvider.family<
    ReaderDataNotifier, ReaderDataState, String>(
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

/// Get the page value from a sentence row for the given column.
String? _getPageValue(dynamic s, String column) {
  switch (column) {
    case 'vripage':
      return (s as dynamic).vripage as String?;
    case 'ptspage':
      return (s as dynamic).ptspage as String?;
    case 'thaipage':
      return (s as dynamic).thaipage as String?;
    case 'mypage':
      return (s as dynamic).mypage as String?;
    default:
      return null;
  }
}
