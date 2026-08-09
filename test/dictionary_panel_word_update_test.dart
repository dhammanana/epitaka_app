import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_panel.dart';
import 'package:epitaka/shared/providers/side_panel_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies the desktop [DictionaryPanel] stays in sync with the word routed
/// through [SidePanelProvider] — both when it mounts with a pending word and
/// when a new word arrives while it's already open (double-clicking another
/// word on desktop must re-search the panel in place, without requiring a
/// window/panel resize to force a rebuild).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> makeContainer() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final prefs = await SharedPreferences.getInstance();
    container.read(settingsProvider.notifier).init(prefs);
    return container;
  }

  Future<void> pumpPanel(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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
          home: const Scaffold(body: DictionaryPanel()),
        ),
      ),
    );
    await tester.pump();
  }

  String searchText(WidgetTester tester) {
    return tester.widget<TextField>(find.byType(TextField)).controller!.text;
  }

  testWidgets('panel opened with a word searches it on mount', (tester) async {
    final container = await makeContainer();
    // Route the word BEFORE the panel mounts, like opening the dictionary
    // from a double-click on desktop.
    container
        .read(sidePanelProvider.notifier)
        .open(SidePanelType.dictionary, data: 'dhamma');
    await pumpPanel(tester, container);
    expect(searchText(tester), 'dhamma');
  });

  testWidgets('a second word lookup updates the open panel in place', (
    tester,
  ) async {
    final container = await makeContainer();
    await pumpPanel(tester, container);
    expect(searchText(tester), isEmpty);

    container
        .read(sidePanelProvider.notifier)
        .open(SidePanelType.dictionary, data: 'dhamma');
    await tester.pump();
    expect(searchText(tester), 'dhamma');

    // Double-tapping another word routes via updateDictionaryWord — the
    // panel must re-search without any resize forcing a rebuild.
    container.read(sidePanelProvider.notifier).updateDictionaryWord('kamma');
    await tester.pump();
    expect(searchText(tester), 'kamma');

    // And a third word still lands.
    container.read(sidePanelProvider.notifier).updateDictionaryWord('citta');
    await tester.pump();
    expect(searchText(tester), 'citta');
  });

  testWidgets('unrelated panel changes do not re-search the current word', (
    tester,
  ) async {
    final container = await makeContainer();
    await pumpPanel(tester, container);
    container
        .read(sidePanelProvider.notifier)
        .open(SidePanelType.dictionary, data: 'dhamma');
    await tester.pump();
    expect(searchText(tester), 'dhamma');

    // A provider change that leaves panelData untouched (e.g. pinning, like
    // a panel resize would) must not disturb the active query.
    container
        .read(sidePanelProvider.notifier)
        .setPinned(SidePanelType.dictionary, true);
    await tester.pump();
    expect(searchText(tester), 'dhamma');
  });
}
