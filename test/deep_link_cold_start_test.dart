import 'package:epitaka/features/deep_links/deep_link_service.dart';
import 'package:epitaka/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// On a cold start the index gate shows a loading screen first, so the
// navigator does not exist yet when the launch link (a shared text) arrives.
void main() {
  tearDown(() => DeepLinkService.instance.dispose());

  testWidgets('a search link that arrives before the app screens runs '
      'once they appear', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final gateOpen = ValueNotifier(false);
    final router = GoRouter(
      navigatorKey: navigatorKey,
      routes: [
        GoRoute(
          path: AppRoutes.library,
          builder: (context, state) => const Text('home'),
        ),
        GoRoute(
          path: AppRoutes.search,
          builder: (context, state) =>
              Text('search:${state.uri.queryParameters['q']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => ValueListenableBuilder<bool>(
            valueListenable: gateOpen,
            builder: (context, open, _) =>
                open
                    ? PendingDeepLinkRunner(child: child!)
                    : const Text('loading'),
          ),
        ),
      ),
    );

    // The app_links plugin call inside init only answers on the real clock.
    await tester.runAsync(() => DeepLinkService.instance.init(navigatorKey));
    DeepLinkService.instance.handleUri(Uri.parse('epitaka://search?q=dhamma'));
    await tester.pump();
    expect(find.text('loading'), findsOneWidget);

    gateOpen.value = true;
    await tester.pumpAndSettle();

    expect(router.state.matchedLocation, AppRoutes.search);
    expect(find.text('search:dhamma'), findsOneWidget);
  });
}
