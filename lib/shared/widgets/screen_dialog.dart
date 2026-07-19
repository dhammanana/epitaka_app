import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';

/// Shows a screen as a centered modal dialog that **embeds the real screen
/// widget** (e.g. [LibraryScreen], [SettingsScreen]) rather than a separate
/// dialog-only implementation.
///
/// This guarantees that edits to the original screen automatically appear
/// inside the dialog — there is a single source of truth for each screen.
///
/// The embedded screen keeps its own [Scaffold] + app bar (whose back/close
/// button calls `context.pop()`, which closes this dialog).
Future<T?> showScreenDialog<T>({
  required BuildContext context,
  required Widget child,
  double? width,
  double? height,
}) async {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final screenHeight = MediaQuery.sizeOf(context).height;

  final dialogWidth = width ?? (screenWidth * 0.9).clamp(360.0, 1100.0);
  final dialogHeight = height ?? (screenHeight * 0.9).clamp(480.0, 900.0);

  return showDialog<T>(
    context: context,
    useSafeArea: false,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      insetPadding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: SizedBox(width: dialogWidth, height: dialogHeight, child: child),
    ),
  );
}
