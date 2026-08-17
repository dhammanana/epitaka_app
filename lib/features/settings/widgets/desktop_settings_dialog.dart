import 'package:flutter/material.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../screens/appearance_settings_screen.dart';
import '../screens/context_menu_settings_screen.dart';
import '../screens/dictionary_settings_screen.dart';
import '../screens/help_screen.dart';
import '../screens/reading_options_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/translation_settings_screen.dart';
import '../screens/tts_replacements_screen.dart';
import '../screens/tts_settings_screen.dart';
import '../screens/toolbar_settings_screen.dart';

/// One entry in the macOS-style settings sidebar.
class _SettingsCategory {
  final IconData icon;
  final String title;
  final Widget body;

  const _SettingsCategory({
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

  final categories = <_SettingsCategory>[
    _SettingsCategory(
      icon: Icons.tune,
      title: loc.general,
      body: _SectionPane(title: loc.general, child: const SettingsGeneralSection()),
    ),
    _SettingsCategory(
      icon: Icons.palette_outlined,
      title: loc.appearance,
      body: const AppearanceSettingsBody(),
    ),
    _SettingsCategory(
      icon: Icons.menu_book_outlined,
      title: loc.readingOptions,
      body: const ReadingOptionsBody(),
    ),
    _SettingsCategory(
      icon: Icons.record_voice_over_outlined,
      title: loc.textToSpeech,
      body: const TtsSettingsBody(),
    ),
    _SettingsCategory(
      icon: Icons.find_replace_outlined,
      title: loc.ttsReplacements,
      body: const TtsReplacementsBody(),
    ),
    _SettingsCategory(
      icon: Icons.touch_app_outlined,
      title: loc.contextMenu,
      body: const ContextMenuSettingsBody(),
    ),
    _SettingsCategory(
      icon: Icons.view_agenda_outlined,
      title: loc.toolbar,
      body: const ToolbarSettingsBody(),
    ),
    _SettingsCategory(
      icon: Icons.search,
      title: loc.search,
      body: _SectionPane(title: loc.search, child: const SettingsSearchSection()),
    ),
    _SettingsCategory(
      icon: Icons.translate,
      title: loc.dictionaries,
      body: const DictionarySettingsBody(),
    ),
    _SettingsCategory(
      icon: Icons.download_outlined,
      title: loc.translationsDownloads,
      body: const TranslationSettingsBody(),
    ),
    _SettingsCategory(
      icon: Icons.question_answer_outlined,
      title: loc.aiQa,
      body: _SectionPane(title: loc.aiQa, child: const SettingsAiSection()),
    ),
    _SettingsCategory(
      icon: Icons.cloud_outlined,
      title: loc.account,
      body: _SectionPane(title: loc.account, child: const SettingsAccountSection()),
    ),
    _SettingsCategory(
      icon: Icons.settings_suggest_outlined,
      title: loc.system,
      body: _SectionPane(title: loc.system, child: const SettingsSystemSection()),
    ),
    _SettingsCategory(
      icon: Icons.help_outline,
      title: loc.help,
      body: const HelpScreenBody(),
    ),
  ];

  final screenSize = MediaQuery.sizeOf(context);
  final width = (screenSize.width * 0.92).clamp(680.0, 1120.0);
  final height = (screenSize.height * 0.92).clamp(520.0, 880.0);

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
      child: SizedBox(
        width: width,
        height: height,
        child: _DesktopSettingsDialog(categories: categories),
      ),
    ),
  );
}

/// The macOS-style settings window: title bar, sidebar, content pane.
class _DesktopSettingsDialog extends StatefulWidget {
  final List<_SettingsCategory> categories;

  const _DesktopSettingsDialog({required this.categories});

  @override
  State<_DesktopSettingsDialog> createState() => _DesktopSettingsDialogState();
}

class _DesktopSettingsDialogState extends State<_DesktopSettingsDialog> {
  int _selected = 0;

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
              // macOS-style traffic-light placeholder (decorative).
              Row(
                children: [
                  _TrafficLight(color: const Color(0xffff5f57)),
                  const SizedBox(width: 6),
                  _TrafficLight(color: const Color(0xfffebc2e)),
                  const SizedBox(width: 6),
                  _TrafficLight(color: const Color(0xff28c840)),
                ],
              ),
              const SizedBox(width: AppDimensions.md),
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
                width: 230,
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
                          onTap: () => setState(() => _selected = index),
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

/// Decorative macOS traffic-light dot in the title bar.
class _TrafficLight extends StatelessWidget {
  final Color color;

  const _TrafficLight({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
