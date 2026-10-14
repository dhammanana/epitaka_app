import 'package:flutter/material.dart';

import '../../dpd/database/dao.dart' show DpdHeadwordWithRoot;
import '../../dpd/providers/dictionary_list_provider.dart';
import '../../dpd/providers/dpd_lookup_provider.dart';
import '../../dpd/providers/dpd_settings_provider.dart';
import '../../dpd/widgets/dpd_results_view.dart';
import '../../dpd/widgets/dpd_status_message.dart';
import '../../dpd/widgets/tap_search_wrapper.dart';
import '../../dpd/widgets/tier_divider.dart';
import '../../mdx_dictionary/widgets/mdx_definition_section.dart';
import 'dictionary_search_shared.dart';
import 'external_dictionary_section.dart';
import 'page_anchors.dart';
import 'page_summary.dart';
import 'pali_definition_card.dart';

/// `dictionary_books.id` of the Bold Definition book, drawn as linked
/// sentence cards.
const _paliDefinitionBookId = 100;

/// A tap on a word in a dictionary looks that word up, as it does in DPD.
Widget _tappable(void Function(String word) onWordTap, Widget child) =>
    TapSearchWrapper(onWordTap: onWordTap, child: child);

/// The lookup page body: the user's dictionary list, in order, as one widget
/// per dictionary. DPD sources that sit next to each other share one widget,
/// because they share one text theme and one tap handler. Dictionaries that
/// are switched off, and ids that are not installed, are not here.
List<Widget> buildOrderedDictionaryItems({
  required List<DictionaryListEntry> entries,
  required DpdLookup lookup,
  required DictionaryLevel level,
  required String searchWord,
  required ColorScheme colors,
  required void Function(String word) onWordTap,
  PageAnchors? anchors,
  void Function(String targetId)? onJump,
  bool showSummary = true,
}) {
  final widgets = <Widget>[];
  var run = <String>[];
  var statusShown = false;
  final summaryEnabled = entries.any(
    (e) => e.enabled && e.item.id == kDpdSummaryId,
  );
  // At Saṅkhitta the summary is all the DPD content, so it shows whatever its
  // own switch says; it then sits at the top when the list does not place it.
  final summaryOnTop =
      level == DictionaryLevel.sankhitta && !(summaryEnabled && showSummary);

  // A tapped word in a line with no card to jump to (the DPD lines at
  // Saṅkhitta) is looked up; a line that jumps keeps its own tap.
  Widget summary() => _tappable(
    onWordTap,
    PageSummary(
      key: const ValueKey('page-summary'),
      entries: entries,
      lookup: lookup,
      level: level,
      searchWord: searchWord,
      onJump: onJump,
    ),
  );

  /// [w] under the anchor of the list item [item], when the page has anchors.
  Widget anchored(DictionaryListItem item, Widget w) => anchors == null
      ? w
      : KeyedSubtree(key: anchors.keyFor(itemTarget(item.id)), child: w);

  if (summaryOnTop) widgets.add(summary());

  void flushRun() {
    if (run.isEmpty) return;
    if (lookup.unavailable != null) {
      if (!statusShown) {
        widgets.add(DpdStatusMessage(unavailable: lookup.unavailable!));
        statusShown = true;
      }
    } else {
      widgets.add(
        DpdResultsView(
          key: ValueKey('dpd:${run.join(',')}'),
          lookup: lookup,
          level: level,
          sources: run,
          anchors: anchors,
          onWordTap: onWordTap,
        ),
      );
    }
    run = <String>[];
  }

  for (final entry in entries) {
    if (!entry.enabled) continue;
    final item = entry.item;
    if (!item.ready) continue;
    if (item.id == kDpdSummaryId) {
      flushRun();
      if (!summaryOnTop && (showSummary || level == DictionaryLevel.sankhitta)) {
        widgets.add(summary());
      }
      continue;
    }
    switch (item.kind) {
      case DictionaryItemKind.dpdSource:
        run.add(item.id);
      case DictionaryItemKind.external:
        flushRun();
        widgets.add(
          anchored(
            item,
            _tappable(
              onWordTap,
              ExternalDictionarySection(
                dictId: item.id,
                dictName: item.label,
                searchWord: searchWord,
                colors: colors,
              ),
            ),
          ),
        );
      case DictionaryItemKind.book:
        flushRun();
        final bookId = int.parse(item.id.substring('book_'.length));
        widgets.add(
          anchored(
            item,
            _tappable(
              onWordTap,
              bookId == _paliDefinitionBookId
              ? PaliDefinitionSection(
                  searchWord: searchWord,
                  bookName: item.label,
                  colors: colors,
                )
              : DictDefinitionSection(
                  bookId: bookId,
                  bookName: item.label,
                  searchWord: searchWord,
                  colors: colors,
                  onEntryTap: onWordTap,
                ),
            ),
          ),
        );
      case DictionaryItemKind.mdx:
        flushRun();
        widgets.add(
          anchored(
            item,
            _tappable(
              onWordTap,
              MdxDefinitionSection(
                dictId: item.id.substring('mdx_'.length),
                dictTitle: item.label,
                searchWord: searchWord,
                onEntryTap: onWordTap,
              ),
            ),
          ),
        );
    }
  }
  flushRun();

  // The looser tiers, when their settings are on, come last as headword lines.
  final headwordsEntries = [
    for (final e in entries)
      if (e.enabled && e.item.id == 'dpd_headwords') e,
  ];
  if (lookup.unavailable == null && headwordsEntries.isNotEmpty) {
    void tier(ResultTier tier, List<DpdHeadwordWithRoot> headwords) {
      if (headwords.isEmpty) return;
      final tierLookup = DpdLookup(
        query: lookup.query,
        headwords: headwords,
        roots: const [],
        secondary: const [],
        timer: lookup.timer,
      );
      widgets.add(TierDivider(key: ValueKey('tier:${tier.name}'), tier: tier));
      // At Saṅkhitta the results view draws nothing (the summary is the whole
      // DPD content), so the tier's headwords become summary lines.
      widgets.add(
        level == DictionaryLevel.sankhitta
            ? _tappable(
                onWordTap,
                PageSummary(
                  key: ValueKey('tier-results:${tier.name}'),
                  entries: headwordsEntries,
                  lookup: tierLookup,
                  level: level,
                  searchWord: searchWord,
                ),
              )
            : DpdResultsView(
                key: ValueKey('tier-results:${tier.name}'),
                lookup: tierLookup,
                level: level,
                sources: const ['dpd_headwords'],
                logFirstPaint: false,
                onWordTap: onWordTap,
              ),
      );
    }

    tier(ResultTier.partial, lookup.partial);
    tier(ResultTier.fuzzy, lookup.fuzzy);
  }
  return widgets;
}
