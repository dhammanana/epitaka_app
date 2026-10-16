import 'package:flutter/material.dart';

import '../../theme/dpd_colors.dart';
import '../../theme/dpd_palette.dart';
import '../../utils/text_filters.dart';

/// A card matching the webapp's `h3 + div.dpd` pattern.
/// Header is h3-equivalent (130% bold), content is in a primary-bordered box.
class DpdSecondaryCard extends StatelessWidget {
  const DpdSecondaryCard({
    super.key,
    required this.title,
    required this.content,
    this.footer,
  });

  final String title;
  final Widget content;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Text(
              context.nigg(title),
              style: titleStyle?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: context.palette.primary, width: 2),
              borderRadius: DpdColors.borderRadius,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                // ignore: use_null_aware_elements
                if (footer != null) footer!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Matches the webapp's `h3 + div.tertiary` pattern.
/// Same as [DpdSecondaryCard] but border is green ([DpdColors.secondary])
/// and padding is slightly narrower (3px 5px).
/// Used by Abbreviations and Help cards only.
class TertiaryCard extends StatelessWidget {
  const TertiaryCard({
    super.key,
    required this.title,
    required this.content,
  });

  final String title;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Text(
              context.nigg(title),
              style: titleStyle?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: context.palette.secondary, width: 2),
              borderRadius: DpdColors.borderRadius,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: content,
          ),
        ],
      ),
    );
  }
}
