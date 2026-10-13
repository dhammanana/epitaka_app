/// The display level: stored, chosen in Settings, and passed to the results
/// in the sheet and the panel while they are open.
library;

import 'dart:io';

import 'package:epitaka/features/dictionary/widgets/dictionary_panel.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/features/dpd/providers/dpd_settings_provider.dart';
import 'package:epitaka/features/dpd/widgets/dpd_results_view.dart';
import 'package:epitaka/features/settings/screens/dictionary_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart';

DictionaryLevel _shownLevel(WidgetTester tester) =>
    tester.widget<DpdResultsView>(find.byType(DpdResultsView)).level;

void main() {
  late Directory dir;
  late File dbFile;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('dpd_level_test');
    dbFile = buildDpdFixture(dir);
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('setting', () {
    test('defaults to Majjhima', () {
      expect(const DpdSettings().level, DictionaryLevel.majjhima);
    });

    test('is stored and read back by name', () async {
      SharedPreferences.setMockInitialValues({});
      final first = DpdSettingsNotifier();
      first.setLevel(DictionaryLevel.vitthara);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(DpdSettingsNotifier.levelKey), 'vitthara');

      final second = DpdSettingsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(second.state.level, DictionaryLevel.vitthara);
    });

    test('an unknown stored value falls back to Majjhima', () async {
      SharedPreferences.setMockInitialValues({'dpd_level': 'nonsense'});
      final notifier = DpdSettingsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.level, DictionaryLevel.majjhima);
    });
  });

  group('open dictionary', () {
    testWidgets('the sheet passes a changed level to the results', (
      tester,
    ) async {
      bigScreen(tester);
      final container = await makeShellContainer(
        tester,
        dbFile,
        words: ['dhamma'],
      );
      await tester.pumpWidget(
        wrapShell(container, const DictionarySheet(initialWord: 'dhamma')),
      );
      await settleShell(tester);
      expect(_shownLevel(tester), DictionaryLevel.majjhima);

      container
          .read(dpdSettingsProvider.notifier)
          .setLevel(DictionaryLevel.sankhitta);
      await settleShell(tester);
      expect(_shownLevel(tester), DictionaryLevel.sankhitta);
    });

    testWidgets('the panel passes a changed level to the results', (
      tester,
    ) async {
      bigScreen(tester);
      final container = await makeShellContainer(
        tester,
        dbFile,
        words: ['dhamma'],
      );
      await tester.pumpWidget(
        wrapShell(container, const DictionaryPanel(initialWord: 'dhamma')),
      );
      await settleShell(tester);
      expect(_shownLevel(tester), DictionaryLevel.majjhima);

      container
          .read(dpdSettingsProvider.notifier)
          .setLevel(DictionaryLevel.vitthara);
      await settleShell(tester);
      expect(_shownLevel(tester), DictionaryLevel.vitthara);
    });
  });

  testWidgets('the settings page selector sets the level', (tester) async {
    bigScreen(tester);
    final container = await makeShellContainer(tester, dbFile);
    await tester.pumpWidget(
      wrapShell(container, const DictionarySettingsBody()),
    );
    await settleShell(tester);

    expect(find.text('Brief'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Full'), findsOneWidget);

    await tester.tap(find.text('Vitthāra'));
    await settleShell(tester);
    expect(
      container.read(dpdSettingsProvider).level,
      DictionaryLevel.vitthara,
    );
  });
}
