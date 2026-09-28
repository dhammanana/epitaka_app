import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../providers/dictionary_expanded_provider.dart';

/// A collapsible card wrapping one dictionary's result section.
///
/// The header (icon + title + chevron) is always rendered. The [child] is
/// only inserted into the tree when expanded, so any providers watched
/// inside [child] are not fetched while collapsed (lazy load). The
/// expand/collapse state is persisted via [dictionaryExpandedProvider], so
/// the next search reuses the user's choice.
class DictionaryCollapsibleCard extends ConsumerWidget {
  /// Stable key, e.g. `dpd`, `book_12`, `mdx_<id>`.
  final String dictionaryKey;
  final String title;
  final IconData icon;
  final ColorScheme colors;

  /// Built only when expanded. Return [SizedBox.shrink] when the dictionary
  /// has no entry so empty dictionaries disappear.
  final Widget child;

  const DictionaryCollapsibleCard({
    super.key,
    required this.dictionaryKey,
    required this.title,
    required this.icon,
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(
      dictionaryExpandedFamilyProvider(dictionaryKey),
    );
    final pali = ref.watch(settingsProvider.select((s) => s.typography.pali));

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      decoration: BoxDecoration(
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.55),
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => ref
                .read(dictionaryExpandedProvider.notifier)
                .toggle(dictionaryKey),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.sm,
                vertical: AppDimensions.xs,
              ),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: colors.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: (pali.fontSize * 0.55).clamp(9.0, 14.0),
                        fontWeight: FontWeight.w600,
                        color: colors.onSurfaceVariant,
                        fontFamily: pali.fontFamily.fontFamily,
                      ),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          // Lazy: [child] is only in the tree when expanded, so its
          // definition providers are not watched while collapsed.
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.xs,
                2,
                AppDimensions.xs,
                AppDimensions.xs,
              ),
              child: child,
            ),
        ],
      ),
    );
  }
}
