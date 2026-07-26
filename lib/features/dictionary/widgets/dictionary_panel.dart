import 'dart:async';

import 'package:epitaka/shared/providers/side_panel_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/dictionary_books_provider.dart';
import '../../../core/providers/dpd_dictionary_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/velthuis.dart';
import 'dictionary_search_shared.dart';
import 'pali_definition_card.dart';

/// A dictionary panel that can be shown in a sidebar or as a standalone
/// widget. When used in the right sidebar on desktop, it communicates
/// with [SidePanelProvider] for word lookup navigation.
class DictionaryPanel extends ConsumerStatefulWidget {
  final String initialWord;

  /// When true, the search text field is focused once the panel is built.
  /// Used by the Ctrl/Cmd + D shortcut so the user can type immediately.
  /// This is intentionally NOT triggered on word double-click (which opens
  /// the dictionary with a word already filled in) to avoid popping up the
  /// on-screen keyboard on touch devices.
  final bool autoFocus;

  const DictionaryPanel({
    super.key,
    this.initialWord = '',
    this.autoFocus = false,
  });

  @override
  ConsumerState<DictionaryPanel> createState() => _DictionaryPanelState();
}

class _DictionaryPanelState extends ConsumerState<DictionaryPanel> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  Timer? _debounce;
  bool _isConverting = false;

  String _query = '';
  final List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialWord.trim();
    if (initial.isNotEmpty) {
      _searchController.text = initial;
      _query = initial;
      _addToHistory(initial);
    } else if (widget.autoFocus) {
      // Focus the search field after the first frame so the keyboard can show.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Keep the panel in sync with the dictionary word coming from the
    // reader (e.g. a double-clicked word routed here when pinned on desktop).
    final panelData = ref.watch(sidePanelProvider).right.panelData;
    if (panelData != null && panelData.trim().isNotEmpty) {
      final word = panelData.trim();
      if (word != _query) {
        _searchController.text = word;
        _initiateSearch(word);
      }
    }
  }

  @override
  void didUpdateWidget(DictionaryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newWord = widget.initialWord.trim();
    if (newWord.isNotEmpty && newWord != oldWidget.initialWord.trim()) {
      _searchController.text = newWord;
      _initiateSearch(newWord);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _addToHistory(String word) {
    final w = word.trim();
    if (w.isEmpty) return;
    setState(() {
      _searchHistory.remove(w);
      _searchHistory.insert(0, w);
      if (_searchHistory.length > 10) {
        _searchHistory.removeLast();
      }
    });
  }

  void _onSearchChanged(String value) {
    if (_isConverting) return;
    _debounce?.cancel();

    final converted = velthuis(value);
    if (converted != value && converted.trim().isNotEmpty) {
      _isConverting = true;
      _searchController.value = convertedTextEditingValue(
        _searchController.value,
      );
      _isConverting = false;
    }

    final trimmed = converted.trim();
    if (trimmed.isEmpty) {
      setState(() => _query = '');
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _initiateSearch(trimmed);
    });
  }

  void _performSearch(String value) {
    final converted = velthuis(value).trim();
    _focusNode.unfocus();
    _initiateSearch(converted);
  }

  void _initiateSearch(String word) {
    if (word.isEmpty) return;
    _addToHistory(word);
    setState(() => _query = word);
  }

  void _selectWord(String word) {
    final converted = velthuis(word).trim();
    if (converted.isEmpty) return;
    _searchController.text = converted;
    _initiateSearch(converted);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Compact search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.sm,
            AppDimensions.sm,
            AppDimensions.sm,
            0,
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search Pāḷi…',
              isDense: true,
              prefixIcon: Icon(
                Icons.search,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: colors.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.sm,
                vertical: 8,
              ),
            ),
            style: AppTypography.labelMedium.copyWith(
              color: colors.onSurface,
              fontSize: 14,
            ),
            onChanged: _onSearchChanged,
            onSubmitted: _performSearch,
          ),
        ),

        // Search history chips
        if (_searchHistory.isNotEmpty)
          Container(
            height: 32,
            margin: const EdgeInsets.only(top: 4, left: 8, right: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _searchHistory.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                return ActionChip(
                  label: Text(_searchHistory[index]),
                  labelStyle: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 10,
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: colors.surfaceContainerHighest,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onPressed: () {
                    _searchController.text = _searchHistory[index];
                    _performSearch(_searchHistory[index]);
                  },
                );
              },
            ),
          ),

        const SizedBox(height: 4),
        const Divider(height: 1),

        // Results
        Expanded(
          child: _query.isEmpty
              ? _buildIdleState(colors)
              : _buildResults(colors),
        ),
      ],
    );
  }

  Widget _buildIdleState(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book,
            size: 40,
            color: colors.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'Dictionary',
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(ColorScheme colors) {
    return ref
        .watch(dpdDictionaryLookupProvider(_query))
        .when(
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error: $e',
                style: AppTypography.labelSmall.copyWith(color: colors.error),
              ),
            ),
          ),
          data: (lookup) {
            if (lookup.hasHeadwords || lookup.hasDeconstructor) {
              return _buildDictionaryResults(colors, lookup);
            }
            return _buildPrefixSuggestions(colors);
          },
        );
  }

  Widget _buildPrefixSuggestions(ColorScheme colors) {
    return ref
        .watch(dpdDictionarySearchProvider(_query))
        .when(
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error: $e',
                style: AppTypography.labelSmall.copyWith(color: colors.error),
              ),
            ),
          ),
          data: (results) {
            if (results.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 36,
                        color: colors.outlineVariant,
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      Text(
                        'No matches for "$_query"',
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppDimensions.sm),
              children: [
                Text(
                  'Did you mean…',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                ...results.map(
                  (r) => SuggestionTile(
                    word: r.lemma1,
                    meaningPreview: r.meaningHtml,
                    onTap: () => _selectWord(r.lemma1),
                    colors: colors,
                  ),
                ),
              ],
            );
          },
        );
  }

  Widget _buildDictionaryResults(ColorScheme colors, DpdFullLookup lookup) {
    String searchWord = _query;
    if (lookup.headwords.isNotEmpty) {
      searchWord = lookup.headwords.first.cleanLemma1;
    }

    return Consumer(
      builder: (context, ref, _) {
        final booksAsync = ref.watch(dictionaryBooksNotifierProvider);
        return booksAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (_, _) => const SizedBox.shrink(),
          data: (books) {
            final enabledBooks = books.where((b) => b.userChoice).toList();
            final children = <Widget>[];
            for (final book in enabledBooks) {
              if (book.id == 11) {
                if (lookup.hasHeadwords || lookup.hasDeconstructor) {
                  children.add(
                    _DpdSection(
                      colors: colors,
                      lookup: lookup,
                      onWordTap: _selectWord,
                    ),
                  );
                }
              } else if (book.id == 100) {
                children.add(
                  PaliDefinitionSection(
                    searchWord: searchWord,
                    bookName: book.name,
                    colors: colors,
                  ),
                );
              } else {
                children.add(
                  DictDefinitionSection(
                    bookId: book.id,
                    bookName: book.name,
                    searchWord: searchWord,
                    colors: colors,
                  ),
                );
              }
            }
            return ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppDimensions.sm),
              children: [...children, const SizedBox(height: 24)],
            );
          },
        );
      },
    );
  }
}

// ── DPD Section ────────────────────────────────────────────────────────

class _DpdSection extends ConsumerWidget {
  final ColorScheme colors;
  final DpdFullLookup lookup;
  final ValueChanged<String> onWordTap;

  const _DpdSection({
    required this.colors,
    required this.lookup,
    required this.onWordTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final pali = settings.typography.pali;
    final paliFontFamily = pali.fontFamily.fontFamily;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_stories, size: 14, color: colors.primary),
            const SizedBox(width: 4),
            Text(
              'DPD Dictionary',
              style: AppTypography.labelSmall.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
                fontSize: (pali.fontSize * 0.6).clamp(10.0, 16.0),
                fontFamily: paliFontFamily,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          lookup.searchedKey,
          style: AppTypography.headlineSmall.copyWith(
            color: colors.onSurface,
            fontSize: (pali.fontSize * 1.0).clamp(16.0, 30.0),
            fontWeight: FontWeight.bold,
            fontFamily: paliFontFamily,
          ),
        ),
        const SizedBox(height: 6),
        ...lookup.headwords.map(
          (hw) => DpdHeadwordCard(
            lemma: hw.lemma1,
            meaningHtml: hw.meaningHtml,
            colors: colors,
            onWordTap: onWordTap,
            compact: true,
          ),
        ),
      ],
    );
  }
}
