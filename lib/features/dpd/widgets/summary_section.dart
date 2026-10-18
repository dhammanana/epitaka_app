import 'package:flutter/material.dart';

import '../models/summary_entry.dart';
import '../theme/dpd_colors.dart';
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

/// Displays a summary list at the top of search results.
/// Each entry shows label, type, meaning, and a ► tap target.
class SummarySection extends StatelessWidget {
  const SummarySection({super.key, required this.entries, this.onTap});

  final List<SummaryEntry> entries;

  /// Called with the line's `targetId`. A line with no target, or no [onTap],
  /// is plain text: no ► and no tap (the DPD app's lines always have both).
  final void Function(String targetId)? onTap;

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

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
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
              onTap: onTap != null && entries[i].targetId.isNotEmpty
                  ? () => onTap!(entries[i].targetId)
                  : null,
            ),
          const SizedBox(height: 12),
          Divider(height: 1, color: context.palette.primary.withValues(alpha: 0.3)),
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
    required this.onTap,
  });

  final SummaryEntry entry;
  final bool showHeadwordHeading;
  final bool isSingletonGroup;
  final VoidCallback? onTap;

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

    return InkWell(
      onTap: onTap,
      borderRadius: DpdColors.borderRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: entry.type == SummaryEntryType.headword &&
                splitLabel.suffix != null &&
                !isSingletonGroup
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showHeadwordHeading)
                    Text(context.nigg(splitLabel.lemma), style: labelStyle),
                  if (entry.typeLabel.isNotEmpty ||
                      entry.meaning.isNotEmpty ||
                      splitLabel.suffix != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                if (splitLabel.suffix != null)
                                  TextSpan(
                                    text: context.nigg(
                                      '${splitLabel.suffix} ',
                                    ),
                                    style: linkStyle,
                                  ),
                                if (entry.typeLabel.isNotEmpty)
                                  TextSpan(
                                    text: entry.typeLabel,
                                    style: baseStyle,
                                  ),
                                if (entry.meaning.isNotEmpty)
                                  ...meaningSpans(
                                    entry.typeLabel.isNotEmpty
                                        ? ' ${entry.meaning}'
                                        : entry.meaning,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Kept in the layout when the line has no tap, so a line wraps the same
                  // at every level.
                  Visibility(
                    visible: onTap != null,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: Text('►', style: linkStyle),
                  ),
                      ],
                    ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: context.nigg(entry.label),
                            style: labelStyle,
                          ),
                          if (entry.typeLabel.isNotEmpty)
                            TextSpan(
                              text: ' ${entry.typeLabel}',
                              style: baseStyle,
                            ),
                          // The splits read better under their word (user,
                          // 2026-10-14).
                          if (entry.meaning.isNotEmpty)
                            ...meaningSpans(
                              entry.type == SummaryEntryType.deconstructor
                                  ? '\n${entry.meaning}'
                                  : ' ${entry.meaning}',
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Kept in the layout when the line has no tap, so a line wraps the same
                  // at every level.
                  Visibility(
                    visible: onTap != null,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: Text('►', style: linkStyle),
                  ),
                ],
              ),
      ),
    );
  }
}
