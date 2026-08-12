import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../router/app_router.dart' show AppRoutes;

/// The main navigation drawer.
///
/// Contains:
/// - Tipitaka
/// - Search
/// - Gavesana
class MainDrawer extends StatefulWidget {
  const MainDrawer({super.key});

  @override
  State<MainDrawer> createState() => _MainDrawerState();
}

class _MainDrawerState extends State<MainDrawer> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.menu_book,
                        size: 20,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'ePitaka',
                      style: AppTypography.headlineLarge.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 46),
                  child:                    Text(
                      loc.paliTipitakaReader,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
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
                // ── Tipitaka ─────────────────────────────────
                _DrawerItem(
                  icon: Icons.menu_book,
                  title: loc.tipitaka,
                  onTap: () => _closeAndGo(context, '/'),
                  selected: _isRouteActive(context, '/'),
                ),

                const SizedBox(height: 4),
                Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: colors.outlineVariant.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 4),

                // ── Search ───────────────────────────────────
                _DrawerItem(
                  icon: Icons.search,
                  title: loc.search,
                  onTap: () => _closeAndGo(context, '/search?fromDrawer=true'),
                  selected: _isRouteActive(context, '/search'),
                ),

                const SizedBox(height: 4),
                Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: colors.outlineVariant.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 4),

                // ── Annotations ──────────────────────────────
                _DrawerItem(
                  icon: Icons.edit_note,
                  title: loc.annotations,
                  subtitle: loc.highlightsNotesBookmarks,
                  onTap: () =>
                      _closeAndGo(context, '/annotations?fromDrawer=true'),
                  selected: _isRouteActive(context, '/annotations'),
                ),

                const SizedBox(height: 4),
                Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: colors.outlineVariant.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 4),

                // ── Script Converter ─────────────────────────
                _DrawerItem(
                  icon: Icons.swap_horiz,
                  title: loc.scriptConverter,
                  subtitle: loc.scriptConverterSubtitle,
                  onTap: () => _closeAndGo(
                    context,
                    '/script-converter?fromDrawer=true',
                  ),
                  selected: _isRouteActive(context, '/script-converter'),
                ),

                const SizedBox(height: 4),
                Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: colors.outlineVariant.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 4),

                // ── Dictionary ────────────────────────────────
                _DrawerItem(
                  icon: Icons.menu_book_outlined,
                  title: loc.dictionary,
                  onTap: () => _closeAndGo(context, '/dictionary'),
                  selected: _isRouteActive(context, '/dictionary'),
                ),

                const SizedBox(height: 4),
                Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: colors.outlineVariant.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 4),

                // ── Gavesana ─────────────────────────────────
                _DrawerItem(
                  icon: Icons.psychology,
                  title: loc.gavesana,
                  subtitle: loc.semanticSearch,
                  onTap: () => _closeAndGo(context, '/gavesana'),
                  selected: _isRouteActive(context, '/gavesana'),
                ),

                const SizedBox(height: 4),
                Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: colors.outlineVariant.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 4),

                // ── Vimaṃsa ───────────────────────────────────
                _DrawerItem(
                  icon: Icons.auto_awesome,
                  title: loc.vimamsa,
                  subtitle: loc.investigationExploration,
                  onTap: () => _closeAndGo(context, '/ai-qa'),
                  selected: _isRouteActive(context, '/ai-qa'),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Feedback
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(); // close drawer
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
                    icon: Icon(
                      Icons.feedback_outlined,
                      size: 16,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    label: Text(
                      loc.feedback,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
                // Feature Guide (reopen the new-user instructions anytime)
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _closeAndGo(
                      context,
                      AppRoutes.featureGuide,
                    ),
                    icon: Icon(
                      Icons.explore_outlined,
                      size: 16,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    label: Text(
                      loc.featureGuide,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
                // Settings
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _closeAndGo(context, '/settings'),
                    icon: Icon(
                      Icons.settings,
                      size: 16,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    label: Text(
                      loc.settings,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _closeAndGo(BuildContext context, String route) {
    Navigator.of(context).pop(); // close drawer
    context.push(route);
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

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool selected;

  const _DrawerItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.selected = false,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
