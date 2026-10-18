import 'package:flutter/material.dart';

import '../database/dpd_database.dart';
import '../theme/dpd_colors.dart';
import '../theme/dpd_palette.dart';
import '../utils/text_filters.dart';

/// A root as a heading and one summary box. The DPD app's `InlineRootCard`
/// adds root info, matrix and family buttons, which come with the Vitthāra
/// level.
class RootSummaryCard extends StatelessWidget {
  const RootSummaryCard({super.key, required this.rwf});

  final RootWithFamilies rwf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final root = rwf.root;
    final rootClean = root.root.replaceAll('√', '');
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.5);
    final boldStyle = baseStyle?.copyWith(fontWeight: FontWeight.w700);
    final grayStyle = baseStyle?.copyWith(color: context.palette.gray);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 1),
            child: Text(
              context.nigg('root: $rootClean'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.primary, width: 2),
              borderRadius: DpdColors.borderRadius,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            child: Text.rich(
              TextSpan(
                style: baseStyle,
                children: [
                  const TextSpan(text: 'root. '),
                  TextSpan(text: context.nigg(rootClean), style: boldStyle),
                  if (root.rootHasVerb.isNotEmpty)
                    TextSpan(
                      text: root.rootHasVerb,
                      style: baseStyle?.copyWith(
                        fontSize: (baseStyle.fontSize ?? 14) * 0.7,
                        fontFeatures: [const FontFeature.superscripts()],
                      ),
                    ),
                  TextSpan(text: context.nigg(' ${root.rootGroup} ')),
                  TextSpan(text: context.nigg(root.rootSign)),
                  TextSpan(text: context.nigg(' (${root.rootMeaning})')),
                  TextSpan(text: ' ${rwf.count}', style: grayStyle),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
