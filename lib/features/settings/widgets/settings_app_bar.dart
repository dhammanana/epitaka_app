import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// Standard back-arrow app bar used on all settings sub-screens.
///
/// Uses Flutter's [AppBar] so the OS status-bar safe area is handled
/// automatically on every platform (no manual [MediaQuery.padding.top] needed).
class SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ColorScheme colors;

  const SettingsAppBar({super.key, required this.colors});

  @override
  // AppBar adds status-bar height on top of toolbarHeight automatically.
  Size get preferredSize => const Size.fromHeight(AppDimensions.appBarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: AppDimensions.appBarHeight,
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: colors.outlineVariant),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        color: colors.primary,
        onPressed: () => context.pop(),
      ),
      title: Text(
        'ePitaka',
        style: AppTypography.displayPali.copyWith(color: colors.primary),
      ),
      centerTitle: true,
      // Balanced placeholder so the title stays centred.
      actions: const [SizedBox(width: 40)],
    );
  }
}
