import 'package:flutter/material.dart';

import '../models/inflection_table_data.dart';
import '../theme/dpd_colors.dart';
import '../theme/dpd_palette.dart';
import '../utils/text_filters.dart';

class InflectionTable extends StatelessWidget {
  const InflectionTable({super.key, required this.data, this.lookupKey});

  final InflectionTableData data;

  /// When non-null and non-empty, any form whose [InflectionForm.word] exactly
  /// matches [lookupKey] is rendered with a yellow highlight.
  final String? lookupKey;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = context.palette;
    final headerBg = isDark ? palette.dark : palette.light;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeading(context),
            const SizedBox(height: 8),
            // SelectionContainer.disabled prevents the root SelectionArea from
            // crashing on nested scrollables. The results view's own
            // TapSearchWrapper makes a tapped form search the word, so the
            // DPD app's nested wrapper is not needed here.
            SelectionContainer.disabled(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: _buildTable(context, headerBg),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeading(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium ?? const TextStyle();
    final bold = base.copyWith(fontWeight: FontWeight.bold);
    final d = data;

    final List<InlineSpan> spans = [
      TextSpan(text: d.headingLemma, style: bold),
      TextSpan(text: ' is ', style: base),
      TextSpan(text: d.headingPattern, style: bold),
      TextSpan(text: ' ${d.headingDeclLabel}', style: base),
    ];

    if (d.headingIsIrregular) {
      spans.add(TextSpan(text: ' (irregular)', style: base));
    } else if (d.headingLike != null) {
      spans.addAll([
        TextSpan(text: ' (like ', style: base),
        TextSpan(text: d.headingLike!, style: bold),
        TextSpan(text: ')', style: base),
      ]);
    }

    return Text.rich(TextSpan(children: spans));
  }

  Widget _buildTable(BuildContext context, Color headerBg) {
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
      children: [
        _buildHeaderRow(context, headerBg),
        for (final row in data.rows)
          _buildDataRow(context, row, headerBg),
      ],
    );
  }

  TableRow _buildHeaderRow(BuildContext context, Color headerBg) {
    final theme = Theme.of(context);
    final headers = data.headers;
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: context.palette.primaryText,
    );

    return TableRow(
      children: [
        for (final header in headers)
          _buildCellContainer(
            color: headerBg,
            borderColor: context.palette.primary,
            child: Text(header, textAlign: TextAlign.center, style: style),
          ),
      ],
    );
  }

  TableRow _buildDataRow(
    BuildContext context,
    (String, List<InflectionCell>) row,
    Color headerBg,
  ) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: context.palette.primaryText,
    );
    final (rowLabel, cells) = row;

    return TableRow(
      children: [
        _buildCellContainer(
          color: headerBg,
          borderColor: context.palette.primary,
          child: Text(rowLabel, textAlign: TextAlign.center, style: labelStyle),
        ),
        for (final cell in cells)
          _buildCellContainer(
            color: surfaceColor,
            borderColor: context.palette.grayTransparent,
            child: cell.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: cell.forms
                        .map((form) => _buildFormText(context, form))
                        .toList(),
                  ),
          ),
      ],
    );
  }

  Widget _buildCellContainer({
    required Color color,
    required Color borderColor,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.all(1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: borderColor, width: 1),
          borderRadius: DpdColors.borderRadius,
        ),
        alignment: Alignment.topCenter,
        child: child,
      ),
    );
  }

  Widget _buildFormText(BuildContext context, InflectionForm form) {
    if (form.ending.isEmpty) return const SizedBox.shrink();

    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final isMatch =
        lookupKey != null && lookupKey!.isNotEmpty && form.word == lookupKey!.trim();

    final textStyle = isMatch
        ? base.copyWith(color: Theme.of(context).colorScheme.onPrimary)
        : !form.isOccurring
        ? base.copyWith(color: context.palette.gray)
        : base;

    final richText = Text.rich(
      TextSpan(
        style: textStyle,
        children: [
          if (form.stem.isNotEmpty) TextSpan(text: context.nigg(form.stem)),
          TextSpan(
            text: context.nigg(form.ending),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      softWrap: false,
    );

    if (!isMatch) return richText;

    return Container(
      decoration: BoxDecoration(
        color: context.palette.primary,
        borderRadius: BorderRadius.circular(3),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: richText,
    );
  }
}
