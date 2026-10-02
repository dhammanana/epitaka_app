import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/settings/widgets/desktop_settings_dialog.dart';

void main() {
  testWidgets('the settings window follows the app window size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsNotifier(prefs)..init(prefs);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => settings)],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDesktopSettingsDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The Dialog widget itself fills the screen; the window is its first
    // SizedBox.
    double dialogHeight() => tester
        .getSize(
          find
              .descendant(
                of: find.byType(Dialog),
                matching: find.byType(SizedBox),
              )
              .first,
        )
        .height;
    expect(dialogHeight(), closeTo(720 * 0.9, 1));

    // Maximizing the app window while settings are open.
    tester.view.physicalSize = const Size(2000, 1250);
    await tester.pump();
    expect(dialogHeight(), closeTo(1250 * 0.9, 1));
  });

  Future<void> openSettings(WidgetTester tester, Size window) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = window;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsNotifier(prefs)..init(prefs);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => settings)],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDesktopSettingsDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  // The sidebar is the dialog's first ListView.
  Finder sidebar() => find
      .descendant(of: find.byType(Dialog), matching: find.byType(ListView))
      .first;

  List<RenderParagraph> sidebarTitles(WidgetTester tester) => [
    for (final element
        in find
            .descendant(of: sidebar(), matching: find.byType(RichText))
            .evaluate())
      element.renderObject! as RenderParagraph,
  ];

  testWidgets('on a wide screen every category name shows in full', (
    tester,
  ) async {
    await openSettings(tester, const Size(2000, 1250));
    final titles = sidebarTitles(tester);
    expect(titles, isNotEmpty);
    for (final title in titles) {
      expect(
        title.didExceedMaxLines,
        isFalse,
        reason: title.text.toPlainText(),
      );
    }
    expect(tester.getSize(sidebar()).width, greaterThan(230));
  });

  testWidgets('on a small screen the sidebar keeps its old width', (
    tester,
  ) async {
    await openSettings(tester, const Size(1000, 700));
    expect(tester.getSize(sidebar()).width, 230);
    expect(
      tester
          .getSize(
            find
                .descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(SizedBox),
                )
                .first,
          )
          .width,
      850,
    );
  });
}
