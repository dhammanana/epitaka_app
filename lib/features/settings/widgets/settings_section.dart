import 'package:flutter/material.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// A titled card section used throughout settings screens.
///
/// When [showDividers] is true, horizontal lines separate consecutive children
/// (used by the main Settings screen's sectioned list).
/// When false, children are stacked directly (used by sub-screens).
class SettingsSection extends StatelessWidget {
  final String title;
  final ColorScheme colors;
  final List<Widget> children;
  final bool showDividers;

  const SettingsSection({
    super.key,
    required this.title,
    required this.colors,
    required this.children,
    this.showDividers = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppDimensions.md, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: showDividers ? _buildWithDividers() : Column(children: children),
        ),
      ],
    );
  }

  Widget _buildWithDividers() {
    return Column(
      children: children.asMap().entries.map((entry) {
        return Column(
          children: [
            if (entry.key > 0)
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: Divider(
                  height: 1,
                  color: colors.outlineVariant,
                ),
              ),
            entry.value,
          ],
        );
      }).toList(),
    );
  }
}
