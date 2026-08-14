import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_localizations.dart';

/// Shows a dismissible "What's New" dialog after an app update.
///
/// The changelog content lives in the bundled `assets/changelog.md` asset,
/// which `scripts/build-release.sh` regenerates from `git log` before each
/// release build. The dialog appears once per installed build: the build
/// number of the currently running app is compared against the last-seen
/// build number stored in SharedPreferences, and when they differ the
/// dialog is shown and the build number is recorded on dismissal.
class ChangelogService {
  static const String _lastSeenBuildKey = 'last_seen_changelog_build';

  /// Checks whether a new build is installed and, if so, shows the
  /// "What's New" dialog over [navigatorKey]. Returns without showing
  /// anything when the build is unchanged or no changelog content exists.
  static Future<void> showIfNewBuild(GlobalKey<NavigatorState> navigatorKey) async {
    final buildNumber = await _currentBuildNumber();
    if (buildNumber == null) return;

    final prefs = await SharedPreferences.getInstance();
    final lastSeen = prefs.getInt(_lastSeenBuildKey);
    if (lastSeen == buildNumber) return;

    final changelog = await _loadChangelog();
    if (changelog.isEmpty) {
      // Nothing to show — remember the build so we don't check again.
      await prefs.setInt(_lastSeenBuildKey, buildNumber);
      return;
    }

    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ChangelogDialog(
        changelog: changelog,
        onDismiss: () {
          // Record the build so the dialog isn't shown again until the
          // next update.
          prefs.setInt(_lastSeenBuildKey, buildNumber);
        },
      ),
    );
  }

  static Future<int?> _currentBuildNumber() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return int.tryParse(info.buildNumber);
    } catch (_) {
      return null;
    }
  }

  /// Reads the bundled changelog markdown, or an empty string when the
  /// asset is missing (e.g. a debug build that never ran the release script).
  static Future<String> _loadChangelog() async {
    try {
      final raw = await rootBundle.loadString('assets/changelog.md');
      return raw.trim();
    } catch (_) {
      return '';
    }
  }
}

/// "What's New" dialog showing the changelog for the installed build.
class _ChangelogDialog extends StatelessWidget {
  final String changelog;
  final VoidCallback onDismiss;

  const _ChangelogDialog({required this.changelog, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.new_releases_outlined, color: colors.primary),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Text(
              loc.whatsNew,
              style: AppTypography.headlineSmall.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400),
        child: SingleChildScrollView(
          child: MarkdownBody(
            data: changelog,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                color: colors.onSurface,
                fontSize: 14,
                height: 1.5,
              ),
              listBullet: TextStyle(color: colors.primary),
              h1: TextStyle(
                color: colors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              h2: TextStyle(
                color: colors.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            onDismiss();
            Navigator.of(context).pop();
          },
          child: Text(loc.gotIt),
        ),
      ],
    );
  }
}
