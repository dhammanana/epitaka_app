import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dictionary/providers/dictionary_font_scale_provider.dart';
import '../../dictionary/widgets/page_anchors.dart';
import '../models/dpd_source_id.dart';
import '../models/lookup_results.dart';
import '../providers/dictionary_list_provider.dart';
import '../providers/dpd_lookup_provider.dart';
import '../providers/dpd_settings_provider.dart';
import '../providers/summary_provider.dart';
import 'inline_entry_card.dart';
import 'inline_root_card.dart';
import 'root_summary_card.dart';
import 'secondary/secondary_result_cards.dart';
import 'tap_search_wrapper.dart';

/// The DPD result stack for one lookup: headwords, roots and the secondary
/// sources, or the run of them in [sources]. A plain column, because it sits inside the dictionary sheet's own
/// scroll view. Built from the DPD app's `SearchResultsBody` and
/// `SplitResultsList`; partial and fuzzy tiers are not shown.
class DpdResultsView extends ConsumerStatefulWidget {
  const DpdResultsView({
    super.key,
    required this.lookup,
    required this.level,
    required this.onWordTap,
    this.sources,
    this.logFirstPaint = true,
    this.anchors,
  });

  final DpdLookup lookup;

  /// The `kDpdSources` ids to draw, in order. The settings list can put other
  /// dictionaries between two DPD sources, so the page draws one view per run
  /// of neighbours. Null draws all of them in the default order.
  final List<String>? sources;

  /// Where the summary's lines jump to: each card is given the key for its id
  /// (`hw_<id>`, `root_<root>`, `sec_<source>#<n>`). Null for no jumping.
  final PageAnchors? anchors;

  /// False for the partial and fuzzy tiers, which are not the lookup's own
  /// first paint.
  final bool logFirstPaint;

  /// Passed in, not watched here, so the sheet and panel can put it in their
  /// memo keys.
  final DictionaryLevel level;

  /// A word tapped inside an entry, already cleaned and in Roman script.
  final void Function(String word) onWordTap;

  @override
  ConsumerState<DpdResultsView> createState() => _DpdResultsViewState();
}

class _DpdResultsViewState extends ConsumerState<DpdResultsView> {
  @override
  void initState() {
    super.initState();
    if (!widget.logFirstPaint) return;
    final lookup = widget.lookup;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ms = lookup.timer.elapsedMicroseconds / 1000;
      debugPrint(
        '[DPD] first paint word="${lookup.query}" ms=${ms.toStringAsFixed(1)}',
      );
    });
  }

  Widget _secondaryCard(Object result) => switch (result) {
    DeconstructorResult r => DeconstructorCard(result: r),
    GrammarDictResult r => GrammarDictCard(result: r),
    AbbreviationResult r => AbbreviationCard(result: r),
    AbbreviationOtherResult r => AbbreviationOtherCard(result: r),
    HelpResult r => HelpCard(result: r),
    EpdResult r => EpdCard(result: r),
    VariantResult r => VariantCard(result: r),
    SpellingResult r => SpellingCard(result: r),
    SeeResult r => SeeCard(result: r),
    _ => const SizedBox.shrink(),
  };

  /// [card] under the anchor for [id], when the page has anchors.
  Widget _anchored(String id, Widget card) => widget.anchors == null
      ? card
      : KeyedSubtree(key: widget.anchors!.keyFor(id), child: card);

  @override
  Widget build(BuildContext context) {
    final lookup = widget.lookup;
    // At Saṅkhitta the summary at the top of the page is the DPD content: the
    // DPD parts draw no cards of their own.
    if (widget.level == DictionaryLevel.sankhitta) {
      return const SizedBox.shrink();
    }
    final sources = widget.sources ?? [for (final s in kDpdSources) s.id];
    final children = <Widget>[
      for (final id in sources)
        if (id == 'dpd_headwords')
          for (final hw in lookup.headwords)
            _anchored(
              'hw_${hw.headword.id}',
              InlineEntryCard(
                key: ValueKey(hw.headword.id),
                headword: hw,
                level: widget.level,
                lookupKey: lookup.query,
              ),
            )
        else if (id == 'dpd_roots')
          for (final rwf in lookup.roots)
            _anchored(
              'root_${rwf.root.root}',
              widget.level == DictionaryLevel.vitthara
                  ? InlineRootCard(key: ValueKey(rwf.root.root), rwf: rwf)
                  : RootSummaryCard(rwf: rwf),
            )
        else
          ..._secondaryCards(id),
    ];

    return DpdTextScope(
      child: TapSearchWrapper(
        onWordTap: widget.onWordTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  List<Widget> _secondaryCards(String sourceId) {
    var n = 0;
    return [
      for (final result in widget.lookup.secondary)
        if (dpdSourceIdOf(result) == sourceId)
          _anchored(
            secondaryTarget(sourceId, n++),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: _secondaryCard(result),
            ),
          ),
    ];
  }
}

/// The text size and font every DPD widget draws with: the ambient text theme
/// gets the dictionary size and the reader's Pāḷi font. Used by the DPD
/// results and by the page summary, so both match.
class DpdTextScope extends ConsumerWidget {
  const DpdTextScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pali = ref.watch(dictionaryPaliProvider);
    final theme = Theme.of(context);
    final base = (pali.fontSize * 0.8).clamp(kDictionaryMinTextSize, 26.0);
    TextStyle? sized(TextStyle? s, double size) =>
        s?.copyWith(fontSize: size, fontFamily: pali.fontFamily.fontFamily);
    final textTheme = theme.textTheme.copyWith(
      bodyMedium: sized(theme.textTheme.bodyMedium, base),
      bodySmall: sized(theme.textTheme.bodySmall, base * 0.85),
      titleLarge: sized(theme.textTheme.titleLarge, base * 1.3),
    );
    return Theme(
      data: theme.copyWith(textTheme: textTheme),
      child: DefaultTextStyle(
        style: textTheme.bodyMedium!.copyWith(color: theme.colorScheme.onSurface),
        child: child,
      ),
    );
  }
}
