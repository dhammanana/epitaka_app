/// Vitthāra's other sections: frequency, sutta info, pronunciation audio and
/// the feedback links, from real fixture rows.
library;

import 'dart:io';

import 'package:epitaka/core/providers/settings_provider.dart'
    show ThemePreference;
import 'package:epitaka/core/theme/app_theme.dart';
import 'package:epitaka/features/dpd/database/dpd_database.dart';
import 'package:epitaka/features/dpd/models/frequency_data.dart';
import 'package:epitaka/features/dpd/providers/dpd_settings_provider.dart';
import 'package:epitaka/features/dpd/theme/dpd_palette_from_scheme.dart';
import 'package:epitaka/features/dpd/widgets/entry_content.dart';
import 'package:epitaka/features/dpd/widgets/feedback_section.dart';
import 'package:epitaka/features/dpd/widgets/frequency_section.dart';
import 'package:epitaka/features/dpd/widgets/frequency_table.dart';
import 'package:epitaka/features/dpd/widgets/inline_entry_card.dart';
import 'package:epitaka/features/dpd/widgets/sutta_info_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart';

String _plain(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText())
    .join('\n');

void main() {
  late Directory dir;
  late File dbFile;
  late DpdDatabase db;
  late DpdDao dao;

  // Real fixture ids.
  const dhammaId = 34626; // dhamma 1.01: frequency data
  const anugaId = 4375; // IPA, frequency data
  const suttaId = 48950; // brahmajālasutta: a sutta_info row

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('dpd_extras_test');
    dbFile = buildDpdFixture(dir);
    db = DpdDatabase(dbFile);
    dao = DpdDao(db);
  });

  tearDownAll(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  group('frequency data', () {
    test('parses a real row', () async {
      final h = (await dao.getById(dhammaId))!;
      final data = parseFrequencyData(h.freqData)!;
      expect(data.freqHeading, contains('dhamma 1.01'));
      expect(data.isNoExactMatches, isFalse);
      expect(data.cstFreq.length, data.cstGrad.length);
      expect(data.cstFreq, isNotEmpty);
      expect(data.cstFreq[0], 302);
    });

    test('a null, empty or broken value gives nothing', () {
      expect(parseFrequencyData(null), isNull);
      expect(parseFrequencyData(''), isNull);
      expect(parseFrequencyData('{not json'), isNull);
    });
  });

  group('the heat map reads in every theme', () {
    void wide(WidgetTester tester) {
      tester.view.physicalSize = const Size(2400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    for (final pref in ThemePreference.values) {
      for (final brightness in Brightness.values) {
        if (pref != ThemePreference.system && brightness == Brightness.dark) {
          continue;
        }
        testWidgets('${pref.name} ${brightness.name}', (tester) async {
          wide(tester);
          final h = (await tester.runAsync(() => dao.getById(dhammaId)))!;
          final data = parseFrequencyData(h.freqData)!;
          final theme = AppTheme.forPreference(
            pref,
            platformBrightness: brightness,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: FrequencyTable(data: data),
                ),
              ),
            ),
          );

          // A cell is a Container with a fill and one number inside.
          var checked = 0;
          for (final c in tester.widgetList<Container>(find.byType(Container))) {
            final deco = c.decoration;
            final child = c.child;
            if (deco is! BoxDecoration || child is! Text) continue;
            final fill = deco.color;
            final color = child.style?.color;
            if (fill == null || color == null) continue;
            if (fill == Colors.transparent) continue;
            final shown = Color.alphaBlend(fill, theme.colorScheme.surface);
            expect(
              contrastRatio(color, shown),
              greaterThanOrEqualTo(kDpdMinContrast),
              reason: 'cell ${child.data}',
            );
            checked++;
          }
          expect(checked, greaterThan(20));
        });
      }
    }
  });

  group('in an entry card', () {
    void bigScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    Future<void> loaded(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await settleShell(tester, frames: 4);
    }

    Future<void> openCard(
      WidgetTester tester,
      int id,
      DictionaryLevel level, {
      bool online = false,
    }) async {
      bigScreen(tester);
      final h = (await tester.runAsync(() => dao.getById(id)))!;
      final container = await makeShellContainer(
        tester,
        dbFile,
        online: online,
      );
      container.read(dpdSettingsProvider.notifier).setLevel(level);
      await tester.pumpWidget(
        wrapShell(
          container,
          SingleChildScrollView(
            child: InlineEntryCard(
              headword: h,
              level: level,
              lookupKey: h.headword.lemma1,
            ),
          ),
        ),
      );
      await settleShell(tester, frames: 4);
      await loaded(tester);
    }

    Future<void> press(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await settleShell(tester, frames: 4);
    }

    testWidgets('Majjhima has none of these buttons', (tester) async {
      await openCard(tester, suttaId, DictionaryLevel.majjhima, online: true);
      expect(find.text('sutta'), findsNothing);
      expect(find.text('feedback'), findsNothing);
      expect(find.byType(DpdPlayButton), findsNothing);
      await openCard(tester, dhammaId, DictionaryLevel.majjhima, online: true);
      expect(find.text('frequency'), findsNothing);
    });

    testWidgets('the frequency button opens the heat map', (tester) async {
      await openCard(tester, dhammaId, DictionaryLevel.vitthara);
      expect(find.byType(FrequencySection), findsNothing);
      await press(tester, 'frequency');
      expect(find.byType(FrequencySection), findsOneWidget);
      expect(find.byType(FrequencyTable), findsOneWidget);
      expect(_plain(tester), contains('Frequency of dhamma 1.01'));
      expect(_plain(tester), contains('Chaṭṭha Saṅgāyana Tipiṭaka'));
    });

    testWidgets('the sutta button opens the sutta info', (tester) async {
      await openCard(tester, suttaId, DictionaryLevel.vitthara);
      expect(find.byType(SuttaInfoSection), findsNothing);
      await press(tester, 'sutta');
      expect(find.byType(SuttaInfoSection), findsOneWidget);
      expect(_plain(tester), contains('DN1'));
    });

    testWidgets('raising the level under a kept card loads the sutta row',
        (tester) async {
      bigScreen(tester);
      final h = (await tester.runAsync(() => dao.getById(suttaId)))!;
      final container = await makeShellContainer(tester, dbFile);
      Widget card(DictionaryLevel level) => wrapShell(
        container,
        SingleChildScrollView(
          child: InlineEntryCard(
            key: ValueKey(h.headword.id),
            headword: h,
            level: level,
            lookupKey: h.headword.lemma1,
          ),
        ),
      );
      await tester.pumpWidget(card(DictionaryLevel.majjhima));
      await settleShell(tester, frames: 4);
      await loaded(tester);
      expect(find.text('sutta'), findsNothing);

      await tester.pumpWidget(card(DictionaryLevel.vitthara));
      await settleShell(tester, frames: 4);
      await loaded(tester);
      expect(find.text('sutta'), findsOneWidget);
    });

    testWidgets('a word with no sutta row has no sutta button',
        (tester) async {
      await openCard(tester, dhammaId, DictionaryLevel.vitthara);
      expect(find.text('sutta'), findsNothing);
    });

    testWidgets('the feedback button opens the links', (tester) async {
      await openCard(tester, dhammaId, DictionaryLevel.vitthara);
      await press(tester, 'feedback');
      expect(find.byType(FeedbackSection), findsOneWidget);
      final text = _plain(tester);
      expect(text, contains('ID $dhammaId'));
      expect(text, contains('https://dpdict.net/$dhammaId'));
      expect(text, contains('Add a missing word'));
      expect(text, contains('Correct a mistake'));
    });

    testWidgets('the play button shows only online, at Vitthāra',
        (tester) async {
      await openCard(tester, anugaId, DictionaryLevel.vitthara, online: true);
      expect(find.byType(DpdPlayButton), findsOneWidget);
      await openCard(tester, anugaId, DictionaryLevel.vitthara);
      expect(find.byType(DpdPlayButton), findsNothing);
    });

    testWidgets('the IPA row has three voices online, at Vitthāra',
        (tester) async {
      await openCard(tester, anugaId, DictionaryLevel.vitthara, online: true);
      await press(tester, 'grammar');
      expect(_plain(tester), contains('/ən̪ugə/'));
      expect(find.byType(DpdPlayButton), findsNWidgets(4));
      final voices = tester
          .widgetList<DpdPlayButton>(find.byType(DpdPlayButton))
          .where((b) => b.compact)
          .map((b) => b.gender);
      expect(voices, ['male1', 'male2', 'female1']);
    });

    testWidgets('the IPA row is text only below Vitthāra', (tester) async {
      await openCard(tester, anugaId, DictionaryLevel.majjhima, online: true);
      await press(tester, 'grammar');
      expect(_plain(tester), contains('/ən̪ugə/'));
      expect(find.byType(DpdPlayButton), findsNothing);
    });
  });
}
