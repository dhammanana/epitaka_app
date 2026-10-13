import 'package:flutter/material.dart';

import '../models/summary_entry.dart';
import '../theme/dpd_palette.dart';
import '../utils/text_filters.dart';

@visibleForTesting
({String lemma, String? suffix}) splitSummaryLemma(String label) {
  final spaceIndex = label.lastIndexOf(' ');
  if (spaceIndex <= 0 || spaceIndex >= label.length - 1) {
    return (lemma: label, suffix: null);
  }

  final suffix = label.substring(spaceIndex + 1);
  if (!RegExp(r'^\d[\d.]*$').hasMatch(suffix)) {
    return (lemma: label, suffix: null);
  }

  return (lemma: label.substring(0, spaceIndex), suffix: suffix);
}

@visibleForTesting
bool shouldShowHeadwordHeading(SummaryEntry entry, SummaryEntry? previous) {
  if (entry.type != SummaryEntryType.headword) return false;

  final current = splitSummaryLemma(entry.label);
  if (current.suffix == null) return true;

  if (previous == null || previous.type != SummaryEntryType.headword) {
    return true;
  }

  final prior = splitSummaryLemma(previous.label);
  return prior.lemma != current.lemma;
}

List<InlineSpan> _parseBoldSpans(String text, {TextStyle? boldStyle}) {
  final spans = <InlineSpan>[];
  text.splitMapJoin(
    RegExp(r'<b>(.*?)</b>'),
    onMatch: (m) {
      spans.add(TextSpan(text: m.group(1), style: boldStyle));
      return '';
    },
    onNonMatch: (s) {
      if (s.isNotEmpty) spans.add(TextSpan(text: s));
      return '';
    },
  );
  return spans;
}

/// The Saṅkhitta level: one line per headword, root and secondary source.
/// Built from the DPD app's `SummarySection`. The title, the divider and the
/// ► tap target are left out, because here the lines are the whole entry
/// and there is nothing to jump to.
class SummarySection extends StatelessWidget {
  const SummarySection({super.key, required this.entries});

  final List<SummaryEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final lemmaCounts = <String, int>{};
    for (final e in entries) {
      if (e.type == SummaryEntryType.headword) {
        final lemma = splitSummaryLemma(e.label).lemma;
        lemmaCounts[lemma] = (lemmaCounts[lemma] ?? 0) + 1;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < entries.length; i++)
            _SummaryRow(
              entry: entries[i],
              showHeadwordHeading: shouldShowHeadwordHeading(
                entries[i],
                i > 0 ? entries[i - 1] : null,
              ),
              isSingletonGroup:
                  (lemmaCounts[splitSummaryLemma(entries[i].label).lemma] ??
                      0) <=
                  1,
            ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.entry,
    required this.showHeadwordHeading,
    required this.isSingletonGroup,
  });

  final SummaryEntry entry;
  final bool showHeadwordHeading;
  final bool isSingletonGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyMedium;
    final isDark = theme.brightness == Brightness.dark;
    final labelStyle = baseStyle?.copyWith(
      color: isDark ? context.palette.primaryTextDark : context.palette.primaryText,
      fontWeight: FontWeight.w700,
    );
    final linkStyle = baseStyle?.copyWith(
      color: context.palette.primaryText,
      fontWeight: FontWeight.w700,
    );
    final boldStyle = baseStyle?.copyWith(fontWeight: FontWeight.bold);
    final splitLabel = splitSummaryLemma(entry.label);

    List<InlineSpan> meaningSpans(String raw) {
      final text = context.nigg(raw);
      return entry.meaningHasBold
          ? _parseBoldSpans(text, boldStyle: boldStyle)
          : [TextSpan(text: text, style: baseStyle)];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: entry.type == SummaryEntryType.headword &&
              splitLabel.suffix != null &&
              !isSingletonGroup
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeadwordHeading)
                  Text(context.nigg(splitLabel.lemma), style: labelStyle),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: context.nigg('${splitLabel.suffix} '),
                        style: linkStyle,
                      ),
                      if (entry.typeLabel.isNotEmpty)
                        TextSpan(text: entry.typeLabel, style: baseStyle),
                      if (entry.meaning.isNotEmpty)
                        ...meaningSpans(
                          entry.typeLabel.isNotEmpty
                              ? ' ${entry.meaning}'
                              : entry.meaning,
                        ),
                    ],
                  ),
                ),
              ],
            )
          : Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: context.nigg(entry.label), style: labelStyle),
                  if (entry.typeLabel.isNotEmpty)
                    TextSpan(text: ' ${entry.typeLabel}', style: baseStyle),
                  if (entry.meaning.isNotEmpty)
                    ...meaningSpans(' ${entry.meaning}'),
                ],
              ),
            ),
    );
  }
}
