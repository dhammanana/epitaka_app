import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';

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
    );
  }
}

/// StateNotifier that loads paragraphs in pages (200 at a time) for a single book.
class ReaderDataNotifier extends StateNotifier<ReaderDataState> {
  final Ref _ref;
  final String _bookId;
  int _offset = 0;
  int? _scrollToParaId;
  static const int _pageSize = 200;

  /// All headings for this book (loaded once on first page load).
  List<HeadingInfo>? _headings;

  ReaderDataNotifier(this._ref, this._bookId, {this._scrollToParaId})
      : super(ReaderDataState(bookId: _bookId)) {
    _loadFirstPage();
  }

  int? get scrollTarget => _scrollToParaId;

  void clearScrollTarget() {
    _scrollToParaId = null;
  }

  Future<void> ensureLoaded(int paraId) async {
    while (state.hasMore &&
        state.paragraphs.every((p) => p.paraId != paraId)) {
      await loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    state = state.copyWith(isLoading: true);
    try {
      // Load headings once
      if (_headings == null) {
        await _loadHeadings();
      }
      await _loadPage(0);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoaded: true,
        error: e.toString(),
      );
    }

    if (_scrollToParaId != null && state.paragraphs.isNotEmpty) {
      final containsTarget =
          state.paragraphs.any((p) => p.paraId == _scrollToParaId);
      if (!containsTarget && state.hasMore) {
        _loadUntilTarget();
      }
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
    // Binary search for the heading at this exact paraId
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

  Future<void> _loadUntilTarget() async {
    while (
        _scrollToParaId != null && state.hasMore && state.paragraphs.isNotEmpty) {
      final containsTarget =
          state.paragraphs.any((p) => p.paraId == _scrollToParaId);
      if (containsTarget) break;
      try {
        await _loadPage(_offset);
      } catch (e) {
        state = state.copyWith(error: e.toString());
        break;
      }
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    if (!state.isLoaded) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      await _loadPage(_offset);
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<void> _loadPage(int offset) async {
    final db = await _ref.read(epitakaDbProvider.future);
    final settings = _ref.read(settingsProvider);

    final pageColumn = _pageColumnName(settings.pageNumberingSystem);

    final enabledLangs = settings.enabledTranslations.isNotEmpty
        ? settings.enabledTranslations.toList()
        : (settings.showTranslation ? [settings.primaryTranslationLang] : <String>[]);

    // Get book info once on first load
    if (offset == 0 && state.bookName == null) {
      final books = await (db.select(db.books)
            ..where((b) => b.bookId.equals(_bookId))
            ..limit(1))
          .get();
      final book = books.isNotEmpty ? books.first : null;
      if (book != null) {
        state = state.copyWith(
          bookName: book.bookName,
          bookDescription: book.description,
        );
      }
    }

    // Get distinct para_ids with pagination
    final paraRows = await db.customSelect(
      'SELECT para_id FROM sentences WHERE book_id = ? '
      'GROUP BY para_id ORDER BY para_id LIMIT ? OFFSET ?',
      variables: [Variable(_bookId), Variable(_pageSize), Variable(offset)],
    ).get();
    final paraIds =
        paraRows.map((r) => r.data['para_id'] as int).toList();

    if (paraIds.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        isLoaded: true,
        hasMore: false,
        error: null,
      );
      return;
    }

    // Get sentences for these para_ids
    final sentences = await (db.select(db.sentences)
          ..where(
              (s) => s.bookId.equals(_bookId) & s.paraId.isIn(paraIds))
          ..orderBy([
            (s) => OrderingTerm(expression: s.paraId),
            (s) => OrderingTerm(expression: s.lineId),
          ]))
        .get();

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

    // Load all enabled translations in parallel
    final transByLang = <String, Map<int, Map<int, String>>>{};
    await Future.wait(enabledLangs.map((langCode) async {
      final lang = TranslationLanguage.fromCode(langCode);
      final translationDb =
          await _ref.read(translationDbProvider(lang).future);
      if (translationDb == null) return;

      final transSentences = await (translationDb
              .select(translationDb.translationSentences)
            ..where((t) =>
                t.bookId.equals(_bookId) & t.paraId.isIn(paraIds)))
          .get();

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
    }));

    // Build paragraphs with lines
    final newParagraphs = <ParagraphData>[];
    String? previousPageNumber;
    if (offset > 0 && state.paragraphs.isNotEmpty) {
      previousPageNumber = state.paragraphs.last.pageNumber;
    }

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

      newParagraphs.add(ParagraphData(
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

    _offset = offset + _pageSize;

    final hasMore = paraIds.length >= _pageSize;
    state = state.copyWith(
      paragraphs: [...state.paragraphs, ...newParagraphs],
      isLoading: false,
      isLoadingMore: false,
      isLoaded: true,
      hasMore: hasMore,
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

/// Provider that loads reader data in pages for a given book.
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
