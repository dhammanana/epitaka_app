// Regression tests for the Gavesana sidebar panel.
//
// The desktop sidebar's Gavesana panel must show the actual AI search UI
// directly (search bar + idle hint) instead of a gateway button that opens
// a separate window — desktop and mobile share one [GavesanaSearchView]
// widget. These tests pin that behavior so a future refactor can't
// silently turn the panel back into a "Open Gavesana" stub.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/utils/app_localizations.dart';
import '../lib/features/gavesana/widgets/gavesana_panel.dart';
import '../lib/features/gavesana/widgets/gavesana_search_view.dart';

/// Minimal MaterialApp with the app's localization delegates installed
/// (the Gavesana UI calls [AppLocalizations.of]).
Widget _app(Widget home) {
  return MaterialApp(
    supportedLocales: AppLocalizationsDelegate.supportedLocales,
    localizationsDelegates: const [
      AppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  );
}

Widget _build(Widget child) {
  return ProviderScope(child: _app(child));
}

void main() {
  group('GavesanaPanel — shows the search directly', () {
    testWidgets('embeds the shared search view (no gateway button)',
        (tester) async {
      await tester.pumpWidget(
        _build(const Scaffold(body: GavesanaPanel())),
      );
      await tester.pumpAndSettle();

      // The shared search widget is embedded.
      expect(find.byType(GavesanaSearchView), findsOneWidget);

      // The search field is present (the actual search, not a stub).
      expect(find.byType(TextField), findsOneWidget);

      // The gateway button that used to open a separate window is gone.
      expect(find.text(AppLocalizations.of(
        tester.element(find.byType(GavesanaPanel)),
      ).openGavesana), findsNothing);

      // The idle hint explaining how to use the search is shown.
      final loc = AppLocalizations.of(
        tester.element(find.byType(GavesanaPanel)),
      );
      expect(
        find.text(loc.searchSemantically),
        findsOneWidget,
        reason: 'idle state hint must render in the panel',
      );
    });

    testWidgets('dense panel still renders the query field', (tester) async {
      await tester.pumpWidget(
        _build(
          const Scaffold(
            body: SizedBox(
              width: 300,
              height: 500,
              child: GavesanaPanel(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GavesanaSearchView), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
