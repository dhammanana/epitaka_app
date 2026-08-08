import 'package:epitaka/core/models/app_models.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/contents/providers/contents_provider.dart';
import 'package:epitaka/shared/providers/side_panel_provider.dart';
import 'package:epitaka/shared/widgets/responsive_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the desktop split-pane behavior of [ResponsiveScaffold]:
/// pinned side panels are separated from the main content by a draggable
/// divider, the width is clamped between a minimum and a screen-aware
/// maximum, and the final width is persisted via [settingsProvider].
void main() {
  Future<void> pumpScaffold(WidgetTester tester) async {
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
                        child: const Text('open-right'),
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
    await pumpScaffold(tester);
    await openPanel(tester, 'open-right');

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
}
