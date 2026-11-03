import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../providers/section_description_provider.dart';

/// The ⓘ button beside a heading's copy menu.
///
/// Shown only when the enabled translation carries a description for that
/// section, so a heading without one keeps the plain row. Tapping it explains
/// the section: the short description as the title, the summary as the text.
class SectionDescriptionButton extends ConsumerWidget {
  final String bookId;
  final int paraId;

  const SectionDescriptionButton({
    super.key,
    required this.bookId,
    required this.paraId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(sectionDescriptionLangProvider);
    if (lang == null) return const SizedBox.shrink();
    final description = ref
        .watch(
          sectionDescriptionProvider((
            lang: lang,
            bookId: bookId,
            paraId: paraId,
          )),
        )
        .valueOrNull;
    if (description == null) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    return SelectionContainer.disabled(
      child: IconButton(
        icon: Icon(
          Icons.info_outline,
          size: 18,
          color: colors.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        tooltip: AppLocalizations.of(context).sectionAbout,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        splashRadius: 14,
        onPressed: () => _showDescription(context, description),
      ),
    );
  }

  Future<void> _showDescription(
    BuildContext context,
    SectionDescription description,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(
            description.title,
            style: AppTypography.labelMedium.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: SelectableText(
                description.text,
                style: AppTypography.bodyTranslation.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).closeButtonLabel),
            ),
          ],
        );
      },
    );
  }
}
