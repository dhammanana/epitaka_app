import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_typography.dart';

/// The main navigation drawer.
///
/// Contains:
/// - Tipitaka (with expandable children: Reading, Bookmarks)
/// - Search
/// - Gavesana
class MainDrawer extends StatefulWidget {
  const MainDrawer({super.key});

  @override
  State<MainDrawer> createState() => _MainDrawerState();
}

class _MainDrawerState extends State<MainDrawer> {
  bool _tipitakaExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.78,
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
                  child: Text(
                    'Pāli Tipiṭaka Reader',
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
                  title: 'Tipitaka',
                  trailing: Icon(
                    _tipitakaExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  onTap: () {
                    // Toggle children AND navigate to library
                    setState(() => _tipitakaExpanded = !_tipitakaExpanded);
                    if (_tipitakaExpanded) {
                      // Just expand, don't navigate yet
                    } else {
                      _closeAndGo(context, '/');
                    }
                  },
                  selected: _isRouteActive(context, '/'),
                ),

                // Children: Reading + Bookmarks
                if (_tipitakaExpanded) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: _DrawerChildItem(
                      icon: Icons.tab,
                      title: 'Reading',
                      onTap: () => _closeAndSwitchLibraryTab(context, 1),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: _DrawerChildItem(
                      icon: Icons.bookmark,
                      title: 'Bookmarks',
                      onTap: () => _closeAndSwitchLibraryTab(context, 2),
                    ),
                  ),
                ],

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
                  title: 'Search',
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

                // ── Gavesana ─────────────────────────────────
                _DrawerItem(
                  icon: Icons.psychology,
                  title: 'Gavesana',
                  subtitle: 'Semantic search',
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
                  title: 'Vimaṃsa',
                  subtitle: 'Investigation & exploration',
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
                      'Feedback',
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
                      'Settings',
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

  /// Navigate to library and switch to the given tab index.
  void _closeAndSwitchLibraryTab(BuildContext context, int tabIndex) {
    Navigator.of(context).pop(); // close drawer
    context.go('/?tab=$tabIndex');
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
  final Widget? trailing;
  final VoidCallback onTap;
  final bool selected;

  const _DrawerItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
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
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Drawer Child Item ───────────────────────────────────────────────────

class _DrawerChildItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DrawerChildItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 44), // icon area alignment
                Icon(icon, size: 14, color: colors.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
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
