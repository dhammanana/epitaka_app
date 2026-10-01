// lib/shared/utils/app_navigation.dart
//
// Route-navigation helpers shared across features.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/responsive_breakpoint.dart';
import '../../features/search/providers/search_provider.dart';
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

/// Open the search route with [query] filled in and run, the way an
/// incoming search link (share sheet, text-selection menu) should.
///
///   * Search not on top: push it, so Back returns to the screen the user
///     was on — the same as tapping the search button.
///   * Search already on top: no navigation. The open screen is told to run
///     the query through [incomingSearchProvider], so a second share never
///     stacks a second search screen and always searches again, even for the
///     same word after the user edited the box. Replacing the page instead
///     does not work: when search is the only page (opened from the drawer),
///     go_router keeps its page key and the old screen state.
void openSearchRoute(BuildContext context, String query) {
  if (GoRouter.of(context).state.matchedLocation == AppRoutes.search) {
    if (query.isEmpty) return;
    ProviderScope.containerOf(context, listen: false)
        .read(incomingSearchProvider.notifier)
        .state = IncomingSearch(query);
    return;
  }
  context.push(
    Uri(
      path: AppRoutes.search,
      queryParameters: {if (query.isNotEmpty) 'q': query},
    ).toString(),
  );
}
