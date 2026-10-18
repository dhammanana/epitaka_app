import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_localizations.dart';
import '../../dpd/providers/dpd_settings_provider.dart';

/// Space each side of an icon button, so two lit buttons do not touch.
const kDictionaryIconGap = 2.0;

const _levelIcons = {
  DictionaryLevel.sankhitta: Icons.density_small,
  DictionaryLevel.majjhima: Icons.density_medium,
  DictionaryLevel.vitthara: Icons.density_large,
};

String _levelTip(AppLocalizations loc, DictionaryLevel l) =>
    '${l.paliName} · ${loc.t(l.englishName)}';

/// The three levels as three icon buttons, the current one filled.
class DictionaryLevelButtons extends ConsumerWidget {
  const DictionaryLevelButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final level = ref.watch(dpdSettingsProvider.select((s) => s.level));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final l in DictionaryLevel.values)
          Tooltip(
            message: _levelTip(loc, l),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kDictionaryIconGap,
              ),
              child: InkWell(
                onTap: () => ref.read(dpdSettingsProvider.notifier).setLevel(l),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: l == level ? colors.primaryContainer : null,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _levelIcons[l],
                    size: 16,
                    color: l == level
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
