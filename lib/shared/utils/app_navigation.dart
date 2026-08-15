// lib/shared/utils/app_navigation.dart
//
// Route-navigation helpers shared across features.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/responsive_breakpoint.dart';
import '../../router/app_router.dart';

/// Open the reader route for the tab that was just activated via
/// [readerTabsProvider], WITHOUT stacking a duplicate `/reader` page.
///
/// Callers must have already opened/switched the reader tab — this function
/// only handles navigation. Previously every entry point pushed `/reader`
/// unconditionally, so once a book was opened from any screen that is itself
/// pushed on top of the reader (/search, /annotations, /ai-qa, /dictionary),
/// the back stack held TWO reader screens and getting back to the library
/// took several Back presses (one of them showing the same book again).
///
///   * Desktop: the reader is the permanent shell and sidebars open books
///     in place, so nothing is pushed (same as before).
///   * Mobile, `/reader` already in the stack (below the current screen):
///     pop back to the existing reader — the tab switch already put the
///     right book in it.
///   * Mobile, already ON `/reader`: nothing to do.
///   * Mobile, `/reader` NOT in the stack (opening a book from the
///     library): push `/reader` so Back returns to the book list.
void openReaderRoute(BuildContext context) {
  if (ResponsiveBreakpoint.isDesktop(context)) return;

  final matches =
      GoRouter.of(context).routerDelegate.currentConfiguration.matches;
  final readerInStack =
      matches.any((m) => m.matchedLocation == AppRoutes.reader);

  if (!readerInStack) {
    context.push(AppRoutes.reader);
  } else if (matches.lastOrNull?.matchedLocation != AppRoutes.reader &&
      context.canPop()) {
    context.pop();
  }
}
