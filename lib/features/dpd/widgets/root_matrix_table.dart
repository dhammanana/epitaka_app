import 'package:flutter/material.dart';

import '../theme/dpd_colors.dart';
import '../theme/dpd_palette.dart';
import 'entry_content.dart';
import 'feedback_type.dart';
import 'root_matrix_builder.dart';
import '../utils/text_filters.dart';

class RootMatrixTable extends StatelessWidget {
  const RootMatrixTable({super.key, required this.root, required this.data});

  final String root;
  final RootMatrixData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.5);
    final labelStyle = textStyle?.copyWith(
      color: context.palette.primaryText,
      fontWeight: FontWeight.w700,
    );
    final headerStyle = textStyle?.copyWith(
      color: context.palette.primaryText,
      fontWeight: FontWeight.w700,
    );

    // Measure the widest label across all non-empty subcategories so every
    // label cell uses the same fixed width — matching table column behaviour.
    final labelWidth = _measureMaxLabelWidth(context, labelStyle);

    final children = <Widget>[];

    for (final categoryEntry in data.entries) {
      final subcats = categoryEntry.value;
      final nonEmpty = subcats.entries
          .where((e) => e.value.isNotEmpty)
          .toList();
      if (nonEmpty.isEmpty) continue;

      // Category header — full-width, primary border
      children.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            border: Border.all(color: context.palette.primary, width: 1),
            borderRadius: BorderRadius.circular(5),
          ),
          padding: const EdgeInsets.all(5),
          child: Text(
            context.nigg(categoryEntry.key),
            textAlign: TextAlign.center,
            style: headerStyle,
          ),
        ),
      );

      // Subcategory rows — fixed-width label cell + expanding value cell.
      // IntrinsicHeight + CrossAxisAlignment.stretch make both cells equal height.
      for (final sub in nonEmpty) {
        children.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: labelWidth,
                  child: _Cell(
                    margin: const EdgeInsets.only(bottom: 2, right: 2),
                    child: Text(
                      context.nigg(sub.key),
                      style: labelStyle,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
                Expanded(
                  child: _Cell(
                    margin: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      context.nigg(sub.value.join(', ')),
                      style: textStyle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (children.isEmpty) {
      return DpdSectionContainer(
        child: Padding(
          padding: DpdColors.sectionPadding,
          child: Text(
            'No matrix data',
            style: textStyle?.copyWith(color: context.palette.gray),
          ),
        ),
      );
    }

    children.add(
      DpdFooter(
        messagePrefix: 'Something out of place?',
        linkText: 'Report it here',
        feedbackType: FeedbackType.rootMatrix,
        word: root,
      ),
    );

    return DpdSectionContainer(
      child: Padding(
        padding: DpdColors.sectionPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  /// Returns the width to use for every label cell: the widest label text
  /// plus padding (5px each side) and border (1px each side).
  double _measureMaxLabelWidth(BuildContext context, TextStyle? style) {
    double maxTextWidth = 0;
    final painter = TextPainter(textDirection: TextDirection.ltr);

    for (final cat in data.values) {
      for (final entry in cat.entries) {
        if (entry.value.isEmpty) continue;
        painter.text = TextSpan(text: entry.key, style: style);
        painter.layout();
        if (painter.width > maxTextWidth) maxTextWidth = painter.width;
      }
    }

    painter.dispose();
    // padding: 5px left + 5px right = 10px; border: 1px left + 1px right = 2px
    return maxTextWidth + 10 + 2;
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.margin, required this.child});

  final EdgeInsets margin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        border: Border.all(color: context.palette.grayTransparent, width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
      padding: const EdgeInsets.all(5),
      child: child,
    );
  }
}
