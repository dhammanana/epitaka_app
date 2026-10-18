import 'package:epitaka/core/models/app_models.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/contents/providers/contents_provider.dart';
import 'package:epitaka/shared/providers/side_panel_provider.dart';
import 'package:epitaka/shared/utils/app_shortcuts.dart';
import 'package:epitaka/shared/widgets/responsive_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the desktop split-pane behavior of [ResponsiveScaffold]:
/// pinned side panels are separated from the main content by a draggable
/// divider, the width is clamped between a minimum and a screen-aware
/// maximum, and the final width is persisted via [settingsProvider].
/// Also verifies that the user can move the panel to the right side (header
/// grip or the saved `sidebar_on_right` setting) and that it stays there.
void main() {
  tearDownAll(() {
    // These tests leave the side panel saved as open (and on the right).
    // Files share a process in `just test`, and a later reader test drawn
    // with the panel open overflows, so leave the store empty.
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScaffold(
    WidgetTester tester, {
    SettingsNotifier? settings,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Avoid touching the database — the contents panel just renders
          // its (empty) data state.
          contentsProvider.overrideWith(
            (ref, bookId) async => <HeadingInfo>[],
          ),
          if (settings != null) settingsProvider.overrideWith((ref) => settings),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
            useMaterial3: true,
          ),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Column(
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => ref
                            .read(sidePanelProvider.notifier)
                            .open(SidePanelType.contents),
                        child: const Text('open-left'),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(sidePanelProvider.notifier)
                            .open(SidePanelType.dictionary),
                        child: const Text('open-dictionary'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ResponsiveScaffold(
                      child: const Text('MAIN CONTENT'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // The first frame is blank while the localizations delegates load;
    // pump again so the real tree is built.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openPanel(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump(); // Start the slide-in animation.
    await tester.pump(const Duration(milliseconds: 300)); // Finish it.
  }

  AppSettings readSettings(WidgetTester tester) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ResponsiveScaffold)),
    );
    return container.read(settingsProvider);
  }

  /// Settings as if the user had already moved the panel to the right side.
  Future<SettingsNotifier> panelOnRightSettings() async {
    SharedPreferences.setMockInitialValues({'sidebar_on_right': true});
    final prefs = await SharedPreferences.getInstance();
    return SettingsNotifier(prefs)..init(prefs);
  }

  bool onLeft() => find
      .byKey(const Key('left-panel-divider'))
      .hitTestable()
      .evaluate()
      .isNotEmpty;

  bool onRight() => find
      .byKey(const Key('right-panel-divider'))
      .hitTestable()
      .evaluate()
      .isNotEmpty;

  testWidgets('divider appears between panel and main content', (
    tester,
  ) async {
    await pumpScaffold(tester);
    // With no panel open the dividers are clipped away (not hit-testable).
    expect(
      find.byKey(const Key('left-panel-divider')).hitTestable(),
      findsNothing,
    );
    expect(
      find.byKey(const Key('right-panel-divider')).hitTestable(),
      findsNothing,
    );

    await openPanel(tester, 'open-left');
    final divider = find.byKey(const Key('left-panel-divider')).hitTestable();
    expect(divider, findsOneWidget);

    // The divider spans the full panel height (a screen divider, not a
    // stub), giving a comfortable vertical drag target.
    final dividerSize = tester.getSize(divider);
    expect(dividerSize.width, 12);
    expect(dividerSize.height, greaterThan(600));

    // The divider sits on the panel's right edge — between the panel and
    // the main content (which starts at the divider's right side).
    final dividerX = tester.getCenter(divider).dx;
    final mainText = find.text('MAIN CONTENT');
    expect(tester.getTopLeft(mainText).dx, greaterThan(dividerX));
  });

  testWidgets('dragging the left divider shrinks the panel to the minimum',
      (tester) async {
    await pumpScaffold(tester);
    await openPanel(tester, 'open-left');

    final divider = find.byKey(const Key('left-panel-divider'));
    final before = tester.getCenter(divider).dx;

    // Drag left: the panel shrinks and clamps at the 260px minimum.
    await tester.drag(divider, const Offset(-200, 0));
    await tester.pump();

    final after = tester.getCenter(divider).dx;
    expect(before - after, greaterThan(60));
    // 52px activity bar + 260px panel + half the divider
    expect(after, lessThan(330));

    // The chosen width is persisted.
    expect(readSettings(tester).leftPanelWidth, 260);
  });

  testWidgets('dragging the right divider grows the panel up to the cap', (
    tester,
  ) async {
    await pumpScaffold(tester, settings: await panelOnRightSettings());
    await openPanel(tester, 'open-dictionary');

    final divider = find.byKey(const Key('right-panel-divider'));
    expect(divider, findsOneWidget);
    final before = tester.getCenter(divider).dx; // ≈ 1280 - 360 - 6

    // Drag left: the right panel grows and clamps at the 640px cap.
    await tester.drag(divider, const Offset(-400, 0));
    await tester.pump();

    final after = tester.getCenter(divider).dx; // ≈ 1280 - 640 - 6
    expect(before - after, greaterThan(200));
    expect(after, greaterThan(600));
    expect(after, lessThan(660));

    expect(readSettings(tester).rightPanelWidth, 640);
  });

  testWidgets('panel width is kept across close/reopen within the session', (
    tester,
  ) async {
    await pumpScaffold(tester);
    await openPanel(tester, 'open-left');

    final divider = find.byKey(const Key('left-panel-divider'));
    await tester.drag(divider, const Offset(-200, 0));
    await tester.pump();
    final afterResize = tester.getCenter(divider).dx;

    // Close the panel, then reopen it.
    await tester.tap(find.byTooltip('Close panel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await openPanel(tester, 'open-left');
    await tester.pump(const Duration(milliseconds: 300));

    final reopened = tester
        .getCenter(find.byKey(const Key('left-panel-divider')))
        .dx;
    expect(reopened, closeTo(afterResize, 1));
  });

  testWidgets('dictionary stays where the user moved it (left → right)',
      (tester) async {
    await pumpScaffold(tester);
    await openPanel(tester, 'open-dictionary');

    // The panel starts on the left.
    expect(onLeft(), isTrue);
    expect(onRight(), isFalse);

    // Drag the header grip to the right: the panel moves to the right side
    // and the choice is saved.
    await tester.drag(
      find.byTooltip('Move panel to the right'),
      const Offset(120, 0),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(onRight(), isTrue);
    expect(onLeft(), isFalse);
    expect(readSettings(tester).sidebarOnRight, isTrue);

    // Close the dictionary, then reopen it via the provider (as a word
    // lookup would) — it stays on the right.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ResponsiveScaffold)),
    );
    container.read(sidePanelProvider.notifier).close(SidePanelType.dictionary);
    await tester.pump();
    await openPanel(tester, 'open-dictionary');

    expect(onRight(), isTrue);
    expect(onLeft(), isFalse);
  });

  testWidgets('right-side dictionary moves back to the left on grip drag',
      (tester) async {
    await pumpScaffold(tester, settings: await panelOnRightSettings());
    await openPanel(tester, 'open-dictionary');

    // Starts on the right (saved placement wins).
    expect(onRight(), isTrue);

    await tester.drag(
      find.byTooltip('Move panel to the left'),
      const Offset(-120, 0),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(onLeft(), isTrue);
    expect(onRight(), isFalse);
    expect(readSettings(tester).sidebarOnRight, isFalse);
  });

  testWidgets('a short slow grip drag leaves the panel where it is',
      (tester) async {
    await pumpScaffold(tester);
    await openPanel(tester, 'open-dictionary');

    // 60 px in 400 ms: under both the 80 px and the 300 px/s thresholds.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byTooltip('Move panel to the right')),
    );
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(15, 0));
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Hold still so the release velocity is zero.
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(onLeft(), isTrue);
    expect(onRight(), isFalse);
    expect(readSettings(tester).sidebarOnRight, isFalse);
  });

  testWidgets('dictionary placement is restored from persisted settings',
      (tester) async {
    // The user previously moved the panel to the right side.
    await pumpScaffold(tester, settings: await panelOnRightSettings());
    // Dictionary open (as from a word lookup).
    await openPanel(tester, 'open-dictionary');

    // The saved placement wins: right side, not the left.
    expect(onRight(), isTrue);
    expect(onLeft(), isFalse);
  });

  testWidgets('activity bar honors the saved right-side placement',
      (tester) async {
    await pumpScaffold(tester, settings: await panelOnRightSettings());
    // Toggle the dictionary from the activity bar (panel closed). The
    // status bar no longer duplicates the dictionary button.
    await tester.tap(
      find.byTooltip(AppShortcuts.tooltip('Dictionary', 'dictionary')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The saved placement wins: the dictionary opens on the right and
    // nothing opens on the left.
    expect(onRight(), isTrue);
    expect(onLeft(), isFalse);
  });

  testWidgets('status bar drops the sidebar actions and keeps the shell actions',
      (tester) async {
    await pumpScaffold(tester);

    // Contents / search / dictionary now live only in the activity bar —
    // exactly one tooltip each, i.e. the status bar no longer duplicates
    // them. Tooltips carry the shortcut hint (computed the same way the
    // widgets build them, so the assertions hold on any platform).
    expect(
      find.byTooltip(AppShortcuts.tooltip('Contents', 'contents')),
      findsOneWidget,
    );
    expect(
      find.byTooltip(AppShortcuts.tooltip('Search', 'find-everywhere')),
      findsOneWidget,
    );
    expect(
      find.byTooltip(AppShortcuts.tooltip('Dictionary', 'dictionary')),
      findsOneWidget,
    );

    // The shell actions on the right of the status bar are present. (The
    // reader toolbar in the middle only draws buttons whose handlers a
    // reader tab supplies, so it is empty in this harness.)
    expect(
      find.byTooltip(
        AppShortcuts.tooltip('Decrease font size', 'font-decrease'),
      ),
      findsOneWidget,
    );
    expect(
      find.byTooltip(
        AppShortcuts.tooltip('Increase font size', 'font-increase'),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Reset layout'), findsOneWidget);
    expect(
      find.byTooltip(AppShortcuts.tooltip('Settings', 'settings')),
      findsOneWidget,
    );
  });
}
