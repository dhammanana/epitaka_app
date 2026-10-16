/// One visible change for each DPD option in the dictionary settings.
library;

import 'dart:io';

import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/features/dpd/providers/dict_entries_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_lookup_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_settings_provider.dart';
import 'package:epitaka/features/dpd/widgets/entry_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart';

String _drawn(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText())
    .join('\n');

void main() {
  late Directory dir;
  late File dbFile;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('options_test');
    dbFile = buildDpdFixture(dir);
  });

  tearDownAll(() async {
    // These tests save the partial and fuzzy switches. Files share a
    // process in `just test`, so leave the store empty for the next file.
    SharedPreferences.setMockInitialValues({});
    await dir.delete(recursive: true);
  });

  /// The sheet for [word] with [configure] applied before the lookup runs, so
  /// the lookup is made with the option already set.
  Future<ProviderContainer> show(
    WidgetTester tester,
    String word, {
    void Function(DpdSettingsNotifier s)? configure,
    bool online = false,
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = await makeShellContainer(tester, dbFile, online: online);
    configure?.call(c.read(dpdSettingsProvider.notifier));
    await tester.runAsync(() async {
      c.listen(dpdLookupProvider(word), (_, _) {});
      await c.read(dpdLookupProvider(word).future);
      for (final id in ['peu', 'bhs', 'apte', 'pts']) {
        final key = DictEntriesKey(id, word);
        c.listen(dictEntriesProvider(key), (_, _) {});
        await c.read(dictEntriesProvider(key).future);
      }
    });
    await tester.pumpWidget(wrapShell(c, DictionarySheet(initialWord: word)));
    await settleShell(tester);
    return c;
  }

  void sankhitta(DpdSettingsNotifier s) => s.setLevel(DictionaryLevel.sankhitta);

  testWidgets('construction in the summary is on by default', (tester) async {
    await show(tester, 'dhamma', configure: sankhitta);
    expect(_drawn(tester), contains('√dhar + ma'));
  });

  testWidgets('construction in the summary can be switched off', (tester) async {
    await show(
      tester,
      'dhamma',
      configure: (s) {
        sankhitta(s);
        s.setShowConstructionInSummary(false);
      },
    );
    expect(_drawn(tester), isNot(contains('√dhar + ma')));
  });

  testWidgets('no partial results by default', (tester) async {
    await show(tester, 'ti');
    expect(_drawn(tester), isNot(contains('Partial Results')));
  });

  testWidgets('partial results: a heading and the headwords', (tester) async {
    await show(tester, 'ti', configure: (s) => s.setShowPartialResults(true));
    expect(_drawn(tester), contains('Partial Results'));
    expect(_drawn(tester), contains('tithi'));
    expect(_drawn(tester), isNot(contains('Fuzzy Results')));
  });

  // At Saṅkhitta the results view draws nothing, so the tier must draw its
  // headwords itself, or the heading stands over an empty space.
  testWidgets('partial results at Saṅkhitta: summary lines under the heading', (
    tester,
  ) async {
    await show(
      tester,
      'ti',
      configure: (s) {
        sankhitta(s);
        s.setShowPartialResults(true);
      },
    );
    expect(_drawn(tester), contains('Partial Results'));
    expect(_drawn(tester), contains('tithi'));
  });

  testWidgets('no fuzzy results by default', (tester) async {
    await show(tester, 'kammaṃ');
    expect(_drawn(tester), isNot(contains('Fuzzy Results')));
  });

  testWidgets('fuzzy results: a heading and the headwords', (tester) async {
    await show(tester, 'kammaṃ', configure: (s) => s.setShowFuzzyResults(true));
    final text = _drawn(tester);
    expect(text, contains('Fuzzy Results'));
    expect(text, contains('khama'));
    expect(text, isNot(contains('Partial Results')));
  });

  group('sandhi marks', () {
    void open(DpdSettingsNotifier s) {
      s.setExamplesOpen(true);
      s.setGrammarOpen(true);
    }

    testWidgets('shown by default', (tester) async {
      await show(tester, 'evaṃ', configure: open);
      expect(_drawn(tester), contains("yāva'd'eva"));
    });

    testWidgets('off: the marks between letters go from the examples', (
      tester,
    ) async {
      await show(
        tester,
        'evaṃ',
        configure: (s) {
          open(s);
          s.setShowSandhi(false);
        },
      );
      expect(_drawn(tester), contains('yāvadeva'));
      expect(_drawn(tester), isNot(contains("yāva'd'eva")));
    });

    testWidgets('off: the commentary loses them too', (tester) async {
      await show(
        tester,
        'kammaṃ',
        configure: (s) {
          open(s);
          s.setShowSandhi(false);
        },
      );
      // "tamhā ca kammā'ti tato corakammato." in the commentary of kamma 2.
      expect(_drawn(tester), contains('tamhā ca kammāti'));
    });

    testWidgets('off: a lone mark, and English text, stay', (tester) async {
      await show(
        tester,
        'ti',
        configure: (s) => s.setShowSandhi(false),
      );
      expect(_drawn(tester), contains("(end of direct speech) ' '"));
    });
  });

  testWidgets('the voice setting picks the recording the button plays', (
    tester,
  ) async {
    // The pronunciation button is part of the Vitthāra level.
    final c = await show(
      tester,
      'dhamma',
      online: true,
      configure: (s) => s.setLevel(DictionaryLevel.vitthara),
    );
    String voice() =>
        tester.widget<DpdPlayButton>(find.byType(DpdPlayButton).first).gender;
    expect(voice(), 'male');

    c.read(dpdSettingsProvider.notifier).setAudioGender(AudioGender.female);
    await settleShell(tester);
    expect(voice(), 'female');
  });

  testWidgets('the options survive a new container', (tester) async {
    final c = await show(
      tester,
      'ti',
      configure: (s) {
        s.setShowPartialResults(true);
        s.setShowFuzzyResults(true);
        s.setShowConstructionInSummary(false);
        s.setShowSummary(false);
        s.setAudioGender(AudioGender.female);
      },
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    final fresh = ProviderContainer();
    addTearDown(fresh.dispose);
    fresh.read(dpdSettingsProvider);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    final s = fresh.read(dpdSettingsProvider);
    expect(s, c.read(dpdSettingsProvider));
    expect(s.showPartialResults, isTrue);
    expect(s.showSummary, isFalse);
    expect(s.audioGender, AudioGender.female);
  });
}
