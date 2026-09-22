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

    // The four layout modes with their selection state and tap actions,
    // shared by the segmented control and its caption below.
    final layoutModes = [
      _LayoutMode(
        icon: Icons.visibility_off,
        tooltip: loc.displayNoTranslation,
        caption: loc.displayNoTranslationSubtitle,
        isSelected: !showTrans,
        onSelect: () {
          final notifier = ref.read(settingsProvider.notifier);
          notifier.setShowPali(true);
          notifier.setShowTranslation(false);
          Navigator.of(context).pop();
        },
      ),
      _LayoutMode(
        icon: Icons.view_headline,
        tooltip: loc.displayLineByLine,
        caption: loc.displayLineByLineSubtitle,
        isSelected:
            showPali &&
            showTrans &&
            currentMode == TranslationDisplayMode.lineByLine,
        onSelect: () {
          final notifier = ref.read(settingsProvider.notifier);
          notifier.setShowPali(true);
          notifier.setShowTranslation(true);
          notifier.setTranslationDisplayMode(
            TranslationDisplayMode.lineByLine,
          );
          Navigator.of(context).pop();
        },
      ),
      _LayoutMode(
        icon: Icons.view_column,
        tooltip: loc.displaySideBySide,
        caption: loc.displaySideBySideSubtitle,
        isSelected:
            showPali &&
            showTrans &&
            currentMode == TranslationDisplayMode.sideBySide,
        onSelect: () {
          final notifier = ref.read(settingsProvider.notifier);
          notifier.setShowPali(true);
          notifier.setShowTranslation(true);
          notifier.setTranslationDisplayMode(
            TranslationDisplayMode.sideBySide,
          );
          Navigator.of(context).pop();
        },
      ),
      _LayoutMode(
        icon: Icons.article_outlined,
        tooltip: loc.displayOnlyTranslation,
        caption: loc.displayOnlyTranslationSubtitle,
        isSelected: showTrans && !showPali,
        onSelect: () {
          final notifier = ref.read(settingsProvider.notifier);
          notifier.setShowPali(false);
          notifier.setShowTranslation(true);
          Navigator.of(context).pop();
        },
      ),
    ];

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
              // Four modes as icon segments on a single line; the caption
              // below explains the selected one.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _LayoutModeSegment(modes: layoutModes),
              ),
              const SizedBox(height: 8),
              // Caption explaining the currently selected mode.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _LayoutModeCaption(modes: layoutModes),
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

        // Enabled languages sit at the top in the same order as the
        // Translations & Downloads settings screen — both read and write the
        // shared enabledTranslations list, so reordering here is reflected
        // there and vice versa. Drag the handle on an enabled row to reorder
        // it; disabled rows (below) can't be reordered because they aren't
        // part of the reading order.
        final downloadedCodes = versions.map((v) => v.languageCode).toSet();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (langCodes.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
                child: Text(
                  loc.dragToReorder,
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              children: langCodes.asMap().entries.map((entry) {
                final index = entry.key;
                final code = entry.value;
                final enabled = settings.enabledTranslations.contains(code);
                return _TranslationToggleTile(
                  key: ValueKey(code),
                  englishName: TranslationLanguageRegistry.englishName(code),
                  nativeName: TranslationLanguageRegistry.nativeName(code),
                  value: enabled,
                  dragIndex: enabled ? index : null,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .setTranslationEnabled(code, v),
                );
              }).toList(),
              onReorderItem: (oldIndex, newIndex) {
                // Visual order of the whole list (enabled first, then
                // disabled). onReorderItem already reports final indices.
                final visualOrder = List<String>.from(langCodes);
                final moved = visualOrder.removeAt(oldIndex);
                visualOrder.insert(newIndex, moved);

                // The new enabled order is the enabled codes in their
                // dragged positions; disabled codes are not part of
                // enabledTranslations.
                final newEnabledOrder = visualOrder
                    .where(settings.enabledTranslations.contains)
                    .toList();

                // Rebuild the FULL enabled list, keeping non-downloaded
                // (e.g. database deleted) languages in place and applying
                // the new order to the downloaded subset — same as the
                // settings screen does.
                final queue = List<String>.from(newEnabledOrder);
                final full = settings.enabledTranslations.map((code) {
                  if (!downloadedCodes.contains(code)) return code;
                  return queue.removeAt(0);
                }).toList();

                ref
                    .read(settingsProvider.notifier)
                    .setTranslationsOrder(full);
              },
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

  /// Non-null when this row is an enabled translation — shows a drag handle
  /// and makes the row reorderable within the popup.
  final int? dragIndex;
  final ValueChanged<bool> onChanged;

  const _TranslationToggleTile({
    super.key,
    required this.englishName,
    required this.nativeName,
    required this.value,
    this.dragIndex,
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
            if (dragIndex != null)
              ReorderableDragStartListener(
                index: dragIndex!,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.drag_indicator,
                    size: 18,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.55),
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

/// One selectable layout mode in the segmented control.
class _LayoutMode {
  final IconData icon;
  final String tooltip;
  final String caption;
  final bool isSelected;
  final VoidCallback onSelect;

  const _LayoutMode({
    required this.icon,
    required this.tooltip,
    required this.caption,
    required this.isSelected,
    required this.onSelect,
  });
}

/// A single-line segmented control of the four layout modes. The selected
/// segment is filled; every segment shows its label in a tooltip on
/// long-press/hover.
class _LayoutModeSegment extends StatelessWidget {
  final List<_LayoutMode> modes;

  const _LayoutModeSegment({required this.modes});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          for (final mode in modes) ...[
            Expanded(
              child: _LayoutModeSegmentButton(mode: mode),
            ),
          ],
        ],
      ),
    );
  }
}

/// One icon button inside [_LayoutModeSegment].
class _LayoutModeSegmentButton extends StatelessWidget {
  final _LayoutMode mode;

  const _LayoutModeSegmentButton({required this.mode});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: mode.tooltip,
      triggerMode: TooltipTriggerMode.longPress,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: mode.onSelect,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.symmetric(vertical: 8),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: mode.isSelected ? colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              mode.icon,
              size: 20,
              color: mode.isSelected
                  ? colors.onPrimary
                  : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// The caption under the segmented control explaining the selected mode.
class _LayoutModeCaption extends StatelessWidget {
  final List<_LayoutMode> modes;

  const _LayoutModeCaption({required this.modes});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    _LayoutMode? selected;
    for (final m in modes) {
      if (m.isSelected) {
        selected = m;
        break;
      }
    }
    return Text(
      (selected ?? modes.first).caption,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
    );
  }
}
