import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/platform_info.dart';
import '../screens/appearance_settings_screen.dart';
import '../screens/context_menu_settings_screen.dart';
import '../screens/dictionary_settings_screen.dart';
import '../screens/help_screen.dart';
import '../screens/reading_options_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/shortcut_settings_screen.dart';
import '../screens/translation_settings_screen.dart';
import '../screens/tts_replacements_screen.dart';
import '../screens/tts_settings_screen.dart';
import '../screens/toolbar_settings_screen.dart';

const _lastCategoryKey = 'settings_last_category';

/// The id of the page the user last chose in the settings window, if any.
Future<String?> loadLastSettingsCategory() async {
  try {
    return (await SharedPreferences.getInstance()).getString(_lastCategoryKey);
  } catch (_) {
    return null;
  }
}

@visibleForTesting
Future<void> saveLastSettingsCategory(String id) async {
  try {
    await (await SharedPreferences.getInstance()).setString(_lastCategoryKey, id);
  } catch (_) {}
}

/// One entry in the macOS-style settings sidebar.
@visibleForTesting
class SettingsCategory {
  /// Stable across releases and platforms: this is what is saved, not the
  /// position, because some pages exist only on some platforms.
  final String id;
  final IconData icon;
  final String title;
  final Widget body;

  const SettingsCategory({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
  });
}

/// Shows the settings as a macOS-style window on desktop: a left sidebar to
/// choose a category, and a scrollable pane on the right to change it.
///
/// Every pane reuses the exact same body widgets as the mobile settings
/// screens (`AppearanceSettingsBody`, `SettingsGeneralSection`, …) so the
/// logic is identical — only the chrome differs.
Future<void> showDesktopSettingsDialog(BuildContext context) async {
  final loc = AppLocalizations.of(context);

  final categories = <SettingsCategory>[
    SettingsCategory(
      id: 'general',
      icon: Icons.tune,
      title: loc.general,
      body: _SectionPane(
        title: loc.general,
        child: const SettingsGeneralSection(),
      ),
    ),
    SettingsCategory(
      id: 'appearance',
      icon: Icons.palette_outlined,
      title: loc.appearance,
      body: const AppearanceSettingsBody(),
    ),
    SettingsCategory(
      id: 'reading',
      icon: Icons.menu_book_outlined,
      title: loc.readingOptions,
      body: const ReadingOptionsBody(),
    ),
    if (PlatformInfo.isTtsSupported) ...[
      SettingsCategory(
        id: 'tts',
        icon: Icons.record_voice_over_outlined,
        title: loc.textToSpeech,
        body: const TtsSettingsBody(),
      ),
      SettingsCategory(
        id: 'ttsReplacements',
        icon: Icons.find_replace_outlined,
        title: loc.ttsReplacements,
        body: const TtsReplacementsBody(),
      ),
    ],
    SettingsCategory(
      id: 'contextMenu',
      icon: Icons.touch_app_outlined,
      title: loc.contextMenu,
      body: const ContextMenuSettingsBody(),
    ),
    SettingsCategory(
      id: 'toolbar',
      icon: Icons.view_agenda_outlined,
      title: loc.toolbar,
      body: const ToolbarSettingsBody(),
    ),
    SettingsCategory(
      id: 'shortcuts',
      icon: Icons.keyboard_outlined,
      title: loc.keyboardShortcuts,
      body: const ShortcutSettingsBody(),
    ),
    SettingsCategory(
      id: 'search',
      icon: Icons.search,
      title: loc.search,
      body: _SectionPane(
        title: loc.search,
        child: const SettingsSearchSection(),
      ),
    ),
    SettingsCategory(
      id: 'dictionaries',
      icon: Icons.translate,
      title: loc.dictionaries,
      body: const DictionarySettingsBody(),
    ),
    SettingsCategory(
      id: 'translations',
      icon: Icons.download_outlined,
      title: loc.translationsDownloads,
      body: const TranslationSettingsBody(),
    ),
    SettingsCategory(
      id: 'vimamsa',
      icon: Icons.question_answer_outlined,
      title: loc.vimamsa,
      body: _SectionPane(title: loc.vimamsa, child: const SettingsAiSection()),
    ),
    SettingsCategory(
      id: 'account',
      icon: Icons.cloud_outlined,
      title: loc.account,
      body: _SectionPane(
        title: loc.account,
        child: const SettingsAccountSection(),
      ),
    ),
    SettingsCategory(
      id: 'system',
      icon: Icons.settings_suggest_outlined,
      title: loc.system,
      body: _SectionPane(
        title: loc.system,
        child: const SettingsSystemSection(),
      ),
    ),
    SettingsCategory(
      id: 'help',
      icon: Icons.help_outline,
      title: loc.help,
      body: const HelpScreenBody(),
    ),
  ];

  final lastId = await loadLastSettingsCategory();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    useSafeArea: false,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      insetPadding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      // Measured inside the builder so the window follows the app window
      // when it is resized or maximized while settings are open.
      child: Builder(
        builder: (ctx) {
          final screenSize = MediaQuery.sizeOf(ctx);
          // A wide screen gets a wider window so the sidebar shows every
          // category name in full; the content pane keeps its width. On a
          // narrower screen the sidebar gives the room back first, down to
          // its old width (names then end in "…" as before).
          final extra = _sidebarWidthFor(ctx, categories) - _kSidebarMinWidth;
          final width = (screenSize.width * 0.85).clamp(
            640.0,
            _kMaxWidthBefore + extra,
          );
          return SizedBox(
            width: width,
            height: (screenSize.height * 0.9).clamp(520.0, double.infinity),
            child: DesktopSettingsDialog(
              initialId: lastId,
              categories: categories,
              sidebarWidth: (_kSidebarMinWidth + width - _kMaxWidthBefore)
                  .clamp(_kSidebarMinWidth, _kSidebarMinWidth + extra),
            ),
          );
        },
      ),
    ),
  );
}

/// The macOS-style settings window: title bar, sidebar, content pane.
/// The sidebar's width before it could grow, and the window's widest size
/// then; small screens still get exactly these.
const double _kSidebarMinWidth = 230;
const double _kMaxWidthBefore = 960;

/// The sidebar width that shows the longest category name in full: the
/// selected (bold) title plus the row's icon, gap and paddings below.
double _sidebarWidthFor(
  BuildContext context,
  List<SettingsCategory> categories,
) {
  var widest = 0.0;
  for (final category in categories) {
    final painter = TextPainter(
      text: TextSpan(
        text: category.title,
        style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    if (painter.width > widest) widest = painter.width;
    painter.dispose();
  }
  // 8 + 10 padding each side, 18 icon, 10 gap, 4 to spare for rounding.
  final needed = (widest + 2 * 8 + 2 * 10 + 18 + 10 + 4).ceilToDouble();
  return needed < _kSidebarMinWidth ? _kSidebarMinWidth : needed;
}

@visibleForTesting
class DesktopSettingsDialog extends StatefulWidget {
  final List<SettingsCategory> categories;
  final double sidebarWidth;

  /// The id of the page to open on; the first page when it is not listed.
  final String? initialId;

  const DesktopSettingsDialog({
    super.key,
    required this.categories,
    required this.sidebarWidth,
    this.initialId,
  });

  @override
  State<DesktopSettingsDialog> createState() => DesktopSettingsDialogState();
}

class DesktopSettingsDialogState extends State<DesktopSettingsDialog> {
  late int _selected = _indexOf(widget.initialId);

  int _indexOf(String? id) {
    final i = widget.categories.indexWhere((c) => c.id == id);
    return i < 0 ? 0 : i;
  }

  void _select(int index) {
    setState(() => _selected = index);
    saveLastSettingsCategory(widget.categories[index].id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Column(
      children: [
        // ── Title bar ────────────────────────────────────────────────
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            border: Border(
              bottom: BorderSide(color: colors.outlineVariant, width: 1),
            ),
          ),
          child: Row(
            children: [
              // Balances the close button so the centered title stays
              // centered (traffic lights removed).
              const SizedBox(width: 48),
              Expanded(
                child: Text(
                  loc.settings,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: colors.onSurfaceVariant,
                tooltip: loc.close,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        // ── Sidebar + content ────────────────────────────────────────
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left sidebar
              Container(
                width: widget.sidebarWidth,
                color: colors.surfaceContainerLow,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: widget.categories.length,
                  itemBuilder: (context, index) {
                    final category = widget.categories[index];
                    final selected = index == _selected;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 1,
                      ),
                      child: Material(
                        color: selected
                            ? colors.secondaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () => _select(index),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  category.icon,
                                  size: 18,
                                  color: selected
                                      ? colors.onSecondaryContainer
                                      : colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    category.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.labelMedium.copyWith(
                                      color: selected
                                          ? colors.onSecondaryContainer
                                          : colors.onSurface,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Right content pane
              Expanded(
                child: ColoredBox(
                  color: colors.surface,
                  child: widget.categories[_selected].body,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Scrollable pane that wraps a section-based settings body (a non-scrolling
/// section widget) with a headline, matching the sub-screen bodies' look.
class _SectionPane extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionPane({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.md,
        AppDimensions.marginMobile,
        120,
      ),
      children: [
        Text(
          title,
          style: AppTypography.headlineLarge.copyWith(color: colors.onSurface),
        ),
        const SizedBox(height: AppDimensions.lg),
        child,
      ],
    );
  }
}
