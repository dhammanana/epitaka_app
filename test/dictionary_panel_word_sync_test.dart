import 'package:epitaka/core/providers/dictionary_books_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/desktop/desktop_shell.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_panel.dart';
import 'package:epitaka/features/dpd/providers/dictionary_list_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_lookup_provider.dart';
import 'package:epitaka/shared/providers/side_panel_provider.dart';
import 'package:epitaka/shared/widgets/velthuis_help_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/type_keys.dart';

/// Verifies the desktop dictionary panel receives words routed through
/// [sidePanelProvider].
///
/// Word lookups from the reader (double-click/tap on a Pāli word, context
/// menu) land in the LEFT sidebar slot: [SidePanelNotifier.open] with data,
/// or [SidePanelNotifier.updateDictionaryWord] when the panel is already
/// open. The panel reads the left slot first, then the right one; nothing in
/// the app puts the dictionary in the right slot today, so that is a
/// fallback. The dictionary drawn on the right side of the window still lives
/// in the left slot: the desktop shell only draws that slot on the right.
void main() {
  // Stub the DPD lookup and its suggestions so no database file is touched.
  // An empty lookup is a plain miss, which is all these tests need.
  final lookupOverride = dpdLookupProvider.overrideWith(
    (ref, String word) async => DpdLookup(
      query: word,
      headwords: const [],
      roots: const [],
      secondary: const [],
      timer: Stopwatch(),
    ),
  );
  final suggestionsOverride = dpdSuggestionsProvider.overrideWith(
    (ref, String prefix) async => <String>[],
  );
  final closestOverride = dpdClosestMatchesProvider.overrideWith(
    (ref, String query) async => <String>[],
  );
  // The real books provider reads the epitaka database, which never resolves
  // in the widget-test environment; stub it with an empty list instead.
  final booksOverride = dictionaryBooksProvider.overrideWith(
    (ref) async => const <DictionaryBook>[],
  );
  // The list also waits on the DPD file, which never resolves here either.
  final listOverride = dictionaryListProvider.overrideWithValue(
    const AsyncData(<DictionaryListEntry>[]),
  );

  Future<ProviderContainer> pumpPanel(
    WidgetTester tester, {
    required SidePanelsState initialPanels,
  }) async {
    final container = ProviderContainer(
      overrides: [
        lookupOverride,
        suggestionsOverride,
        closestOverride,
        booksOverride,
        listOverride,
      ],
    );
    addTearDown(container.dispose);
    container.read(sidePanelProvider.notifier).state = initialPanels;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [AppLocalizationsDelegate()],
          home: const Scaffold(body: DictionaryPanel()),
        ),
      ),
    );
    return container;
  }

  String textFieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets(
      'Velthuis turns into diacritics; the help icon shows, empty or with text',
      (tester) async {
    await pumpPanel(
      tester,
      initialPanels: const SidePanelsState(
        left: SidePanelState(
          openPanel: SidePanelType.dictionary,
          isPinned: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final help = find.descendant(
      of: find.byType(TextField),
      matching: find.byType(VelthuisHelpIcon),
    );
    expect(textFieldText(tester), isEmpty);
    expect(help, findsOneWidget);

    await typeKeys(tester, find.byType(TextField), 'paali');
    // The panel redraws after its 300 ms suggestion pause.
    await tester.pump(const Duration(milliseconds: 400));
    expect(help, findsOneWidget);
    expect(find.byIcon(Icons.clear), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'pāli',
    );
  });

  testWidgets(
    'panel shows the word passed when the dictionary is opened in the left '
    'sidebar slot',
    (tester) async {
      final container = await pumpPanel(
        tester,
        initialPanels: const SidePanelsState(
          left: SidePanelState(
            openPanel: SidePanelType.dictionary,
            isPinned: true,
            panelData: 'bhagavā',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(sidePanelProvider).left.openPanel,
        SidePanelType.dictionary,
      );
      expect(textFieldText(tester), 'bhagavā',
          reason: 'the looked-up word must reach the panel search field');
    },
  );

  testWidgets(
    'panel picks up a new word pushed via updateDictionaryWord while open',
    (tester) async {
      final container = await pumpPanel(
        tester,
        initialPanels: const SidePanelsState(
          left: SidePanelState(
            openPanel: SidePanelType.dictionary,
            isPinned: true,
            panelData: 'citta',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(textFieldText(tester), 'citta');

      // The reader re-points the already-open panel at a new word.
      container
          .read(sidePanelProvider.notifier)
          .updateDictionaryWord('kamma');
      await tester.pumpAndSettle();

      expect(textFieldText(tester), 'kamma',
          reason: 'an already-open panel must re-search the new word');
    },
  );

  testWidgets(
    'panel shows the word passed when the dictionary is in the right sidebar '
    'slot',
    (tester) async {
      await pumpPanel(
        tester,
        initialPanels: const SidePanelsState(
          right: SidePanelState(
            openPanel: SidePanelType.dictionary,
            panelData: 'bhagavā',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(textFieldText(tester), 'bhagavā',
          reason: 'the dictionary can live in the right slot too');
    },
  );

  testWidgets(
    'the dictionary drawn on the right side of the desktop shell shows its '
    'word',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'sidebar_on_right': true});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          lookupOverride,
          suggestionsOverride,
          closestOverride,
          booksOverride,
          listOverride,
        ],
      );
      addTearDown(container.dispose);
      container.read(settingsProvider.notifier).init(prefs);
      container.read(sidePanelProvider.notifier).state = const SidePanelsState(
        left: SidePanelState(
          openPanel: SidePanelType.dictionary,
          isPinned: true,
          panelData: 'bhagavā',
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            supportedLocales: AppLocalizationsDelegate.supportedLocales,
            localizationsDelegates: const [AppLocalizationsDelegate()],
            home: const DesktopShell(child: SizedBox()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<DesktopSidebar>(find.byType(DesktopSidebar)).onRight,
          isTrue);
      expect(tester.getTopLeft(find.byType(DictionaryPanel)).dx,
          greaterThan(800),
          reason: 'the saved setting puts the sidebar on the right');
      expect(textFieldText(tester), 'bhagavā');

      // A word looked up while the sidebar is already on the right.
      container.read(sidePanelProvider.notifier).updateDictionaryWord('kamma');
      await tester.pumpAndSettle();
      expect(textFieldText(tester), 'kamma');
    },
  );
}
