import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../models/lookup_results.dart';
import '../providers/dpd_lookup_provider.dart';
import 'inline_entry_card.dart';
import 'root_summary_card.dart';
import 'secondary/secondary_result_cards.dart';
import 'tap_search_wrapper.dart';

/// The DPD result stack for one lookup: headwords, roots and the secondary
/// sources. A plain column, because it sits inside the dictionary sheet's own
/// scroll view. Built from the DPD app's `SearchResultsBody` and
/// `SplitResultsList`; partial and fuzzy tiers are not shown.
class DpdResultsView extends ConsumerStatefulWidget {
  const DpdResultsView({
    super.key,
    required this.lookup,
    required this.onWordTap,
  });

  final DpdLookup lookup;

  /// A word tapped inside an entry, already cleaned and in Roman script.
  final void Function(String word) onWordTap;

  @override
  ConsumerState<DpdResultsView> createState() => _DpdResultsViewState();
}

class _DpdResultsViewState extends ConsumerState<DpdResultsView> {
  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final lookup = widget.lookup;
    final pali = ref.watch(settingsProvider.select((s) => s.typography.pali));
    final theme = Theme.of(context);
    // The DPD widgets size their text from the ambient text theme, so it is
    // set here from the user's Pāḷi font and size.
    final base = (pali.fontSize * 0.8).clamp(13.0, 26.0);
    TextStyle? sized(TextStyle? s, double size) =>
        s?.copyWith(fontSize: size, fontFamily: pali.fontFamily.fontFamily);
    final textTheme = theme.textTheme.copyWith(
      bodyMedium: sized(theme.textTheme.bodyMedium, base),
      bodySmall: sized(theme.textTheme.bodySmall, base * 0.85),
      titleLarge: sized(theme.textTheme.titleLarge, base * 1.3),
    );

    // `secondary` is already in the DPD app's default order.
    final children = <Widget>[
      for (final hw in lookup.headwords)
        InlineEntryCard(key: ValueKey(hw.headword.id), headword: hw),
      for (final rwf in lookup.roots) RootSummaryCard(rwf: rwf),
      for (final result in lookup.secondary)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: _secondaryCard(result),
        ),
    ];

    return Theme(
      data: theme.copyWith(textTheme: textTheme),
      child: DefaultTextStyle(
        style: textTheme.bodyMedium!.copyWith(color: theme.colorScheme.onSurface),
        child: TapSearchWrapper(
          onWordTap: widget.onWordTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}
