import 'package:flutter/material.dart';

import '../database/dpd_database.dart';
import '../theme/dpd_colors.dart';
import '../theme/dpd_palette.dart';
import 'entry_content.dart';
import 'feedback_type.dart';
import '../utils/text_filters.dart';

const Map<int, String> _rootGroupPali = {
  1: 'bhūvādigaṇa',
  2: 'rudhādigaṇa',
  3: 'divādigaṇa',
  4: 'svādigaṇa',
  5: 'kiyādigaṇa',
  6: 'gahādigaṇa',
  7: 'tanādigaṇa',
  8: 'curādigaṇa',
};

class RootInfoTable extends StatelessWidget {
  const RootInfoTable({super.key, required this.root, this.bases});

  final DpdRoot root;
  final List<String>? bases;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: context.palette.primaryText,
      fontWeight: FontWeight.w700,
    );
    final valueStyle = theme.textTheme.bodyMedium;
    final grayStyle = valueStyle?.copyWith(color: context.palette.gray);
    final italicStyle = valueStyle?.copyWith(fontStyle: FontStyle.italic);

    final rows = <TableRow>[];

    // Pāḷi Root
    final rootClean = root.root.replaceAll('√', '');
    final groupPali = _rootGroupPali[root.rootGroup] ?? '';
    rows.add(
      buildKvRow(
        context,
        'Pāḷi Root:',
        Text.rich(
          TextSpan(
            style: valueStyle,
            children: [
              TextSpan(text: context.nigg(rootClean)),
              if (root.rootHasVerb.isNotEmpty)
                TextSpan(
                  text: root.rootHasVerb,
                  style: valueStyle?.copyWith(
                    fontSize: (valueStyle.fontSize ?? 14) * 0.7,
                    fontFeatures: [const FontFeature.superscripts()],
                  ),
                ),
              TextSpan(
                text: context.nigg(
                  ' ${root.rootGroup} $groupPali + ${root.rootSign}',
                ),
              ),
              TextSpan(text: context.nigg(' (${root.rootMeaning})')),
            ],
          ),
        ),
        labelStyle: labelStyle,
      ),
    );

    // Base(s)
    final b = bases;
    final basesLabel = (b != null && b.length > 1) ? 'Bases:' : 'Base:';
    final basesValue = b == null ? '…' : (b.isEmpty ? '-' : b.join(', '));
    rows.add(
      buildKvTextRow(
        context,
        basesLabel,
        basesValue,
        labelStyle: labelStyle,
        valueStyle: valueStyle,
      )!,
    );

    // Root in Compounds (optional)
    if (root.rootInComps.isNotEmpty) {
      rows.add(
        buildKvTextRow(
          context,
          'Root in Compounds:',
          root.rootInComps,
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        )!,
      );
    }

    // Dhātupātha
    if (root.dhatupathaRoot != '-') {
      rows.add(
        buildKvRow(
          context,
          'Dhātupātha:',
          Text.rich(
            TextSpan(
              style: valueStyle,
              children: [
                TextSpan(text: '${root.dhatupathaRoot} '),
                TextSpan(
                  style: italicStyle,
                  children: parseSimpleMarkup(
                    root.dhatupathaPali,
                    boldStyle: italicStyle?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextSpan(text: ' ('),
                ...parseSimpleMarkup(
                  root.dhatupathaEnglish,
                  boldStyle: valueStyle?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: ') #${root.dhatupathaNum}'),
              ],
            ),
          ),
          labelStyle: labelStyle,
        ),
      );
    } else {
      rows.add(
        buildKvTextRow(
          context,
          'Dhātupātha:',
          '-',
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        )!,
      );
    }

    // Dhātumañjūsa
    if (root.dhatumanjusaRoot != '-') {
      rows.add(
        buildKvRow(
          context,
          'Dhātumañjūsa:',
          Text.rich(
            TextSpan(
              style: valueStyle,
              children: [
                TextSpan(text: '${root.dhatumanjusaRoot} '),
                TextSpan(
                  style: italicStyle,
                  children: parseSimpleMarkup(
                    root.dhatumanjusaPali,
                    boldStyle: italicStyle?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextSpan(text: ' ('),
                ...parseSimpleMarkup(
                  root.dhatumanjusaEnglish,
                  boldStyle: valueStyle?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: ') #${root.dhatumanjusaNum}'),
              ],
            ),
          ),
          labelStyle: labelStyle,
        ),
      );
    } else {
      rows.add(
        buildKvTextRow(
          context,
          'Dhātumañjūsa:',
          '-',
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        )!,
      );
    }

    // Saddanīti
    if (root.dhatumalaRoot != '-') {
      rows.add(
        buildKvRow(
          context,
          'Saddanīti:',
          Text.rich(
            TextSpan(
              style: valueStyle,
              children: [
                TextSpan(text: '${root.dhatumalaRoot} '),
                TextSpan(text: root.dhatumalaPali, style: italicStyle),
                TextSpan(text: ' (${root.dhatumalaEnglish})'),
              ],
            ),
          ),
          labelStyle: labelStyle,
        ),
      );
    } else {
      rows.add(
        buildKvTextRow(
          context,
          'Saddanīti:',
          '-',
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        )!,
      );
    }

    // Sanskrit Root (gray)
    rows.add(
      buildKvRow(
        context,
        'Sanskrit Root:',
        Text(
          '${root.sanskritRoot} ${root.sanskritRootClass} (${root.sanskritRootMeaning})',
          style: grayStyle,
        ),
        labelStyle: labelStyle,
      ),
    );

    // Pāṇinīya Dhātupāṭha (gray or "-")
    if (root.paniniRoot != '-') {
      rows.add(
        buildKvRow(
          context,
          'Pāṇinīya Dhātupāṭha:',
          Text.rich(
            TextSpan(
              style: grayStyle,
              children: [
                TextSpan(text: '${root.paniniRoot} '),
                TextSpan(
                  text: root.paniniSanskrit,
                  style: grayStyle?.copyWith(fontStyle: FontStyle.italic),
                ),
                TextSpan(text: ' (${root.paniniEnglish})'),
              ],
            ),
          ),
          labelStyle: labelStyle,
        ),
      );
    } else {
      rows.add(
        buildKvTextRow(
          context,
          'Pāṇinīya Dhātupāṭha:',
          '-',
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        )!,
      );
    }

    // Notes (optional) — may contain inline HTML (<i>, <b>, <a>)
    if (root.note.isNotEmpty) {
      rows.add(
        buildKvRichRow(context, 'Notes:', root.note, labelStyle: labelStyle)!,
      );
    }

    return DpdSectionContainer(
      child: Padding(
        padding: DpdColors.sectionPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Table(
              columnWidths: const {
                0: IntrinsicColumnWidth(),
                1: FlexColumnWidth(),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: rows,
            ),
            DpdFooter(
              messagePrefix: 'Something out of place?',
              linkText: 'Report it here',
              feedbackType: FeedbackType.rootInfo,
              word: root.root,
            ),
          ],
        ),
      ),
    );
  }
}
