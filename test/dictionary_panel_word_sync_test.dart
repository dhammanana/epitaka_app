import 'package:epitaka/core/providers/dictionary_books_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_panel.dart';
import 'package:epitaka/features/dpd/providers/dictionary_list_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_lookup_provider.dart';
import 'package:epitaka/shared/providers/side_panel_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the desktop dictionary panel receives words routed through
/// [sidePanelProvider].
///
/// Word lookups from the reader (double-click/tap on a Pāli word, context
/// menu) land in the LEFT sidebar slot: [SidePanelNotifier.open] with data,
/// or [SidePanelNotifier.updateDictionaryWord] when the panel is already
/// open. The panel must read `left.panelData` — reading the right slot (a
/// leftover from an earlier refactor) opened the sidebar with an empty
/// search field.
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
    'panel does not read the word from the right sidebar slot',
    (tester) async {
      await pumpPanel(
        tester,
        initialPanels: const SidePanelsState(
          right: SidePanelState(
            openPanel: SidePanelType.dictionary,
            panelData: 'wrong-slot',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(textFieldText(tester), isEmpty,
          reason: 'the dictionary lives in the left slot; right-slot data '
              'must be ignored');
    },
  );
}
