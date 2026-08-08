/// Verifies the "Show book links" checkbox in the reader's display layout
/// popup toggles the setting (temporarily, without persisting) and that the
/// checkbox reflects the current setting value.
library;

import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/reader/widgets/display_layout_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Widget wrap(Widget child) => ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) {
            final notifier = SettingsNotifier(null);
            notifier.state = const AppSettings();
            return notifier;
          }),
        ],
        child: MaterialApp(
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [AppLocalizationsDelegate()],
          // The default Material 3 ink-sparkle splash tries to load the
          // 'shaders/ink_sparkle.frag' asset on tap, which doesn't exist in
          // the test environment. The classic ripple needs no shader asset.
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkSplash.splashFactory,
          ),
          home: Scaffold(body: child),
        ),
      );

  testWidgets('popup checkbox reflects and toggles showBookLinks', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const DisplayLayoutPopup()));
    await tester.pumpAndSettle();

    final checkbox = find.byType(Checkbox);
    expect(checkbox, findsOneWidget);
    // Default AppSettings has showBookLinks = true.
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);

    // Tap the row to hide book links.
    await tester.tap(find.text('Show Book Links'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(checkbox).value, isFalse);

    // Tap again to re-enable.
    await tester.tap(find.text('Show Book Links'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
  });

  testWidgets('popup toggle is temporary — the saved preference is untouched', (
    tester,
  ) async {
    // Seed a persisted 'show_book_links' preference.
    SharedPreferences.setMockInitialValues({'show_book_links': true});
    final prefs = await SharedPreferences.getInstance();
    final notifier = SettingsNotifier(prefs)..init(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [AppLocalizationsDelegate()],
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkSplash.splashFactory,
          ),
          home: const Scaffold(body: DisplayLayoutPopup()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Toggle OFF in the popup: the in-memory state flips…
    await tester.tap(find.text('Show Book Links'));
    await tester.pumpAndSettle();
    expect(notifier.state.showBookLinks, isFalse);

    // …but the persisted preference is NOT written (session-only).
    expect(prefs.getBool('show_book_links'), isTrue);
  });
}
