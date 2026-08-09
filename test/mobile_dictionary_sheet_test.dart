import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies the mobile dictionary is the modal bottom sheet again — the
/// classic bottom-sheet behaviors must work: opening from a word lookup,
/// closing with the system back button, closing by tapping outside, and
/// closing by pulling the sheet down.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final prefs = await SharedPreferences.getInstance();
    container.read(settingsProvider.notifier).init(prefs);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showDictionarySheet(context, ''),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pump();
    // Modal route transition + sheet build.
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('opening the dictionary shows the modal bottom sheet', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byType(DictionarySheet), findsNothing);

    await openSheet(tester);
    expect(find.byType(DictionarySheet), findsOneWidget);
    // It behaves like a bottom sheet: the search field is present.
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets(
    'Android back button closes the dictionary sheet, keeping the app open',
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    (tester) async {
      await pumpApp(tester);
      await openSheet(tester);
      expect(find.byType(DictionarySheet), findsOneWidget);

      // Simulate the system back button — pops the sheet route only.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DictionarySheet), findsNothing);
      // The app behind is still there.
      expect(find.text('open'), findsOneWidget);
    },
  );

  testWidgets('tapping outside closes the dictionary sheet', (tester) async {
    await pumpApp(tester);
    await openSheet(tester);
    expect(find.byType(DictionarySheet), findsOneWidget);

    // The sheet starts at 70% of the 800px screen, so the top 30% (above
    // y=240) belongs to the modal barrier. Tapping there dismisses the
    // sheet.
    await tester.tapAt(const Offset(200, 50));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(DictionarySheet), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('pulling the sheet down closes it', (tester) async {
    await pumpApp(tester);
    await openSheet(tester);
    expect(find.byType(DictionarySheet), findsOneWidget);

    // The sheet starts at 70% of the 800px screen (top edge at y=240). A
    // fast downward flick on the header drag region (the search field sits
    // inside it) dismisses it, like any bottom sheet.
    await tester.fling(
      find.byType(TextField),
      const Offset(0, 300),
      1200,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(DictionarySheet), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
