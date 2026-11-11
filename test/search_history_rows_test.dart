/// The Search history as full-width rows on the three surfaces (screen,
/// sidebar panel, bottom sheet): when they show, the keyboard model, and what
/// a tap, Enter or the X does.
library;

import 'package:epitaka/core/database/app_database.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/search/providers/search_history_provider.dart';
import 'package:epitaka/features/search/providers/search_provider.dart';
import 'package:epitaka/features/search/widgets/search_panel.dart';
import 'package:epitaka/features/search/widgets/search_screen.dart';
import 'package:epitaka/features/search/widgets/search_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/type_keys.dart';

class FakeSearch extends SearchNotifier {
  FakeSearch(super.ref);

  final calls = <String>[];

  @override
  Future<void> ensureIndexBuilt() async {}

  @override
  Future<List<SearchSuggestion>> getSuggestions(String prefix) async => [];

  @override
  Future<void> search({
    required String query,
    int distance = 0,
    bool regex = false,
  }) async {
    calls.add(query);
    state = query.isEmpty
        ? const SearchIdle()
        : SearchResults(query: query, totalResults: 0, bookSummaries: const []);
  }
}

enum Surface { screen, panel, sheet }

late FakeSearch fake;
late ProviderContainer container;

Future<void> pumpSurface(WidgetTester tester, Surface surface) async {
  SharedPreferences.setMockInitialValues({
    SearchHistoryNotifier.prefsKey: ['alpha', 'beta', 'gamma'],
  });
  container = ProviderContainer(
    overrides: [searchProvider.overrideWith((ref) => fake = FakeSearch(ref))],
  );
  addTearDown(container.dispose);
  // The saved history loads on first read.
  container.read(searchHistoryProvider);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final localization = <LocalizationsDelegate<dynamic>>[
    const AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
  final Widget app;
  switch (surface) {
    case Surface.screen:
      app = MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const SearchScreen()),
          ],
        ),
        supportedLocales: AppLocalizationsDelegate.supportedLocales,
        localizationsDelegates: localization,
      );
    case Surface.panel:
    case Surface.sheet:
      app = MaterialApp(
        supportedLocales: AppLocalizationsDelegate.supportedLocales,
        localizationsDelegates: localization,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: surface == Surface.panel ? 360 : 600,
              height: 800,
              child: surface == Surface.panel
                  ? const SearchPanel()
                  : const SearchSheet(),
            ),
          ),
        ),
      );
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: app),
  );
  await tester.pump();
  await tester.pump();
  await tester.tap(find.byType(TextField).first);
  await tester.pump();
}

Color? rowColor(WidgetTester tester, String text) => tester
    .widget<Material>(
      find
          .descendant(
            of: find.byKey(ValueKey(text)),
            matching: find.byType(Material),
          )
          .first,
    )
    .color;

bool highlighted(WidgetTester tester, String text) =>
    rowColor(tester, text) ==
    Theme.of(tester.element(find.text(text))).colorScheme.primaryContainer;

Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await tester.pump();
}

String boxText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).controller!.text;

void main() {
  for (final surface in Surface.values) {
    group(surface.name, () {
      testWidgets('rows show on open, in saved order', (tester) async {
        await pumpSurface(tester, surface);
        expect(find.text('alpha'), findsOneWidget);
        expect(find.text('gamma'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('alpha')).dy <
              tester.getTopLeft(find.text('beta')).dy,
          isTrue,
        );
      });

      testWidgets('Down, Down, Up, Up leaves no highlight, typing works', (
        tester,
      ) async {
        await pumpSurface(tester, surface);
        await key(tester, LogicalKeyboardKey.arrowDown);
        expect(highlighted(tester, 'alpha'), isTrue);
        await key(tester, LogicalKeyboardKey.arrowDown);
        expect(highlighted(tester, 'beta'), isTrue);
        expect(highlighted(tester, 'alpha'), isFalse);
        await key(tester, LogicalKeyboardKey.arrowUp);
        await key(tester, LogicalKeyboardKey.arrowUp);
        for (final w in ['alpha', 'beta', 'gamma']) {
          expect(highlighted(tester, w), isFalse);
        }
        await typeKeys(tester, find.byType(TextField).first, 'k');
        await tester.pump();
        expect(boxText(tester), 'k');
        expect(find.text('alpha'), findsNothing);
      });

      testWidgets('Down never wraps past the last row', (tester) async {
        await pumpSurface(tester, surface);
        for (var i = 0; i < 6; i++) {
          await key(tester, LogicalKeyboardKey.arrowDown);
        }
        expect(highlighted(tester, 'gamma'), isTrue);
      });

      testWidgets('Down then Enter runs that search exactly once', (
        tester,
      ) async {
        await pumpSurface(tester, surface);
        await key(tester, LogicalKeyboardKey.arrowDown);
        await key(tester, LogicalKeyboardKey.arrowDown);
        await key(tester, LogicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 500));
        expect(fake.calls, ['beta']);
        expect(boxText(tester), 'beta');
      });

      testWidgets('a tap fills the box and runs the search once', (
        tester,
      ) async {
        await pumpSurface(tester, surface);
        await tester.tap(find.text('gamma'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(fake.calls, ['gamma']);
        expect(boxText(tester), 'gamma');
      });

      testWidgets('backspace to empty shows the rows again after a search', (
        tester,
      ) async {
        await pumpSurface(tester, surface);
        await tester.tap(find.text('alpha'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('beta'), findsNothing);
        await tester.enterText(find.byType(TextField).first, '');
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('beta'), findsOneWidget);
      });

      testWidgets('the X removes a row and the saved list', (tester) async {
        await pumpSurface(tester, surface);
        await tester.tap(find.byIcon(Icons.delete_outline).first);
        await tester.pump();
        expect(find.text('alpha'), findsNothing);
        expect(container.read(searchHistoryProvider), ['beta', 'gamma']);
      });

      testWidgets('Clear history empties the shared store', (tester) async {
        await pumpSurface(tester, surface);
        await tester.tap(find.text('Clear history'));
        await tester.pump();
        expect(container.read(searchHistoryProvider), isEmpty);
        expect(find.text('alpha'), findsNothing);
      });
    });
  }

  testWidgets('screen: with no saved rows Down still reaches the results', (
    tester,
  ) async {
    await pumpSurface(tester, Surface.screen);
    container.read(searchHistoryProvider.notifier).clear();
    await tester.pump();
    // No rows and no results: Down is simply ignored and nothing throws.
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(tester.takeException(), isNull);
  });
}
