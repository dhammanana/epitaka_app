/// Keyboard shortcuts for the dictionary's settings and controls (Phase 9).
/// They ship with no keys; the user binds them in Settings → Keyboard
/// Shortcuts, and they then work from anywhere in the app.
library;

import 'dart:io';

import 'package:epitaka/features/dictionary/providers/dictionary_font_scale_provider.dart';
import 'package:epitaka/features/dictionary/providers/dictionary_header_provider.dart';
import 'package:epitaka/features/dictionary/providers/dictionary_sheet_open_provider.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_panel.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/features/dpd/providers/dpd_settings_provider.dart';
import 'package:epitaka/shared/utils/app_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart';
import 'tap_lookup_test.dart' show fieldTextOf;

const _ids = [
  'dict-level-sankhitta',
  'dict-level-majjhima',
  'dict-level-vitthara',
  'dict-summary',
  'dict-grammar',
  'dict-examples',
  'dict-text-larger',
  'dict-text-smaller',
  'dict-top',
  'dict-history',
  'dict-back',
  'dict-forward',
  'dict-search',
];

const _letters = [
  LogicalKeyboardKey.keyA,
  LogicalKeyboardKey.keyB,
  LogicalKeyboardKey.keyC,
  LogicalKeyboardKey.keyD,
  LogicalKeyboardKey.keyE,
  LogicalKeyboardKey.keyF,
  LogicalKeyboardKey.keyG,
  LogicalKeyboardKey.keyH,
  LogicalKeyboardKey.keyI,
  LogicalKeyboardKey.keyJ,
  LogicalKeyboardKey.keyK,
  LogicalKeyboardKey.keyL,
  LogicalKeyboardKey.keyM,
];

/// A distinct Alt key per row, as a user would bind them.
final _keys = {
  for (var i = 0; i < _ids.length; i++)
    _ids[i]: SingleActivator(_letters[i], alt: true),
};

void main() {
  setUp(() => AppShortcuts.overrides = const {});
  tearDown(() => AppShortcuts.overrides = const {});

  test('thirteen app-wide rows under the dictionary heading, with no keys', () {
    final rows = AppShortcuts.shortcutCatalog
        .where((b) => b.section == ShortcutSection.dictionary)
        .toList();
    expect(rows.map((b) => b.id), _ids);
    expect(ShortcutSection.dictionary.isAppWide, isTrue);
    for (final b in rows) {
      expect(b.activators, isEmpty, reason: b.id);
      expect(AppShortcuts.hintFor(b.id), '', reason: b.id);
    }
  });

  group('a bound key runs its action', () {
    late ProviderContainer c;
    late Map<ShortcutActivator, VoidCallback> bindings;

    Future<void> bind(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      AppShortcuts.overrides = _keys;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              c = ProviderScope.containerOf(context);
              bindings = AppShortcuts.bindings(
                GlobalKey<NavigatorState>(),
                ref,
              );
              return const SizedBox();
            },
          ),
        ),
      );
    }

    void press(String id) {
      final want = _keys[id]!;
      final hit = bindings.entries.firstWhere(
        (e) =>
            e.key is SingleActivator &&
            (e.key as SingleActivator).trigger == want.trigger &&
            (e.key as SingleActivator).alt,
      );
      hit.value();
    }

    testWidgets('the three levels', (tester) async {
      await bind(tester);
      press('dict-level-sankhitta');
      expect(c.read(dpdSettingsProvider).level, DictionaryLevel.sankhitta);
      press('dict-level-vitthara');
      expect(c.read(dpdSettingsProvider).level, DictionaryLevel.vitthara);
      press('dict-level-majjhima');
      expect(c.read(dpdSettingsProvider).level, DictionaryLevel.majjhima);
    });

    testWidgets('summary, grammar and examples switch each way', (
      tester,
    ) async {
      await bind(tester);
      final before = c.read(dpdSettingsProvider);
      press('dict-summary');
      press('dict-grammar');
      press('dict-examples');
      final after = c.read(dpdSettingsProvider);
      expect(after.showSummary, !before.showSummary);
      expect(after.grammarOpen, !before.grammarOpen);
      expect(after.examplesOpen, !before.examplesOpen);
      press('dict-summary');
      expect(c.read(dpdSettingsProvider).showSummary, before.showSummary);
    });

    testWidgets('text larger and smaller by one step', (tester) async {
      await bind(tester);
      final start = c.read(dictionaryFontScaleProvider);
      press('dict-text-larger');
      expect(
        c.read(dictionaryFontScaleProvider),
        closeTo(start + kDictionaryFontScaleStep, 1e-9),
      );
      press('dict-text-smaller');
      press('dict-text-smaller');
      expect(
        c.read(dictionaryFontScaleProvider),
        closeTo(start - kDictionaryFontScaleStep, 1e-9),
      );
    });

    testWidgets('top, history, back, forward and search raise their requests', (
      tester,
    ) async {
      await bind(tester);
      for (final id in [
        'dict-top',
        'dict-history',
        'dict-back',
        'dict-forward',
        'dict-search',
      ]) {
        press(id);
      }
      expect(c.read(dictionaryScrollTopRequestProvider), 1);
      expect(c.read(dictionaryHistoryRequestProvider), 1);
      expect(c.read(dictionaryBackRequestProvider), 1);
      expect(c.read(dictionaryForwardRequestProvider), 1);
      expect(c.read(dictionarySearchFocusRequestProvider), 1);
    });
  });

  group('the open dictionary answers the requests', () {
    late Directory dir;
    late File dbFile;

    setUpAll(() async {
      dir = await Directory.systemTemp.createTemp('dictionary_shortcuts');
      dbFile = buildDpdFixture(dir);
    });

    tearDownAll(() async {
      await dir.delete(recursive: true);
    });

    bool fieldFocused(WidgetTester tester) => tester
        .widget<TextField>(find.byType(TextField).first)
        .focusNode!
        .hasFocus;

    Future<void> submit(WidgetTester tester, String word) async {
      await tester.enterText(find.byType(TextField).first, word);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settleShell(tester);
    }

    Future<void> request(
      WidgetTester tester,
      ProviderContainer c,
      StateProvider<int> p,
    ) async {
      c.read(p.notifier).state++;
      await settleShell(tester);
    }

    testWidgets('panel: back, forward, then the search field', (tester) async {
      tester.view.physicalSize = const Size(900, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = await makeShellContainer(
        tester,
        dbFile,
        words: ['dhamma', 'kammaṃ'],
      );
      await tester.pumpWidget(wrapShell(c, const DictionaryPanel()));
      await tester.pump();
      await submit(tester, 'dhamma');
      await submit(tester, 'kammaṃ');

      await request(tester, c, dictionaryBackRequestProvider);
      expect(fieldTextOf(tester), 'dhamma');
      await request(tester, c, dictionaryForwardRequestProvider);
      expect(fieldTextOf(tester), 'kammaṃ');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(fieldFocused(tester), isFalse);
      await request(tester, c, dictionarySearchFocusRequestProvider);
      expect(fieldFocused(tester), isTrue);
    });

    testWidgets('a panel under an open sheet ignores the requests', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = await makeShellContainer(
        tester,
        dbFile,
        words: ['dhamma', 'kammaṃ'],
      );
      await tester.pumpWidget(wrapShell(c, const DictionaryPanel()));
      await tester.pump();
      await submit(tester, 'dhamma');
      await submit(tester, 'kammaṃ');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      c.read(dictionarySheetOpenProvider.notifier).state = 1;
      await request(tester, c, dictionaryBackRequestProvider);
      await request(tester, c, dictionarySearchFocusRequestProvider);
      expect(fieldTextOf(tester), 'kammaṃ');
      expect(fieldFocused(tester), isFalse);

      c.read(dictionarySheetOpenProvider.notifier).state = 0;
      await request(tester, c, dictionaryBackRequestProvider);
      expect(fieldTextOf(tester), 'dhamma');
    });

    testWidgets('sheet: back, forward, then the search field', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = await makeShellContainer(
        tester,
        dbFile,
        words: ['dhamma', 'kammaṃ'],
      );
      await tester.pumpWidget(
        wrapShell(c, const DictionarySheet(initialWord: 'dhamma')),
      );
      await settleShell(tester);
      await submit(tester, 'kammaṃ');

      await request(tester, c, dictionaryBackRequestProvider);
      expect(fieldTextOf(tester), 'dhamma');
      await request(tester, c, dictionaryForwardRequestProvider);
      expect(fieldTextOf(tester), 'kammaṃ');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(fieldFocused(tester), isFalse);
      await request(tester, c, dictionarySearchFocusRequestProvider);
      expect(fieldFocused(tester), isTrue);
    });
  });
}
