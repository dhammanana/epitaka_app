import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/dpd_database.dart';
import '../../../core/providers/dpd_provider.dart';
import '../../../core/utils/velthuis.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

void showDictionarySheet(BuildContext context, String word) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // This allows the 85% height to work
    backgroundColor: Colors.transparent,
    builder: (_) => DictionarySheet(initialWord: word),
  );
}

// ── Sheet State ────────────────────────────────────────────────────────────

/// What the sheet is currently showing.
enum _SheetView { search, results, entry }

// ── Main Sheet Widget ──────────────────────────────────────────────────────

/// A modal bottom sheet for looking up words in the DPD dictionary.
class DictionarySheet extends ConsumerStatefulWidget {
  final String initialWord;

  const DictionarySheet({super.key, this.initialWord = ''});

  @override
  ConsumerState<DictionarySheet> createState() => _DictionarySheetState();
}

class _DictionarySheetState extends ConsumerState<DictionarySheet> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  Timer? _debounce;
  bool _isConverting = false;

  _SheetView _view = _SheetView.search;
  String _query = '';
  DpdEntryData? _selectedEntry;

  // Search History State
  final List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialWord.trim();
    if (initial.isNotEmpty) {
      _searchController.text = initial;
      _query = initial;
      _addToHistory(initial);
      _performSearch(initial);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
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
      if (_searchHistory.length > 15) {
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
      _searchController.value = TextEditingValue(
        text: converted,
        selection: TextSelection.collapsed(offset: converted.length),
      );
      _isConverting = false;
    }

    final trimmed = converted.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _query = '';
        _view = _SheetView.search;
        _selectedEntry = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _query = trimmed;
        _view = _SheetView.results;
        _selectedEntry = null;
      });
    });
  }

  void _performSearch(String value) {
    final converted = velthuis(value).trim();
    _addToHistory(converted);
    setState(() {
      _query = converted;
      _view = _SheetView.results;
      _selectedEntry = null;
    });
    _focusNode.unfocus();
  }

  void _openEntry(DpdEntryData entry) {
    _addToHistory(entry.headword.lemma1);
    setState(() {
      _selectedEntry = entry;
      _view = _SheetView.entry;
    });
  }

  void _goBack() {
    setState(() {
      _selectedEntry = null;
      if (_query.isNotEmpty) {
        _view = _SheetView.results;
      } else {
        _view = _SheetView.search;
      }
    });
  }

  void _lookupWord(String word) {
    final converted = velthuis(word);
    _searchController.text = converted;
    _addToHistory(converted);
    setState(() {
      _query = converted;
      _selectedEntry = null;
      _view = _SheetView.results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      // 1. Use sizeOf to prevent 60fps layout thrashing
      height: MediaQuery.sizeOf(context).height * 0.88, 
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusSheet)),
      ),
      // 2. Use a transparent Scaffold to handle the keyboard smoothly
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true, // This does the magic!
        body: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Search bar row
            Padding(
              padding: const EdgeInsets.fromLTRB(
                4,
                AppDimensions.sm,
                AppDimensions.marginMobile - 8,
                0,
              ),
              child: Row(
                children: [
                  if (_view == _SheetView.entry)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: colors.onSurfaceVariant,
                      onPressed: _goBack,
                    ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search Pāḷi…',
                        prefixIcon:
                            Icon(Icons.search, color: colors.onSurfaceVariant),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                  _focusNode.requestFocus();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: colors.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusXl),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.md,
                          vertical: 12,
                        ),
                      ),
                      style: AppTypography.bodyTranslation.copyWith(
                        color: colors.onSurface,
                        fontSize: 16,
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: _performSearch,
                    ),
                  ),
                ],
              ),
            ),

            // Search History Row
            if (_searchHistory.isNotEmpty && _view != _SheetView.entry)
              Container(
                height: 40,
                margin: const EdgeInsets.only(top: 8, left: 16, right: 16),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _searchHistory.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return ActionChip(
                      label: Text(_searchHistory[index]),
                      labelStyle: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      backgroundColor: colors.surfaceContainerHighest,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onPressed: () {
                        _searchController.text = _searchHistory[index];
                        _performSearch(_searchHistory[index]);
                      },
                    );
                  },
                ),
              ),

            const SizedBox(height: AppDimensions.sm),
            const Divider(height: 1),

            // Content area
            Expanded(
              child: _buildContent(colors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colors) {
    switch (_view) {
      case _SheetView.search:
        return _buildIdleState(colors);
      case _SheetView.results:
        return _buildResults(colors);
      case _SheetView.entry:
        if (_selectedEntry == null) return const SizedBox.shrink();
        return _EntryDetailView(
          entry: _selectedEntry!,
          colors: colors,
          onWordTap: _lookupWord,
        );
    }
  }

  Widget _buildIdleState(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book,
            size: 56,
            color: colors.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppDimensions.md),
          Text(
            'Digital Pāli Dictionary',
            style: AppTypography.headlineSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'Search for a Pāḷi word to see\ndefinitions, grammar, and more',
            textAlign: TextAlign.center,
            style: AppTypography.bodyTranslation.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(ColorScheme colors) {
    return ref.watch(dpdSearchProvider(_query)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error: $e',
                style: AppTypography.bodyTranslation.copyWith(
                  color: colors.error,
                ),
              ),
            ),
          ),
          data: (results) {
            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: ref.watch(dpdDeconstructionProvider(_query)).when(
                        data: (decon) {
                          if (decon == null || decon.candidates.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return _buildDeconstructionInline(decon, colors);
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                ),
                if (results.isEmpty)
                  SliverToBoxAdapter(
                    child: _buildEmptyState(colors),
                  ),
                if (results.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.marginMobile,
                      AppDimensions.sm,
                      AppDimensions.marginMobile,
                      32,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final result = results[index];
                          return _SearchResultCard(
                            result: result,
                            onTap: () => _openEntryFromSearch(result),
                            colors: colors,
                          );
                        },
                        childCount: results.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
  }

  Widget _buildDeconstructionInline(
      DpdDeconstructionData decon, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.call_split, size: 16, color: colors.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Possible deconstruction',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...decon.candidates.map((candidate) {
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: candidate.tokens.map((token) {
                return ActionChip(
                  label: Text(token),
                  labelStyle: AppTypography.bodyTranslation.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  backgroundColor: colors.primary.withValues(alpha: 0.1),
                  side: BorderSide(
                    color: colors.primary.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onPressed: () => _lookupWord(token),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _openEntryFromSearch(DpdSearchResult result) async {
    try {
      final entry = await ref.read(dpdEntryProvider(result.id).future);
      if (entry != null && mounted) {
        _openEntry(entry);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load entry: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildEmptyState(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: colors.outlineVariant,
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              'No direct matches found for "$_query"',
              style: AppTypography.bodyTranslation.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Entry Detail View ──────────────────────────────────────────────────────

class _EntryDetailView extends StatefulWidget {
  final DpdEntryData entry;
  final ColorScheme colors;
  final ValueChanged<String> onWordTap;

  const _EntryDetailView({
    required this.entry,
    required this.colors,
    required this.onWordTap,
  });

  @override
  State<_EntryDetailView> createState() => _EntryDetailViewState();
}

class _EntryDetailViewState extends State<_EntryDetailView> {
  String? _activeTab;

  /// Custom utility to parse bold and italic HTML tags (<b>, <i>) safely into a RichText widget
  Widget _buildHtmlText(String htmlText, TextStyle baseStyle) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(</?[bi]>)', caseSensitive: false);
    final matches = regex.allMatches(htmlText);

    int lastMatchEnd = 0;
    bool isBold = false;
    bool isItalic = false;

    void addSpan(String text) {
      if (text.isEmpty) return;
      spans.add(TextSpan(
        text: text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : null,
          fontStyle: isItalic ? FontStyle.italic : null,
        ),
      ));
    }

    for (final match in matches) {
      final preText = htmlText.substring(lastMatchEnd, match.start);
      addSpan(preText);

      final tag = match.group(0)!.toLowerCase();
      if (tag == '<b>') {
        isBold = true;
      } else if (tag == '</b>') {
        isBold = false;
      } else if (tag == '<i>') {
        isItalic = true;
      } else if (tag == '</i>') {
        isItalic = false;
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < htmlText.length) {
      addSpan(htmlText.substring(lastMatchEnd));
    }

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hw = widget.entry.headword;
    final colors = widget.colors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.md,
        AppDimensions.marginMobile,
        40,
      ),
      children: [
        // ── Headword ─────────────────────────────────────────────────
        Text(
          hw.lemma1,
          style: AppTypography.displayPali.copyWith(
            color: colors.onSurface,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (hw.lemma2 != null && hw.lemma2!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            hw.lemma2!,
            style: AppTypography.bodyTranslation.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],

        // ── Definition Box (Cyan outline style) ───────────────────────
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colors.primary,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Line 1: pos + meaning
              RichText(
                text: TextSpan(
                  style: AppTypography.bodyTranslation.copyWith(
                    color: colors.onSurface,
                    fontSize: 16,
                  ),
                  children: [
                    if (hw.pos != null && hw.pos!.isNotEmpty)
                      TextSpan(
                        text: '${hw.pos}. ',
                        style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.bold),
                      ),
                    if (hw.meaning1 != null && hw.meaning1!.isNotEmpty)
                      TextSpan(
                        text: '${hw.meaning1} ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    if (hw.meaning2 != null && hw.meaning2!.isNotEmpty)
                      TextSpan(
                        text: '; ${hw.meaning2}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),

              // Line 2: lit. meaning + construction
              if ((hw.meaningLit != null && hw.meaningLit!.isNotEmpty) ||
                  (hw.construction != null && hw.construction!.isNotEmpty)) ...[
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: AppTypography.bodyTranslation.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 15,
                    ),
                    children: [
                      if (hw.meaningLit != null && hw.meaningLit!.isNotEmpty)
                        TextSpan(
                          text: 'lit. ${hw.meaningLit} ',
                        ),
                      if (hw.construction != null &&
                          hw.construction!.isNotEmpty)
                        TextSpan(
                          text: '[${hw.construction}] ✓',
                        ),
                    ],
                  ),
                ),
              ],

              // Line 3: Root and Root meaning
              if (widget.entry.root != null &&
                  widget.entry.root!.rootMeaning!.isNotEmpty) ...[
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: AppTypography.bodyTranslation.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 14,
                    ),
                    children: [
                      const TextSpan(
                          text: 'root: ',
                          style: TextStyle(fontStyle: FontStyle.italic)),
                      TextSpan(
                        text: '${hw.rootKey ?? ''} ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: '(${widget.entry.root!.rootMeaning})'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Action Tabs Row ──────────────────────────────────────────
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (widget.entry.hasGrammarDetails) _buildTab('grammar'),
            if (hw.example1 != null && hw.example1!.isNotEmpty)
              _buildTab('example'),
            if (widget.entry.rootFamilyKeys.isNotEmpty)
              _buildTab('root family'),
            if (widget.entry.compoundFamilyItems.isNotEmpty)
              _buildTab('compound family'),
            _buildTab('declension'),
            if (hw.commentary != null && hw.commentary!.isNotEmpty)
              _buildTab('commentary'),
          ],
        ),

        // ── Active Tab Content Area ──────────────────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _activeTab == null
              ? const SizedBox.shrink()
              : Container(
                  key: ValueKey(_activeTab),
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: _buildActiveTabContent(),
                ),
        ),
      ],
    );
  }

  Widget _buildTab(String label) {
    final isActive = _activeTab == label;
    final colors = widget.colors;

    return InkWell(
      onTap: () => setState(() => _activeTab = isActive ? null : label),
      borderRadius: BorderRadius.circular(4), // Square styling
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? colors.primary.withValues(alpha: 0.8)
              : colors.primary,
          borderRadius: BorderRadius.circular(4), // Square styling
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: colors.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    final colors = widget.colors;
    final hw = widget.entry.headword;
    final entry = widget.entry;

    switch (_activeTab) {
      case 'grammar':
        return _buildGrammarTable(hw, entry.root, colors);
      case 'example':
        return _buildExamples(hw, colors);
      case 'root family':
        return _buildFamilySection(entry.rootFamilyKeys, colors);
      case 'compound family':
        return _buildFamilySection(entry.compoundFamilyItems, colors);
      case 'declension':
        return Text(
          "Declension features using Pattern: ${hw.pattern ?? '-'}, Stem: ${hw.stem ?? '-'}\nDetailed declension tables mapping coming soon.",
          style: AppTypography.bodyTranslation.copyWith(
            color: colors.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        );
      case 'commentary':
        return _buildHtmlText(
          hw.commentary!,
          AppTypography.bodyTranslation.copyWith(
            color: colors.onSurface,
            fontSize: 15,
            height: 1.6,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Tab Builders ─────────────────────────────────────────────────────

  Widget _buildGrammarTable(DpdHeadword hw, DpdRoot? root, ColorScheme colors) {
    final rows = <_LabelValue>[];

    void add(String label, String? value) {
      if (value != null && value.isNotEmpty) {
        rows.add(_LabelValue(label, value));
      }
    }

    add('Part of speech', hw.pos);
    add('Grammar', hw.grammar);
    add('Derived from', hw.derivedFrom);
    add('Negation', hw.neg);
    add('Verb type', hw.verb);
    add('Transitivity', hw.trans);
    add('Plus case', hw.plusCase);
    add('Stem', hw.stem);
    add('Pattern', hw.pattern);
    add('Suffix', hw.suffix);
    add('Compound type', hw.compoundType);
    add('Root key', hw.rootKey);
    add('Root sign', hw.rootSign);
    add('Root base', hw.rootBase);

    if (root != null) {
      add('Root group', root.rootGroup);
      add('Root meaning', root.rootMeaning);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows.map((r) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  r.label,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  r.value,
                  style: AppTypography.bodyTranslation.copyWith(
                    color: colors.onSurface,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExamples(DpdHeadword hw, ColorScheme colors) {
    final children = <Widget>[];

    if (hw.example1 != null && hw.example1!.isNotEmpty) {
      children.add(_buildExampleBlock(
        example: hw.example1!,
        source: hw.source1,
        sutta: hw.sutta1,
        colors: colors,
      ));
    }

    if (hw.example2 != null && hw.example2!.isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 12));
      children.add(_buildExampleBlock(
        example: hw.example2!,
        source: hw.source2,
        sutta: hw.sutta2,
        colors: colors,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildExampleBlock({
    required String example,
    String? source,
    String? sutta,
    required ColorScheme colors,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Using our html builder instead of Text
        _buildHtmlText(
          example,
          AppTypography.bodyPali.copyWith(
            color: colors.onSurface,
            fontSize: 15,
            height: 1.6,
          ),
        ),
        if (source != null || sutta != null) ...[
          const SizedBox(height: 4),
          Text(
            [source, sutta].whereType<String>().join(' · '),
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFamilySection(List<String> items, ColorScheme colors) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.map((item) {
        return ActionChip(
          label: Text(
            item,
            style: AppTypography.labelSmall.copyWith(
              color: colors.primary,
            ),
          ),
          onPressed: () => widget.onWordTap(item),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
          backgroundColor: colors.primary.withValues(alpha: 0.1),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4), // Match square styling
          ),
        );
      }).toList(),
    );
  }
}

// ── Supporting Widgets ─────────────────────────────────────────────────────

/// Search result card showing summary info.
class _SearchResultCard extends StatelessWidget {
  final DpdSearchResult result;
  final VoidCallback onTap;
  final ColorScheme colors;

  const _SearchResultCard({
    required this.result,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: colors.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.lemma1,
                      style: AppTypography.headlineSmall.copyWith(
                        color: colors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (result.summaryLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        result.summaryLine,
                        style: AppTypography.bodyTranslation.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple label-value pair for grammar table.
class _LabelValue {
  final String label;
  final String value;
  const _LabelValue(this.label, this.value);
}