// An incoming search link (share sheet, text-selection menu) opens the
// search screen with a query. The screen must fill the box and run the
// search exactly as if the user had typed it and pressed Enter.
library;

import 'package:epitaka/core/database/app_database.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/search/providers/search_provider.dart';
import 'package:epitaka/features/search/widgets/search_screen.dart';
import 'package:epitaka/router/app_router.dart';
import 'package:epitaka/shared/utils/app_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSearchNotifier extends SearchNotifier {
  _FakeSearchNotifier(super.ref);

  final calls = <({String query, int distance})>[];

  @override
  Future<void> ensureIndexBuilt() async {}

  @override
  Future<List<SearchSuggestion>> getSuggestions(String prefix) async => [];

  @override
  Future<void> search({required String query, int distance = 0}) async {
    calls.add((query: query, distance: distance));
  }
}

Future<_FakeSearchNotifier> _pumpRouter(
  WidgetTester tester,
  GoRouter router,
) async {
  late _FakeSearchNotifier fake;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        searchProvider.overrideWith((ref) => fake = _FakeSearchNotifier(ref)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        supportedLocales: AppLocalizationsDelegate.supportedLocales,
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return fake;
}

Future<_FakeSearchNotifier> _pumpSearch(
  WidgetTester tester,
  String? initialQuery,
) =>
    _pumpRouter(
      tester,
      GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                SearchScreen(initialQuery: initialQuery),
          ),
        ],
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('an initial query is typed in and searched once',
      (tester) async {
    final fake = await _pumpSearch(tester, 'dhamma vinaya');

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, 'dhamma vinaya');
    expect(fake.calls, [(query: 'dhamma vinaya', distance: 3)]);
  });

  testWidgets('no initial query runs no search', (tester) async {
    final fake = await _pumpSearch(tester, null);

    expect(fake.calls, isEmpty);
  });

  testWidgets('the real /search route hands q to the search screen',
      (tester) async {
    final router = buildRouter()..go('/search?q=dhamma');
    final fake = await _pumpRouter(tester, router);

    expect(fake.calls, [(query: 'dhamma', distance: 0)]);
  });

  testWidgets('a repeat share on an open search runs the search again',
      (tester) async {
    final router = buildRouter()..go('/search?q=dhamma');
    final fake = await _pumpRouter(tester, router);

    BuildContext screen() => tester.element(find.byType(SearchScreen));
    openSearchRoute(screen(), 'dhamma');
    await tester.pump();
    openSearchRoute(screen(), 'vinaya');
    await tester.pump();

    expect(fake.calls, [
      (query: 'dhamma', distance: 0),
      (query: 'dhamma', distance: 0),
      (query: 'vinaya', distance: 0),
    ]);
    expect(find.byType(SearchScreen), findsOneWidget);
  });
}
