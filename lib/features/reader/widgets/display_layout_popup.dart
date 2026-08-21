import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/translation_version.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/translation_manifest_provider.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../shared/widgets/font_size_adjuster.dart';

/// A compact popup card shown when tapping the layout toggle button in the
/// reader bottom toolbar. Displays four layout options (No translation,
/// Line by line, Side by side, Only translation), quick enable/disable
/// toggles for every downloaded translation, a shortcut to the
/// Translations & Downloads settings, and a font-size adjuster below.
class DisplayLayoutPopup extends ConsumerWidget {
  const DisplayLayoutPopup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final currentMode = settings.translationDisplayMode;
    final showPali = settings.showPali;
    final showTrans = settings.showTranslation;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 300,
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        // Content can outgrow the anchored space once downloaded translations
        // are listed, so the whole card scrolls when it exceeds the max height.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Text(
                  loc.display,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // ── Layout options ───────────────────────────────────────────
              _LayoutOptionTile(
                icon: Icons.visibility_off,
                title: loc.displayNoTranslation,
                subtitle: loc.displayNoTranslationSubtitle,
                isSelected: !showTrans,
                onTap: () {
                  final notifier = ref.read(settingsProvider.notifier);
                  notifier.setShowPali(true);
                  notifier.setShowTranslation(false);
                  Navigator.of(context).pop();
                },
              ),
              _LayoutOptionTile(
                icon: Icons.view_headline,
                title: loc.displayLineByLine,
                subtitle: loc.displayLineByLineSubtitle,
                isSelected:
                    showPali &&
                    showTrans &&
                    currentMode == TranslationDisplayMode.lineByLine,
                onTap: () {
                  final notifier = ref.read(settingsProvider.notifier);
                  notifier.setShowPali(true);
                  notifier.setShowTranslation(true);
                  notifier.setTranslationDisplayMode(
                    TranslationDisplayMode.lineByLine,
                  );
                  Navigator.of(context).pop();
                },
              ),
              _LayoutOptionTile(
                icon: Icons.view_column,
                title: loc.displaySideBySide,
                subtitle: loc.displaySideBySideSubtitle,
                isSelected:
                    showPali &&
                    showTrans &&
                    currentMode == TranslationDisplayMode.sideBySide,
                onTap: () {
                  final notifier = ref.read(settingsProvider.notifier);
                  notifier.setShowPali(true);
                  notifier.setShowTranslation(true);
                  notifier.setTranslationDisplayMode(
                    TranslationDisplayMode.sideBySide,
                  );
                  Navigator.of(context).pop();
                },
              ),
              _LayoutOptionTile(
                icon: Icons.article_outlined,
                title: loc.displayOnlyTranslation,
                subtitle: loc.displayOnlyTranslationSubtitle,
                isSelected: showTrans && !showPali,
                onTap: () {
                  final notifier = ref.read(settingsProvider.notifier);
                  notifier.setShowPali(false);
                  notifier.setShowTranslation(true);
                  Navigator.of(context).pop();
                },
              ),

              // ── Divider ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: colors.outlineVariant.withValues(alpha: 0.2),
                ),
              ),

              // ── Downloaded translations ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Text(
                  loc.translationsLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const _TranslationsSection(),

              // ── Manage translations & downloads (jump to settings) ───────
              InkWell(
                onTap: () {
                  // Capture the router before popping so we don't use a
                  // deactivated context after the dialog route closes.
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.push('/settings/translation');
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.download_outlined,
                        size: 20,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          loc.translationsDownloads,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Divider ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: colors.outlineVariant.withValues(alpha: 0.2),
                ),
              ),

              // ── Show Inline Commentaries (temporary toggle) ───────────────
              _CheckboxTile(
                icon: Icons.link,
                title: loc.showBookLinks,
                value: settings.showBookLinks,
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .setShowBookLinksTemporary(v),
              ),

              // ── Tap to translate (word lookup gesture) ────────────────────
              _WordLookupTile(
                icon: Icons.touch_app,
                title: loc.tapToTranslate,
                gesture: settings.wordLookupGesture,
                onSelected: (g) =>
                    ref.read(settingsProvider.notifier).setWordLookupGesture(g),
              ),

              // ── Divider ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: colors.outlineVariant.withValues(alpha: 0.2),
                ),
              ),

              // ── Font size ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                child: Text(
                  loc.fontSize,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: FontSizeAdjuster(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// The list of downloaded translations with enable/disable checkboxes.
/// Mirrors the language toggles in Translations & Downloads settings; only
/// languages with a database file on disk are shown. Toggling persists
/// immediately but does not close the popup.
class _TranslationsSection extends ConsumerWidget {
  const _TranslationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final versionsAsync = ref.watch(localTranslationVersionsProvider);

    return versionsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          '${loc.error} $e',
          style: TextStyle(fontSize: 12, color: colors.error),
        ),
      ),
      data: (versions) {
        if (versions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              loc.noTranslationsFound,
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }

        // Group versions by language so one toggle represents the whole
        // language (matching how enabledTranslations is keyed).
        final grouped = <String, List<TranslationVersion>>{};
        for (final v in versions) {
          grouped.putIfAbsent(v.languageCode, () => []).add(v);
        }
        final langCodes = grouped.keys.toList()
          ..sort((a, b) {
            final aEnabled = settings.enabledTranslations.contains(a);
            final bEnabled = settings.enabledTranslations.contains(b);
            if (aEnabled && bEnabled) {
              return settings.enabledTranslations
                  .indexOf(a)
                  .compareTo(settings.enabledTranslations.indexOf(b));
            }
            if (aEnabled) return -1;
            if (bEnabled) return 1;
            return a.compareTo(b);
          });

        return Column(
          children: [
            for (final code in langCodes)
              _TranslationToggleTile(
                englishName: TranslationLanguageRegistry.englishName(code),
                nativeName: TranslationLanguageRegistry.nativeName(code),
                value: settings.enabledTranslations.contains(code),
                onChanged: (enabled) => ref
                    .read(settingsProvider.notifier)
                    .setTranslationEnabled(code, enabled),
              ),
          ],
        );
      },
    );
  }
}

/// A checkbox row for one downloaded translation language in the popup.
class _TranslationToggleTile extends StatelessWidget {
  final String englishName;
  final String nativeName;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _TranslationToggleTile({
    required this.englishName,
    required this.nativeName,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = englishName == nativeName
        ? englishName
        : '$englishName · $nativeName';
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: colors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tap-to-translate row in the layout popup. Shows the current gesture
/// (Disabled / Single tap / Double tap) and opens a popup menu to change it.
/// Mirrors the "Word lookup" dropdown in Reading Options and persists the
/// same setting.
class _WordLookupTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final WordLookupGesture gesture;
  final ValueChanged<WordLookupGesture> onSelected;

  const _WordLookupTile({
    required this.icon,
    required this.title,
    required this.gesture,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return PopupMenuButton<WordLookupGesture>(
      initialValue: gesture,
      onSelected: onSelected,
      tooltip: title,
      itemBuilder: (context) => [
        for (final g in const [
          WordLookupGesture.disabled,
          WordLookupGesture.singleTap,
          WordLookupGesture.doubleTap,
        ])
          PopupMenuItem(value: g, child: Text(loc.wordLookupGestureLabel(g))),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: gesture == WordLookupGesture.disabled
                      ? FontWeight.w400
                      : FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              loc.wordLookupGestureLabel(gesture),
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 18, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// A checkbox-style toggle row (e.g. "Show Inline Commentaries") in the layout popup.
/// Toggling it applies immediately but does NOT persist — the reader toolbar
/// is meant for quick, temporary adjustments.
class _CheckboxTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CheckboxTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: colors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Icon(icon, size: 20, color: colors.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single layout option row with radio-style indicator.
class _LayoutOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _LayoutOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? colors.primary : colors.outline,
                  width: isSelected ? 2 : 1.5,
                ),
                color: isSelected
                    ? colors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Icon
            Icon(icon, size: 20, color: colors.onSurfaceVariant),
            const SizedBox(width: 10),
            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
