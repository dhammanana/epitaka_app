/// Regression test for the polarity of the "Show variant readings"
/// switch in Reading options.
///
/// The stored setting is `stripVariantAnnotations` (true = variants
/// HIDDEN), but the switch is labeled "Show variant readings" — so the
/// switch must display the inverse: ON = variants shown (strip == false),
/// OFF = variants hidden (strip == true). It used to bind the raw stored
/// value, making the toggle reversed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/settings/screens/reading_options_screen.dart';

/// The Switch rendered next to the "Show variant readings" tile.
Finder _variantSwitch() {
  return find.descendant(
    of: find.ancestor(
      of: find.text('Show variant readings'),
      matching: find.byType(Row),
    ),
    matching: find.byType(Switch),
  );
}

void main() {
  Future<ProviderContainer> pumpOptions(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Default construction leaves stripVariantAnnotations = true.
    container.read(settingsProvider.notifier).state = AppSettings();
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
          home: const Scaffold(body: ReadingOptionsBody()),
        ),
      ),
    );
    await tester.pump();
    // The body is a lazily-built ListView; the Display section (with the
    // variant switch) sits below the default test viewport — scroll to it.
    await tester.scrollUntilVisible(
      find.text('Show variant readings'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    return container;
  }

  testWidgets('default setting (strip=true) renders the switch OFF', (
    tester,
  ) async {
    await pumpOptions(tester);

    expect(_variantSwitch(), findsOneWidget);
    expect(tester.widget<Switch>(_variantSwitch()).value, isFalse);
  });

  testWidgets('tapping the switch ON stores strip=false', (tester) async {
    final container = await pumpOptions(tester);

    expect(tester.widget<Switch>(_variantSwitch()).value, isFalse);

    await tester.tap(_variantSwitch());
    await tester.pump();

    expect(container.read(settingsProvider).stripVariantAnnotations, isFalse);
    expect(tester.widget<Switch>(_variantSwitch()).value, isTrue);
  });
}
