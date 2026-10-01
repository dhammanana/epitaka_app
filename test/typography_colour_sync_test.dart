import 'package:epitaka/core/models/translation_version.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/providers/translation_manifest_provider.dart';
import 'package:epitaka/core/theme/color_pair.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/settings/screens/translation_settings_screen.dart';
import 'package:epitaka/features/settings/widgets/color_swatch.dart';
import 'package:flutter/material.dart' hide ColorSwatch;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Pāli and translation colours live once, in the reading colour pairs.
/// The typography cards and the reading-colours screen edit the same value.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a colour saved on a card the old way moves into the reading colour', () async {
    const old = Color(0xFF3D3D8F);
    const oldEn = Color(0xFF2A6B6B);
    final prefs = await SharedPreferences.getInstance();

    // An earlier version stored the colour inside the typography.
    final before = SettingsNotifier(null)..init(prefs);
    await before.setTranslationEnabled('en', true);
    await before.setPaliTypography(
      before.state.typography.pali.copyWith(color: old),
    );
    await before.setLanguageTypography(
      'en',
      before.state.typography.typographyFor('en').copyWith(color: oldEn),
    );

    // Next start: the colours move into the pairs; the card copies clear.
    final after = SettingsNotifier(null)..init(prefs);
    await Future<void>.delayed(Duration.zero);
    // The old card colour applied in both modes, so both keep it.
    expect(after.state.paliColorPair.light, old);
    expect(after.state.paliColorPair.dark, old);
    expect(after.state.typography.pali.color, isNull);
    expect(after.state.translationColorPair.light, oldEn);
    expect(after.state.translationColorPair.dark, oldEn);
    expect(after.state.typography.typographyFor('en').color, isNull);

    // And it stays moved on the start after that.
    final again = SettingsNotifier(null)..init(prefs);
    expect(again.state.paliColorPair.light, old);
    expect(again.state.typography.pali.color, isNull);
  });

  Future<(ProviderContainer, Finder)> pumpPaliCard(
    WidgetTester tester, {
    required ThemeData theme,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        localTranslationVersionsProvider.overrideWith(
          (ref) async => const <TranslationVersion>[],
        ),
        mergedTranslationVersionsProvider.overrideWith(
          (ref) async => const <TranslationVersion>[],
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(settingsProvider.notifier)
        .init(await SharedPreferences.getInstance());

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
          theme: theme,
          home: const Scaffold(body: TranslationSettingsBody()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('pali_typography'));
    await tester.tap(find.descendant(of: card, matching: find.text('Pāli')).first);
    await tester.pumpAndSettle();
    return (container, card);
  }

  Future<void> tapSwatch(WidgetTester tester, Finder card, Color color) async {
    await tester.tap(
      find.descendant(
        of: card,
        matching: find.byWidgetPredicate(
          (w) => w is ColorSwatch && w.color == color,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a colour picked on the Pāli card is the reading colour', (
    tester,
  ) async {
    final (container, card) = await pumpPaliCard(
      tester,
      theme: ThemeData.light(),
    );

    const picked = Color(0xFF3D3D8F);
    await tapSwatch(tester, card, picked);

    final settings = container.read(settingsProvider);
    expect(settings.paliColorPair.light, picked);
    expect(settings.typography.pali.color, isNull);

    // A colour set on the reading-colours screen shows on the card.
    const fromColoursScreen = Color(0xFF3C6E47);
    await container
        .read(settingsProvider.notifier)
        .setPaliColor(fromColoursScreen);
    await tester.pumpAndSettle();
    final swatch = tester.widget<ColorSwatch>(
      find.descendant(
        of: card,
        matching: find.byWidgetPredicate(
          (w) => w is ColorSwatch && w.color == fromColoursScreen,
        ),
      ),
    );
    expect(swatch.isSelected, isTrue);
  });

  testWidgets('in dark mode a picked colour is drawn exactly as picked', (
    tester,
  ) async {
    final (container, card) = await pumpPaliCard(
      tester,
      theme: ThemeData.dark(),
    );
    final lightBefore = container.read(settingsProvider).paliColorPair.light;

    // The blue a user reported as coming out near-white in dark mode.
    const picked = Color(0xFF3D3D8F);
    await tapSwatch(tester, card, picked);

    final pair = container.read(settingsProvider).paliColorPair;
    expect(pair.dark, picked);
    expect(pair.light, lightBefore);
  });

  group('dark colour is derived until the user picks one', () {
    // Pairs copied from a real saved settings file on 2026-09-30. Each dark
    // colour there was derived from its light one.
    test('saved derived pairs load as not picked', () {
      for (final raw in [
        {'light': 'ff000000', 'dark': 'ffb3b3b3'},
        {'light': 'ff7a2e1d', 'dark': 'fff4e9e6'},
        {'light': 'ff3d3d8f', 'dark': 'ffe8e8f2'},
      ]) {
        expect(ColorPair.fromJson(raw).darkPicked, isFalse, reason: '$raw');
      }
      expect(
        ColorPair.fromJson(ColorPair.pali.toJson()..remove('darkPicked'))
            .darkPicked,
        isFalse,
      );
    });

    test('a saved hand-picked dark colour loads as picked', () {
      final pair = ColorPair.fromJson({
        'light': 'ff3d3d8f',
        'dark': 'ff3d3d8f',
      });
      expect(pair.darkPicked, isTrue);
      // The flag survives a save and load.
      expect(ColorPair.fromJson(pair.toJson()), pair);
    });

    test('a light pick derives the dark colour only before a dark pick', () async {
      final prefs = await SharedPreferences.getInstance();
      final n = SettingsNotifier(null)..init(prefs);
      const firstLight = Color(0xFF3C6E47);
      await n.setPaliColor(firstLight);
      expect(n.state.paliColorPair.dark, ColorPair.deriveDark(firstLight));

      const myDark = Color(0xFF4A6FA5);
      await n.setPaliColorPair(n.state.paliColorPair.withDark(myDark));
      await n.setPaliColor(const Color(0xFFB5651D));
      expect(n.state.paliColorPair.light, const Color(0xFFB5651D));
      expect(n.state.paliColorPair.dark, myDark);

      // It stays that way after a restart.
      final again = SettingsNotifier(null)..init(prefs);
      await again.setPaliColor(const Color(0xFF7A2E1D));
      expect(again.state.paliColorPair.dark, myDark);
    });
  });
}
