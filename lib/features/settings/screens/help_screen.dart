import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../widgets/settings_app_bar.dart';

/// Help screen documenting keyboard shortcuts and other tips.
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: SettingsAppBar(colors: colors),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.marginMobile,
          AppDimensions.md,
          AppDimensions.marginMobile,
          120,
        ),
        children: [
          Text(
            loc.help,
            style: AppTypography.headlineLarge.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          _ShortcutsSection(colors: colors, loc: loc),
          const SizedBox(height: AppDimensions.lg),

          // ── Send Feedback ────────────────────────────────────────
          _FeedbackTile(colors: colors, loc: loc),
        ],
      ),
    );
  }
}

/// A tile that opens the default email client to send feedback.
class _FeedbackTile extends StatelessWidget {
  final ColorScheme colors;
  final AppLocalizations loc;

  const _FeedbackTile({required this.colors, required this.loc});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: InkWell(
          onTap: () async {
            final uri = Uri(
              scheme: 'mailto',
              path: 'epitaka.org@gmail.com',
              queryParameters: {
                'subject': 'ePitaka Feedback',
                'body': '',
              },
            );
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusMd,
                    ),
                  ),
                  child: Icon(
                    Icons.feedback_outlined,
                    color: colors.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.sendFeedback,
                        style: AppTypography.labelMedium.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'epitaka.org@gmail.com',
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new, color: colors.onSurfaceVariant, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutsSection extends StatelessWidget {
  final ColorScheme colors;
  final AppLocalizations loc;

  const _ShortcutsSection({required this.colors, required this.loc});

  @override
  Widget build(BuildContext context) {
    final items = [
      _Shortcut(loc.searchInBook, 'Ctrl/⌘ + F'),
      _Shortcut(loc.globalSearch, 'Ctrl/⌘ + Shift + F'),
      _Shortcut(loc.closeFocusTab, 'Ctrl/⌘ + W'),
      _Shortcut(loc.closeAllTabs, 'Ctrl/⌘ + Shift + W'),
      _Shortcut(loc.openDictionary, 'Ctrl/⌘ + D'),
      _Shortcut(loc.openLibrary, 'Ctrl/⌘ + N'),
      _Shortcut(loc.openSettings, 'Ctrl/⌘ + ,'),
      _Shortcut(loc.increaseFontSize, 'Ctrl/⌘ + +'),
      _Shortcut(loc.decreaseFontSize, 'Ctrl/⌘ + -'),
      _Shortcut('Switch to Tab 1-9', 'Ctrl/⌘ + 1-9'),
      _Shortcut('Next Tab', 'Ctrl + Tab'),
      _Shortcut('Previous Tab', 'Ctrl + Shift + Tab'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Text(
              loc.keyboardShortcuts,
              style: AppTypography.labelMedium.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...items.asMap().entries.map((entry) {
            final isLast = entry.key == items.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md,
                    vertical: AppDimensions.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.value.label,
                          style: AppTypography.labelMedium.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      _Kbd(entry.value.keys, colors),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: colors.outlineVariant,
                    indent: AppDimensions.md,
                    endIndent: AppDimensions.md,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _Shortcut {
  final String label;
  final String keys;

  const _Shortcut(this.label, this.keys);
}

class _Kbd extends StatelessWidget {
  final String text;
  final ColorScheme colors;

  const _Kbd(this.text, this.colors);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall.copyWith(
          color: colors.onSurfaceVariant,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
