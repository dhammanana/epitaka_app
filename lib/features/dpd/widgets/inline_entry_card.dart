import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/dpd_database.dart';
import '../providers/dpd_settings_provider.dart';
import '../utils/text_filters.dart';
import 'entry_content.dart';
import 'entry_sections_mixin.dart';
import 'family_state_mixin.dart';

class InlineEntryCard extends ConsumerStatefulWidget {
  const InlineEntryCard({
    super.key,
    required this.headword,
    required this.level,
    required this.lookupKey,
  });

  final DpdHeadwordWithRoot headword;
  final DictionaryLevel level;
  final String lookupKey;

  @override
  ConsumerState<InlineEntryCard> createState() => _InlineEntryCardState();
}

class _InlineEntryCardState extends ConsumerState<InlineEntryCard>
    with FamilyStateMixin<InlineEntryCard>, EntrySectionsMixin<InlineEntryCard> {
  @override
  DpdHeadwordWithRoot get familyHeadword => widget.headword;

  @override
  DictionaryLevel get sectionLevel => widget.level;

  @override
  String get sectionLookupKey => widget.lookupKey;

  @override
  void initState() {
    super.initState();
    ref.listenManual(dpdSettingsProvider, handleSettingsChange);
    initSectionState();
  }

  @override
  void didUpdateWidget(InlineEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) handleLevelChange();
  }

  @override
  Widget build(BuildContext context) {
    String n(String t) => context.nigg(t);
    final theme = Theme.of(context);
    final h = widget.headword;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 1),
            child: Text(
              n(h.lemma1),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          EntrySummaryBox(headword: h),
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 2, 7, 3),
            child: Wrap(
              spacing: 0,
              runSpacing: 0,
              children: [
                ...buildSectionButtons(h),
              ],
            ),
          ),
          ...buildSections(h),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
