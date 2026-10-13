import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dpd/providers/dict_entries_provider.dart';
import '../../dpd/widgets/dict_html_card.dart';
import '../providers/dictionary_font_scale_provider.dart';
import 'dictionary_collapsible_card.dart';

/// One external DPD dictionary (Cone, CPD, PTS…) for the looked-up word, as a
/// collapsible card titled with `dict_meta.name`, which carries the licence
/// attribution. Nothing is drawn when the dictionary has no entry for the word.
class ExternalDictionarySection extends ConsumerWidget {
  const ExternalDictionarySection({
    super.key,
    required this.dictId,
    required this.dictName,
    required this.searchWord,
    required this.colors,
  });

  final String dictId;
  final String dictName;
  final String searchWord;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pali = ref.watch(dictionaryPaliProvider);
    final entries = ref.watch(
      dictEntriesProvider(DictEntriesKey(dictId, searchWord)),
    );
    return entries.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (rows) {
        if (rows.isEmpty) return const SizedBox.shrink();
        return DictionaryCollapsibleCard(
          dictionaryKey: dictId,
          title: dictName,
          icon: Icons.book,
          colors: colors,
          child: DictHtmlCard(
            dictId: dictId,
            entries: rows,
            baseStyle: TextStyle(
              fontSize: (pali.fontSize * 0.8).clamp(kDictionaryMinTextSize, 24.0),
              height: pali.lineHeight,
              color: colors.onSurface,
              fontFamily: pali.fontFamily.fontFamily,
            ),
          ),
        );
      },
    );
  }
}
