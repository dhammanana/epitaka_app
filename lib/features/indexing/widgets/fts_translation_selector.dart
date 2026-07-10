import 'package:flutter/material.dart';

import '../../../core/providers/translation_registry_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// A widget that displays available translations for the user to choose from
/// before building the FTS index.
class FtsTranslationSelector extends StatelessWidget {
  final List<AvailableTranslation> translations;
  final String? selectedLang;
  final ValueChanged<String> onSelected;
  final VoidCallback onBuild;
  final ColorScheme colors;

  const FtsTranslationSelector({
    super.key,
    required this.translations,
    required this.selectedLang,
    required this.onSelected,
    required this.onBuild,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.marginMobile,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Available Translations',
            style: AppTypography.labelMedium.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Expanded(
            child: translations.isEmpty
                ? Center(
                    child: Text(
                      'No translations available.\nPlease download a translation first.',
                      textAlign: TextAlign.center,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: translations.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: colors.outlineVariant.withValues(alpha: 0.3),
                    ),
                    itemBuilder: (context, index) {
                      final t = translations[index];
                      final isSelected = selectedLang == t.languageCode;
                      return InkWell(
                        onTap: () => onSelected(t.languageCode),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: AppDimensions.sm,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? colors.primary
                                        : colors.outlineVariant,
                                    width: 2,
                                  ),
                                  color: isSelected ? colors.primary : Colors.transparent,
                                ),
                                child: isSelected
                                    ? Icon(Icons.check, size: 14, color: colors.onPrimary)
                                    : null,
                              ),
                              const SizedBox(width: AppDimensions.md),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.englishName,
                                    style: AppTypography.labelMedium.copyWith(
                                      color: colors.onSurface,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                  Text(
                                    t.nativeName,
                                    style: AppTypography.labelSmall.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: AppDimensions.md),
          FilledButton.icon(
            onPressed: selectedLang != null ? onBuild : null,
            icon: const Icon(Icons.build),
            label: Text(
              selectedLang != null
                  ? 'Build Index (Pāli + ${selectedLang!.toUpperCase()})'
                  : 'Select a Translation',
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
        ],
      ),
    );
  }
}
