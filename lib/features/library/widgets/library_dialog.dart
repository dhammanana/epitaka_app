import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/responsive_breakpoint.dart';
import '../../../features/reader/providers/reader_tabs_provider.dart';
import '../../../shared/widgets/screen_dialog.dart';
import '../screens/library_screen.dart';

/// Show the library as a dialog on desktop.
///
/// The dialog **embeds the real [LibraryScreen]** so there is a single source
/// of truth — any future edit to [LibraryScreen] is reflected here
/// automatically. On mobile this is a no-op; callers should fall back to the
/// full-page `/` route instead.
///
/// The desktop dialog is intentionally compact: it drops the in-screen app
/// bar (the dialog itself provides the close affordance) and is sized to
/// roughly half the current window width.
Future<void> showLibraryDialog(BuildContext context) async {
  if (!ResponsiveBreakpoint.isDesktop(context)) return;

  final screenWidth = MediaQuery.sizeOf(context).width;
  // Half the current window width, clamped to a comfortable range.
  final dialogWidth = (screenWidth * 0.5).clamp(360.0, 720.0);
  final dialogHeight = (MediaQuery.sizeOf(context).height * 0.9).clamp(
    480.0,
    900.0,
  );

  await showScreenDialog(
    context: context,
    width: dialogWidth,
    height: dialogHeight,
    child: const _LibraryDialogContent(),
  );
}

class _LibraryDialogContent extends ConsumerWidget {
  const _LibraryDialogContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(readerTabsProvider, (prev, next) {
      if (prev?.isEmpty == true && next.isNotEmpty) {
        // A book was opened — close the dialog to reveal the reader.
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });

    return const LibraryScreen(showAppBar: false);
  }
}
