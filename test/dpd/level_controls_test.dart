/// The level buttons in the sidebar header, on the same setting as
/// Settings → Dictionaries.
library;

import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/desktop/desktop_shell.dart';
import 'package:epitaka/features/dictionary/providers/dictionary_font_scale_provider.dart';
import 'package:epitaka/features/dictionary/providers/dictionary_header_provider.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_header_icons.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_level_controls.dart';
import 'package:epitaka/features/dpd/providers/dpd_settings_provider.dart';
import 'package:epitaka/shared/providers/side_panel_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:epitaka/core/providers/dictionary_books_provider.dart';
import 'package:epitaka/features/dpd/providers/dictionary_list_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_lookup_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget child, {
    double width = 600,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        dpdSuggestionsProvider.overrideWith(
          (ref, String p) async => <String>[],
        ),
        dpdClosestMatchesProvider.overrideWith(
          (ref, String q) async => <String>[],
        ),
        dictionaryBooksProvider.overrideWith(
          (ref) async => const <DictionaryBook>[],
        ),
        dictionaryListProvider.overrideWithValue(
          const AsyncData(<DictionaryListEntry>[]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [AppLocalizationsDelegate()],
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  DesktopSidebar sidebar(SidePanelType panel) => DesktopSidebar(
    panel: panel,
    title: 'Header title',
    onRight: false,
    autoFocus: false,
    onClose: () {},
    onMoveSidebarRight: () {},
    onMoveSidebarLeft: () {},
  );

  DictionaryLevel level(ProviderContainer c) =>
      c.read(dpdSettingsProvider).level;

  testWidgets('the header of the dictionary panel holds the level buttons', (
    tester,
  ) async {
    await pump(tester, sidebar(SidePanelType.dictionary));
    expect(find.byType(DictionaryLevelButtons), findsOneWidget);
  });

  testWidgets('the header of another panel holds none', (tester) async {
    await pump(tester, sidebar(SidePanelType.history));
    expect(find.byType(DictionaryLevelButtons), findsNothing);
  });

  testWidgets('a tap on a button sets the level, and the current one is lit', (
    tester,
  ) async {
    final c = await pump(tester, const DictionaryLevelButtons());
    expect(level(c), DictionaryLevel.majjhima);
    await tester.tap(find.byIcon(Icons.density_large));
    await tester.pump();
    expect(level(c), DictionaryLevel.vitthara);
    await tester.tap(find.byIcon(Icons.density_small));
    await tester.pump();
    expect(level(c), DictionaryLevel.sankhitta);
    final lit = tester
        .widgetList<Container>(find.byType(Container))
        .where((b) => b.decoration is BoxDecoration)
        .where((b) => (b.decoration as BoxDecoration).color != null);
    expect(lit, hasLength(1));
  });

  testWidgets('wide: the title and the icons share the header', (tester) async {
    await pump(tester, sidebar(SidePanelType.dictionary), width: 600);
    expect(find.text('Header title'), findsOneWidget);
    expect(tester.getTopLeft(find.byIcon(Icons.history)).dy, lessThan(36));
  });

  testWidgets('medium: the title goes first, the icons stay in the header', (
    tester,
  ) async {
    await pump(tester, sidebar(SidePanelType.dictionary), width: 450);
    expect(find.text('Header title'), findsNothing);
    expect(tester.getTopLeft(find.byIcon(Icons.history)).dy, lessThan(36));
  });

  testWidgets('narrow: the icons move to a second row', (tester) async {
    await pump(tester, sidebar(SidePanelType.dictionary), width: 340);
    expect(find.text('Header title'), findsNothing);
    expect(
      tester.getTopLeft(find.byIcon(Icons.history)).dy,
      greaterThanOrEqualTo(36),
    );
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('the summary icon flips the setting', (tester) async {
    final c = await pump(tester, const DictionaryHeaderIcons());
    expect(c.read(dpdSettingsProvider).showSummary, isTrue);
    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pump();
    expect(c.read(dpdSettingsProvider).showSummary, isFalse);
    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pump();
    expect(c.read(dpdSettingsProvider).showSummary, isTrue);
  });

  testWidgets('the grammar and examples icons flip their settings', (
    tester,
  ) async {
    final c = await pump(tester, const DictionaryHeaderIcons());
    expect(c.read(dpdSettingsProvider).grammarOpen, isFalse);
    expect(c.read(dpdSettingsProvider).examplesOpen, isFalse);
    await tester.tap(find.text('g'));
    await tester.pump();
    expect(c.read(dpdSettingsProvider).grammarOpen, isTrue);
    expect(c.read(dpdSettingsProvider).examplesOpen, isFalse);
    await tester.tap(find.text('e'));
    await tester.pump();
    expect(c.read(dpdSettingsProvider).examplesOpen, isTrue);
    await tester.tap(find.text('g'));
    await tester.pump();
    expect(c.read(dpdSettingsProvider).grammarOpen, isFalse);
  });

  testWidgets('the size icons move the text scale one step', (tester) async {
    final c = await pump(tester, const DictionaryHeaderIcons());
    expect(c.read(dictionaryFontScaleProvider), 1.0);
    await tester.tap(find.byIcon(Icons.text_increase));
    await tester.pump();
    expect(c.read(dictionaryFontScaleProvider), closeTo(1.05, 1e-9));
    await tester.tap(find.byIcon(Icons.text_decrease));
    await tester.tap(find.byIcon(Icons.text_decrease));
    await tester.pump();
    expect(c.read(dictionaryFontScaleProvider), closeTo(0.95, 1e-9));
  });

  testWidgets('a size icon lights up for a moment when tapped', (tester) async {
    await pump(tester, const DictionaryHeaderIcons());
    double alpha(IconData icon) {
      final box = tester.widget<Container>(
        find
            .ancestor(of: find.byIcon(icon), matching: find.byType(Container))
            .first,
      );
      return ((box.decoration as BoxDecoration).color ?? Colors.transparent).a;
    }

    expect(alpha(Icons.text_increase), 0);
    await tester.tap(find.byIcon(Icons.text_increase));
    await tester.pump(const Duration(milliseconds: 50));
    expect(alpha(Icons.text_increase), greaterThan(0.5));
    await tester.pump(const Duration(milliseconds: 500));
    expect(alpha(Icons.text_increase), 0);

    // A button with no on or off state of its own does not flash.
    await tester.tap(find.byIcon(Icons.vertical_align_top));
    await tester.pump(const Duration(milliseconds: 50));
    expect(alpha(Icons.vertical_align_top), 0);
  });

  testWidgets('the size icons stop at 50% and 120%', (tester) async {
    final c = await pump(tester, const DictionaryHeaderIcons());
    final notifier = c.read(dictionaryFontScaleProvider.notifier);
    await notifier.setScale(kDictionaryFontScaleMax);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.text_increase));
    await tester.pump();
    expect(c.read(dictionaryFontScaleProvider), kDictionaryFontScaleMax);
    await notifier.setScale(kDictionaryFontScaleMin);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.text_decrease));
    await tester.pump();
    expect(c.read(dictionaryFontScaleProvider), kDictionaryFontScaleMin);
  });

  testWidgets('the hide icon hides the row, the setting brings it back', (
    tester,
  ) async {
    final c = await pump(tester, sidebar(SidePanelType.dictionary));
    expect(find.byIcon(Icons.vertical_align_top), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(c.read(dictionaryHeaderIconsProvider), isFalse);
    expect(find.byIcon(Icons.vertical_align_top), findsNothing);
    expect(find.text('Header title'), findsOneWidget);

    c.read(dictionaryHeaderIconsProvider.notifier).set(true);
    await tester.pump();
    expect(find.byIcon(Icons.vertical_align_top), findsOneWidget);
  });

  test('the row is saved and read back', () async {
    SharedPreferences.setMockInitialValues({});
    final first = DictionaryHeaderIconsNotifier();
    await first.set(false);
    final second = DictionaryHeaderIconsNotifier();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(second.state, isFalse);
  });

  testWidgets('the jump and history icons raise their request', (tester) async {
    final c = await pump(tester, const DictionaryHeaderIcons());
    await tester.tap(find.byIcon(Icons.vertical_align_top));
    await tester.tap(find.byIcon(Icons.history));
    await tester.pump();
    expect(c.read(dictionaryScrollTopRequestProvider), 1);
    expect(c.read(dictionaryHistoryRequestProvider), 1);
  });
}
