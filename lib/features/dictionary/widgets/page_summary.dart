import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/pali_definition_provider.dart';
import '../../dpd/models/summary_entry.dart';
import '../../dpd/providers/dict_entries_provider.dart';
import '../../dpd/providers/dictionary_list_provider.dart';
import '../../dpd/providers/dpd_lookup_provider.dart';
import '../../dpd/providers/dpd_settings_provider.dart';
import '../../dpd/providers/summary_provider.dart';
import '../../dpd/widgets/dpd_results_view.dart' show DpdTextScope;
import '../../dpd/widgets/summary_section.dart';
import '../../mdx_dictionary/providers/mdx_lookup_providers.dart';
import '../../mdx_dictionary/providers/mdx_web_providers.dart';
import '../../mdx_dictionary/widgets/mdx_webview.dart';
import 'dictionary_search_shared.dart';

/// The anchor id of the card of the list item [itemId].
String itemTarget(String itemId) => 'item_$itemId';

/// The summary at the top of the lookup page: one line for each result, in the
/// order of the dictionary list, and a tap on a line calls [onJump] with the
/// id of the card it names. A dictionary has a line exactly when it has an
/// entry for the word (the line watches what the card watches).
class PageSummary extends ConsumerWidget {
  const PageSummary({
    super.key,
    required this.entries,
    required this.lookup,
    required this.level,
    required this.searchWord,
    this.onJump,
  });

  final List<DictionaryListEntry> entries;
  final DpdLookup lookup;
  final DictionaryLevel level;
  final String searchWord;
  final void Function(String targetId)? onJump;

  /// The first entry's headword when [item] has an entry for [word], else null.
  String? _entryWord(WidgetRef ref, DictionaryListItem item, String word) {
    switch (item.kind) {
      case DictionaryItemKind.external:
        return ref
            .watch(dictEntriesProvider(DictEntriesKey(item.id, word)))
            .valueOrNull
            ?.firstOrNull
            ?.word;
      case DictionaryItemKind.book:
        final bookId = int.parse(item.id.substring('book_'.length));
        final has = bookId == 100
            ? ref.watch(paliDefinitionProvider(word)).valueOrNull?.isNotEmpty
            : ref
                  .watch(dictionaryDefinitionProvider(DictLookupKey(bookId, word)))
                  .valueOrNull
                  ?.isNotEmpty;
        return has == true ? word : null;
      case DictionaryItemKind.mdx:
        final key = MdxDefKey(item.id.substring('mdx_'.length), word);
        final has = MdxWebViewBody.isSupported
            ? ref.watch(mdxWebDocumentProvider(key)).valueOrNull?.isNotEmpty
            : ref.watch(mdxDefinitionsProvider(key)).valueOrNull?.isNotEmpty;
        return has == true ? word : null;
      case DictionaryItemKind.dpdSource:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showConstruction = ref.watch(
      dpdSettingsProvider.select((s) => s.showConstructionInSummary),
    );
    // The DPD parts have cards to jump to at every level but Saṅkhitta.
    final withTargets = level != DictionaryLevel.sankhitta;
    final lines = <SummaryEntry>[];
    for (final e in entries) {
      final item = e.item;
      if (!e.enabled || !item.ready || item.id == kDpdSummaryId) continue;
      if (item.kind == DictionaryItemKind.dpdSource) {
        if (lookup.unavailable != null) continue;
        lines.addAll(
          buildSummaryEntries(
            lookup.headwords,
            lookup.roots,
            lookup.secondary,
            sources: [item.id],
            showConstruction: showConstruction,
            withTargets: withTargets,
          ),
        );
        continue;
      }
      final word = _entryWord(ref, item, searchWord);
      if (word == null) continue;
      lines.add(
        dictionarySummaryLine(
          shortName: item.kind == DictionaryItemKind.external
              ? dictShortName(item.id)
              : item.label,
          word: word,
          targetId: itemTarget(item.id),
        ),
      );
    }
    if (lines.isEmpty) return const SizedBox.shrink();
    return DpdTextScope(child: SummarySection(entries: lines, onTap: onJump));
  }
}
