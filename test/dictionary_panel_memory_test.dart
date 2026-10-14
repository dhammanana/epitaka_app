import 'package:epitaka/core/providers/dictionary_books_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/desktop/desktop_shell.dart';
import 'package:epitaka/features/dictionary/providers/dictionary_panel_memory.dart';
import 'package:epitaka/features/dpd/providers/dictionary_list_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_lookup_provider.dart';
import 'package:epitaka/shared/providers/side_panel_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The desktop dictionary panel comes back at start-up where it was left:
/// open or closed, on the last word looked up in it.
void main() {
  // The panel's own lookups are stubbed so no database file is touched.
  final overrides = [
    dpdLookupProvider.overrideWith(
      (ref, String word) async => DpdLookup(
        query: word,
        headwords: const [],
        roots: const [],
        secondary: const [],
        timer: Stopwatch(),
      ),
    ),
    dpdSuggestionsProvider.overrideWith(
      (ref, String prefix) async => <String>[],
    ),
    dpdClosestMatchesProvider.overrideWith(
      (ref, String query) async => <String>[],
    ),
    dictionaryBooksProvider.overrideWith(
      (ref) async => const <DictionaryBook>[],
    ),
    dictionaryListProvider.overrideWithValue(
      const AsyncData(<DictionaryListEntry>[]),
    ),
  ];

  Widget shellApp(ProviderContainer container, Widget home) =>
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [AppLocalizationsDelegate()],
          home: home,
        ),
      );

  Future<void> showShell(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(shellApp(c, const DesktopShell(child: SizedBox())));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<ProviderContainer> pumpShell(
    WidgetTester tester,
    Map<String, Object> saved,
  ) async {
    SharedPreferences.setMockInitialValues(saved);
    DictionaryPanelMemory.restoredThisRun = false;
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    await showShell(tester, container);
    return container;
  }

  Future<Object?> stored(WidgetTester tester, String key) async {
    Object? value;
    await tester.runAsync(() async {
      value = (await SharedPreferences.getInstance()).get(key);
    });
    return value;
  }

  testWidgets('a panel that was open comes back, pinned, on the saved word', (
    tester,
  ) async {
    final c = await pumpShell(tester, {
      DictionaryPanelMemory.openKey: true,
      DictionaryPanelMemory.wordKey: 'dhamma',
    });

    final left = c.read(sidePanelProvider).left;
    expect(left.openPanel, SidePanelType.dictionary);
    expect(left.panelData, 'dhamma');
    expect(left.isPinned, isTrue);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'dhamma',
    );
  });

  testWidgets('a panel that was closed stays closed', (tester) async {
    final c = await pumpShell(tester, {
      DictionaryPanelMemory.openKey: false,
      DictionaryPanelMemory.wordKey: 'dhamma',
    });
    expect(c.read(sidePanelProvider).isAnyOpen, isFalse);
  });

  testWidgets('nothing saved: nothing opens', (tester) async {
    final c = await pumpShell(tester, {});
    expect(c.read(sidePanelProvider).isAnyOpen, isFalse);
  });

  testWidgets('closing the panel saves "closed"', (tester) async {
    final c = await pumpShell(tester, {
      DictionaryPanelMemory.openKey: true,
      DictionaryPanelMemory.wordKey: 'dhamma',
    });
    expect(await stored(tester, DictionaryPanelMemory.openKey), isTrue);

    c.read(sidePanelProvider.notifier).close(SidePanelType.dictionary);
    await tester.pump(const Duration(milliseconds: 100));

    expect(await stored(tester, DictionaryPanelMemory.openKey), isFalse);
  });

  testWidgets('opening the panel saves "open"', (tester) async {
    final c = await pumpShell(tester, {});
    c
        .read(sidePanelProvider.notifier)
        .open(SidePanelType.dictionary, data: 'citta', pin: true);
    await tester.pump(const Duration(milliseconds: 100));

    expect(await stored(tester, DictionaryPanelMemory.openKey), isTrue);
  });

  testWidgets('a lookup in the panel saves the word', (tester) async {
    final c = await pumpShell(tester, {
      DictionaryPanelMemory.openKey: true,
      DictionaryPanelMemory.wordKey: 'dhamma',
    });

    c.read(sidePanelProvider.notifier).updateDictionaryWord('kamma');
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(await stored(tester, DictionaryPanelMemory.wordKey), 'kamma');
  });

  testWidgets('a panel the user closed does not reopen when the shell is '
      'built again', (tester) async {
    final c = await pumpShell(tester, {
      DictionaryPanelMemory.openKey: true,
      DictionaryPanelMemory.wordKey: 'dhamma',
    });
    c.read(sidePanelProvider.notifier).close(SidePanelType.dictionary);
    await tester.pump(const Duration(milliseconds: 100));

    // The window crossed the phone breakpoint and came back.
    await tester.pumpWidget(shellApp(c, const SizedBox()));
    await tester.runAsync(() async {
      await SharedPreferences.getInstance().then(
        (p) => p.setBool(DictionaryPanelMemory.openKey, true),
      );
    });
    await showShell(tester, c);

    expect(c.read(sidePanelProvider).isAnyOpen, isFalse);
  });

  testWidgets('a panel another panel took the slot of is left alone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      DictionaryPanelMemory.openKey: true,
      DictionaryPanelMemory.wordKey: 'dhamma',
    });
    final c = ProviderContainer(overrides: overrides);
    addTearDown(c.dispose);
    c.read(sidePanelProvider.notifier).open(SidePanelType.library);

    await tester.runAsync(
      () => DictionaryPanelMemory.restore(
        c.read(sidePanelProvider.notifier),
        slotFree: () => c.read(sidePanelProvider).left.openPanel == null,
      ),
    );

    expect(c.read(sidePanelProvider).left.openPanel, SidePanelType.library);
  });
}
