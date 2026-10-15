import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/settings/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression test for the settings screen's `_SettingsTile`: the trailing
/// subtitle is an unconstrained Text in the Row, so on narrow screens a long
/// subtitle squeezed the title's Expanded slot to nothing. The tile now
/// strips the subtitle when the title and subtitle can't both fit beside the
/// icon and chevron.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpApp(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
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
          home: const SettingsScreen(),
        ),
      ),
    );
    // The localization delegate loads asynchronously; pump so the screen is
    // actually built before asserting. Not pumpAndSettle: the storage tile's
    // spinner waits on a real platform call that never ends on the fake
    // clock, so the screen never settles.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// The settings list is lazy: bring the tile into the built range.
  Future<void> scrollToContextMenu(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Context Menu'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }

  testWidgets('long subtitle is stripped on a narrow screen', (tester) async {
    // Tall window so every section's tiles are inflated (the System section
    // with the longest subtitle is near the bottom of the list).
    await pumpApp(tester, const Size(300, 1800));

    await scrollToContextMenu(tester);
    // 'Context Menu' tile has the longest English subtitle. On a narrow row
    // it must be stripped so the title keeps the full space.
    expect(find.text('Context Menu'), findsOneWidget);
    expect(find.text('Customize the selection toolbar'), findsNothing,
        reason: 'the long subtitle must not squeeze the title on narrow rows');
  });

  testWidgets('subtitle is shown when there is room', (tester) async {
    await pumpApp(tester, const Size(900, 1800));
    await scrollToContextMenu(tester);

    expect(find.text('Context Menu'), findsOneWidget);
    expect(find.text('Customize the selection toolbar'), findsOneWidget,
        reason: 'with plenty of width the subtitle hint stays visible');
  });

  testWidgets('long subtitle is stripped at a large text scale',
      (tester) async {
    // At 2x text scale the measurement must scale too, so on a wide screen
    // the long subtitle no longer fits and gets stripped — proving the
    // TextPainter uses the same scaler as the rendered text.
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, const Size(900, 1800));
    await scrollToContextMenu(tester);

    expect(find.text('Context Menu'), findsOneWidget);
    expect(find.text('Customize the selection toolbar'), findsNothing,
        reason: 'at 2x scale the subtitle no longer fits and must be stripped');
  });
}
