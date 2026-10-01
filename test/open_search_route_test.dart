import 'package:epitaka/features/search/providers/search_provider.dart';
import 'package:epitaka/router/app_router.dart';
import 'package:epitaka/shared/utils/app_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late GoRouter router;
  late ProviderContainer container;
  late BuildContext homeContext;
  late BuildContext searchContext;

  Future<void> pumpRouter(WidgetTester tester) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    router = GoRouter(
      routes: [
        GoRoute(
          path: AppRoutes.library,
          builder: (context, state) {
            homeContext = context;
            return const Text('home');
          },
        ),
        GoRoute(
          path: AppRoutes.search,
          builder: (context, state) {
            searchContext = context;
            return Text('search:${state.uri.queryParameters['q']}');
          },
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  int depth() => router.routerDelegate.currentConfiguration.matches.length;

  testWidgets('opens search on top of the current screen', (tester) async {
    await pumpRouter(tester);
    openSearchRoute(homeContext, 'dhamma');
    await tester.pumpAndSettle();

    expect(depth(), 2);
    expect(router.state.uri.queryParameters['q'], 'dhamma');
    expect(find.text('search:dhamma'), findsOneWidget);
    expect(container.read(incomingSearchProvider), isNull);
  });

  testWidgets('with search on top, the open screen is asked to search',
      (tester) async {
    await pumpRouter(tester);
    openSearchRoute(homeContext, 'dhamma');
    await tester.pumpAndSettle();
    openSearchRoute(searchContext, 'vinaya');
    await tester.pumpAndSettle();

    expect(depth(), 2);
    expect(router.state.uri.queryParameters['q'], 'dhamma');
    expect(container.read(incomingSearchProvider)?.query, 'vinaya');
  });

  testWidgets('a drawer-opened search keeps its route and drawer flag',
      (tester) async {
    await pumpRouter(tester);
    router.go('/search?fromDrawer=true');
    await tester.pumpAndSettle();
    openSearchRoute(searchContext, 'dhamma');
    await tester.pumpAndSettle();

    expect(depth(), 1);
    expect(router.state.uri.queryParameters, {'fromDrawer': 'true'});
    expect(container.read(incomingSearchProvider)?.query, 'dhamma');
  });

  testWidgets('a blank query on an open search does nothing', (tester) async {
    await pumpRouter(tester);
    router.go('/search');
    await tester.pumpAndSettle();
    openSearchRoute(searchContext, '');
    await tester.pumpAndSettle();

    expect(depth(), 1);
    expect(container.read(incomingSearchProvider), isNull);
  });
}
