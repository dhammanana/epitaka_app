import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../router/app_router.dart' show AppRoutes;
import '../../../shared/utils/app_navigation.dart';
import '../../reader/providers/reader_tabs_provider.dart';

/// The main navigation drawer.
///
/// Contains:
/// - Tipitaka
/// - Search
/// - Gavesana
class MainDrawer extends ConsumerStatefulWidget {
  const MainDrawer({super.key});

  @override
  ConsumerState<MainDrawer> createState() => _MainDrawerState();
}

class _MainDrawerState extends ConsumerState<MainDrawer> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final tabsState = ref.watch(readerTabsProvider);

    // ~78% of the screen on portrait phones, but capped so the drawer never
    // dominates landscape / tablet / desktop windows (Material 3 caps
    // navigation drawers at 360dp).
    return Drawer(
      width: math.min(MediaQuery.sizeOf(context).width * 0.78, 360.0),
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              left: 20,
              right: 20,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                bottom: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/icon.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'ePitaka',
                  style: AppTypography.headlineLarge.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                  ),
                ),
              ],
            ),
          ),

          // ── Navigation items ───────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8),
              children: [
                // ── Group 1: Tipiṭaka + Vīmaṃsā ──────────────
                _DrawerItem(
                  icon: Icons.menu_book,
                  title: loc.tipitaka,
                  onTap: () => _closeAndGo(context, '/'),
                  selected: _isRouteActive(context, '/'),
                  // Reading button — only when books are open; jumps back
                  // to the reader without touching the route history.
                  trailing: tabsState.isNotEmpty
                      ? _ReaderButton(
                          tooltip: tabsState.activeTab?.bookName ?? loc.reading,
                          onTap: () {
                            Navigator.of(context).pop(); // close drawer
                            openReaderRoute(context);
                          },
                        )
                      : null,
                ),
                _DrawerItem(
                  icon: Icons.auto_awesome,
                  title: loc.vimamsa,
                  subtitle: loc.investigationExploration,
                  onTap: () => _closeAndGo(context, '/ai-qa'),
                  selected: _isRouteActive(context, '/ai-qa'),
                ),

                _DrawerDivider(colors: colors),

                // ── Group 2: Search + Gavesanā ────────────────
                _DrawerItem(
                  icon: Icons.search,
                  title: loc.search,
                  onTap: () => _closeAndGo(context, '/search?fromDrawer=true'),
                  selected: _isRouteActive(context, '/search'),
                ),
                _DrawerItem(
                  icon: Icons.psychology,
                  title: loc.gavesana,
                  subtitle: loc.semanticSearch,
                  onTap: () =>
                      _closeAndGo(context, '/gavesana?fromDrawer=true'),
                  selected: _isRouteActive(context, '/gavesana'),
                ),

                _DrawerDivider(colors: colors),

                // ── Group 3: Annotations ────────────
                _DrawerItem(
                  icon: Icons.edit_note,
                  title: loc.annotations,
                  onTap: () =>
                      _closeAndGo(context, '/annotations?fromDrawer=true'),
                  selected: _isRouteActive(context, '/annotations'),
                ),

                _DrawerDivider(colors: colors),

                // ── Group 4: Dictionary + Script + Translator ─
                _DrawerItem(
                  icon: Icons.menu_book_outlined,
                  title: loc.dictionary,
                  onTap: () =>
                      _closeAndGo(context, '/dictionary?fromDrawer=true'),
                  selected: _isRouteActive(context, '/dictionary'),
                ),
                _DrawerItem(
                  icon: Icons.swap_horiz,
                  title: loc.scriptConverter,
                  onTap: () =>
                      _closeAndGo(context, '/script-converter?fromDrawer=true'),
                  selected: _isRouteActive(context, '/script-converter'),
                ),
                _DrawerItem(
                  icon: Icons.translate,
                  title: loc.t('Translation Builder'),
                  subtitle: loc.t('Translate books on-device with AI'),
                  onTap: () =>
                      _closeAndGo(context, '/translator?fromDrawer=true'),
                  selected: _isRouteActive(context, '/translator'),
                ),
              ],
            ),
          ),

          // ── Footer ─────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              left: 8,
              right: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
              top: 4,
            ),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _DrawerIconButton(
                    icon: Icons.feedback_outlined,
                    tooltip: loc.feedback,
                    onTap: () {
                      Navigator.of(context).pop();
                      launchUrl(
                        Uri(
                          scheme: 'mailto',
                          path: 'epitaka.org@gmail.com',
                          queryParameters: {
                            'subject': 'ePitaka Feedback',
                            'body': '',
                          },
                        ),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                  _DrawerIconButton(
                    icon: Icons.explore_outlined,
                    tooltip: loc.featureGuide,
                    onTap: () => _closeAndGo(context, AppRoutes.featureGuide),
                  ),
                  _DrawerIconButton(
                    icon: Icons.settings_outlined,
                    tooltip: loc.settings,
                    onTap: () => _closeAndGo(context, '/settings'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _closeAndGo(BuildContext context, String route) {
    Navigator.of(context).pop(); // close drawer
    context.go(route);
  }

  bool _isRouteActive(BuildContext context, String route) {
    final uri = Uri.tryParse(GoRouterState.of(context).uri.toString());
    if (uri == null) return false;
    // Strip query params for comparison
    final currentPath = uri.path;
    return currentPath == route;
  }
}

// ── Drawer Item ─────────────────────────────────────────────────────────

// ── Drawer Divider (between groups) ────────────────────────────────

class _DrawerDivider extends StatelessWidget {
  final ColorScheme colors;

  const _DrawerDivider({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Divider(
        height: 1,
        thickness: 1,
        color: colors.outlineVariant.withValues(alpha: 0.3),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool selected;
  final Widget? trailing;

  const _DrawerItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.selected = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: selected
            ? colors.primaryContainer.withValues(alpha: 0.3)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.primary.withValues(alpha: 0.1)
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.labelMedium.copyWith(
                          color: selected ? colors.primary : colors.onSurface,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reader shortcut button (Tipitaka row trailing) ────────────────────

/// Small button beside the Tipitaka row that jumps back to the open book.
///
/// Shown only while reader tabs exist. Tapping it closes the drawer and
/// returns to the reader without pushing or popping route history.
class _ReaderButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;

  const _ReaderButton({required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.play_arrow, size: 18, color: colors.primary),
        ),
      ),
    );
  }
}

// ── Drawer Icon Button (footer row) ────────────────────────────────

class _DrawerIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _DrawerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}
