part of 'reader_screen.dart';

/// In-book search state and methods for the reader screen.
///
/// Manages the in-book search bar toggle, database queries against
/// both Pāli and translation texts, match navigation, and the
/// search bar UI widget builder.
mixin ReaderSearchMixin on ConsumerState<ReaderScreen> {
  // ── In-book search state ────────────────────────────────────────────
  bool _showInBookSearch = false;
  String _inBookQuery = '';
  List<int> _inBookMatchParaIds = [];
  List<int> _inBookMatchLineIds = [];
  int _inBookMatchIndex = -1;
  final _inBookSearchController = TextEditingController();
  final _inBookSearchFocusNode = FocusNode();

  /// Get the query currently applied to ReadingParagraph for highlighting.
  String? get _effectiveSearchQuery {
    if (_showInBookSearch && _inBookQuery.isNotEmpty) return _inBookQuery;
    return null;
  }

  Timer? _inBookSearchTimer;
  String _lastInBookSearchQuery = '';

  // ═════════════════════════════════════════════════════════════════════
  // SEARCH LOGIC
  // ═════════════════════════════════════════════════════════════════════

  /// Run an in-book search on the `sentences` table with a `book_id`
  /// b-tree filter. Returns `(para_id, line_id)` pairs so the jump can
  /// scroll to the exact matching sentence.
  Future<void> _runInBookSearch(String query) async {
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;

    _lastInBookSearchQuery = query;

    if (query.trim().isEmpty) {
      setState(() {
        _inBookQuery = '';
        _inBookMatchParaIds = [];
        _inBookMatchLineIds = [];
        _inBookMatchIndex = -1;
      });
      return;
    }

    try {
      final words = query
          .trim()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();

      if (words.isEmpty) {
        setState(() {
          _inBookQuery = '';
          _inBookMatchParaIds = [];
          _inBookMatchLineIds = [];
          _inBookMatchIndex = -1;
        });
        return;
      }

      final seenKeys = <int>{};
      final matchParas = <int>[];
      final matchLines = <int>[];

      void addMatch(int paraId, int lineId) {
        final key = paraId * 1000000 + lineId;
        if (seenKeys.add(key)) {
          matchParas.add(paraId);
          matchLines.add(lineId);
        }
      }

      // 1. Search Pāli text from epitaka.db
      final epitakaDb = await ref.read(epitakaDbProvider.future);
      final paliConditions =
          words.map((_) => "pali LIKE '%' || ? || '%'").join(' AND ');

      final paliRows = await epitakaDb
          .customSelect(
            'SELECT para_id, line_id FROM sentences '
            'WHERE book_id = ? AND $paliConditions '
            'ORDER BY para_id, line_id LIMIT 500',
            variables: [
              Variable.withString(activeTab.bookId),
              for (final w in words) Variable.withString(w),
            ],
          )
          .get();

      for (final row in paliRows) {
        addMatch(row.data['para_id'] as int, row.data['line_id'] as int);
      }

      if (_lastInBookSearchQuery != query) return;

      // 2. Search translation texts from active translation DBs
      final settings = ref.read(settingsProvider);
      final enabledLangs = settings.enabledTranslations.isNotEmpty
          ? settings.enabledTranslations.toList()
          : (settings.showTranslation
              ? [settings.primaryTranslationLang]
              : <String>[]);

      for (final langCode in enabledLangs) {
        if (_lastInBookSearchQuery != query) return;
        try {
          final lang = TranslationLanguage.fromCode(langCode);
          final transDb = await ref.read(translationDbProvider(lang).future);
          if (transDb == null) continue;

          final transConditions =
              words.map((_) => "translation LIKE '%' || ? || '%'").join(' AND ');

          final transRows = await transDb
              .customSelect(
                'SELECT para_id, line_id FROM sentences '
                'WHERE book_id = ? AND $transConditions '
                'ORDER BY para_id, line_id LIMIT 500',
                variables: [
                  Variable.withString(activeTab.bookId),
                  for (final w in words) Variable.withString(w),
                ],
              )
              .get();

          for (final row in transRows) {
            addMatch(row.data['para_id'] as int, row.data['line_id'] as int);
          }
        } catch (_) {
          // Translation db may not exist — skip
        }
      }

      if (_lastInBookSearchQuery != query) return;

      setState(() {
        _inBookQuery = query;
        _inBookMatchParaIds = matchParas;
        _inBookMatchLineIds = matchLines;
        _inBookMatchIndex = matchParas.isEmpty ? -1 : 0;
      });

      if (matchParas.isNotEmpty) _jumpToInBookMatch(0);
    } catch (e) {
      debugPrint('[IN-BOOK SEARCH] Error: $e');
      if (_lastInBookSearchQuery == query) {
        setState(() {
          _inBookQuery = '';
          _inBookMatchParaIds = [];
          _inBookMatchLineIds = [];
          _inBookMatchIndex = -1;
        });
      }
    }
  }

  /// Jump to the [_inBookMatchParaIds] at [index].
  void _jumpToInBookMatch(int index) {
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;
    if (index < 0 || index >= _inBookMatchParaIds.length) return;

    setState(() => _inBookMatchIndex = index);
    final lineId = index < _inBookMatchLineIds.length
        ? _inBookMatchLineIds[index]
        : 1;
    _jumpToParagraph(
      activeTab.bookId,
      _inBookMatchParaIds[index],
      animate: true,
      lineId: lineId,
    );
  }

  void _toggleInBookSearch() {
    setState(() {
      _showInBookSearch = !_showInBookSearch;
      if (!_showInBookSearch) {
        _inBookQuery = '';
        _inBookMatchParaIds = [];
        _inBookMatchLineIds = [];
        _inBookMatchIndex = -1;
        _inBookSearchController.clear();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _inBookSearchFocusNode.requestFocus();
        });
      }
    });
  }

  // ═════════════════════════════════════════════════════════════════════
  // IN-BOOK SEARCH BAR BUILDER
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildInBookSearchBar(ColorScheme colors) {
    return ReaderInBookSearchBar(
      colors: colors,
      controller: _inBookSearchController,
      focusNode: _inBookSearchFocusNode,
      matchCount: _inBookMatchParaIds.length,
      currentMatchIndex: _inBookMatchIndex,
      query: _inBookQuery,
      onClose: _toggleInBookSearch,
      onQueryChanged: (v) {
        _inBookSearchTimer?.cancel();
        _inBookSearchTimer = Timer(
          const Duration(milliseconds: 200),
          () => _runInBookSearch(v),
        );
      },
      onSubmitted: (v) {
        _inBookSearchTimer?.cancel();
        _runInBookSearch(v);
      },
      onPrevious: () {
        if (_inBookMatchParaIds.isEmpty) return;
        final prev =
            (_inBookMatchIndex - 1).clamp(0, _inBookMatchParaIds.length - 1);
        _jumpToInBookMatch(prev);
      },
      onNext: () {
        if (_inBookMatchParaIds.isEmpty) return;
        final next =
            (_inBookMatchIndex + 1).clamp(0, _inBookMatchParaIds.length - 1);
        _jumpToInBookMatch(next);
      },
    );
  }
}
