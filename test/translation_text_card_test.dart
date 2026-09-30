import 'package:epitaka/core/models/translation_version.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/providers/translation_manifest_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/core/utils/pali_script_converter.dart';
import 'package:epitaka/features/settings/screens/translation_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The "Translation Text" section shows one typography card per visible
/// translation, and each card edits only that language's typography.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Names normally arrive with the web manifest.
    TranslationLanguageRegistry.registerFromManifest(
      const TranslationManifest(
        languageNames: {
          'en': LangInfo('en', 'English', 'English'),
          'my': LangInfo('my', 'မြန်မာ', 'Myanmar'),
          'ru': LangInfo('ru', 'Русский', 'Russian'),
          'vi': LangInfo('vi', 'Tiếng Việt', 'Vietnamese'),
        },
      ),
    );
  });

  Future<ProviderContainer> pumpBody(
    WidgetTester tester, {
    required List<String> enabled,
    Script script = Script.roman,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // No database directory or network in tests.
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
    final prefs = await SharedPreferences.getInstance();
    final notifier = container.read(settingsProvider.notifier);
    notifier.init(prefs);
    for (final code in enabled) {
      await notifier.setTranslationEnabled(code, true);
    }
    await notifier.setPaliScript(script);

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
          home: const Scaffold(body: TranslationSettingsBody()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('one card per visible translation, titled with its name', (
    tester,
  ) async {
    await pumpBody(tester, enabled: ['en']);

    expect(find.text('TRANSLATION TEXT'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('translation_typography_en')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith(
              'translation_typography_',
            ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('translation_typography_en')),
        matching: find.text('English'),
      ),
      findsWidgets,
    );
  });

  testWidgets('choosing Sans-Serif on the card sets that language only', (
    tester,
  ) async {
    final container = await pumpBody(tester, enabled: ['en', 'my']);
    final card = find.byKey(const ValueKey('translation_typography_en'));

    await tester.tap(
      find.descendant(
        of: card,
        matching: find.text('English'),
      ).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: card, matching: find.text('Sans-Serif')),
    );
    await tester.pumpAndSettle();

    final typography = container.read(settingsProvider).typography;
    expect(
      typography.typographyFor('en').fontFamily,
      ReadingFontFamily.sansSerif,
    );
    expect(typography.typographyFor('my').fontFamily, ReadingFontFamily.serif);
    expect(typography.pali.fontFamily, ReadingFontFamily.serif);
  });

  testWidgets('no section when no translation is visible', (tester) async {
    final container = await pumpBody(tester, enabled: const []);
    await container.read(settingsProvider.notifier).setShowTranslation(false);
    await tester.pumpAndSettle();

    expect(find.text('TRANSLATION TEXT'), findsNothing);
  });

  // Font chips shown on a card after it is expanded by tapping its title.
  Future<List<String>> chipsOn(
    WidgetTester tester,
    Key cardKey,
    String title,
  ) async {
    final card = find.byKey(cardKey);
    await tester.tap(
      find.descendant(of: card, matching: find.text(title)).first,
    );
    await tester.pumpAndSettle();
    return [
      for (final f in ReadingFontFamily.values)
        if (find
            .descendant(of: card, matching: find.text(f.label))
            .evaluate()
            .isNotEmpty)
          f.label,
    ];
  }

  // Section labels are drawn upper-cased.
  const fontSection = 'FONT FAMILY';

  testWidgets('translation cards offer fonts only for Latin and Cyrillic', (
    tester,
  ) async {
    await pumpBody(tester, enabled: ['en', 'ru', 'vi', 'my']);
    const all = ['Serif', 'Sans-Serif', 'Monospace'];

    expect(
      await chipsOn(
        tester,
        const ValueKey('translation_typography_en'),
        'English',
      ),
      all,
    );
    expect(
      await chipsOn(
        tester,
        const ValueKey('translation_typography_ru'),
        'Russian',
      ),
      all,
    );
    expect(
      await chipsOn(
        tester,
        const ValueKey('translation_typography_vi'),
        'Vietnamese',
      ),
      ['Serif', 'Sans-Serif'],
    );
    final myCard = const ValueKey('translation_typography_my');
    expect(await chipsOn(tester, myCard, 'Myanmar'), isEmpty);
    expect(
      find.descendant(of: find.byKey(myCard), matching: find.text(fontSection)),
      findsNothing,
    );
  });

  const paliCard = ValueKey('pali_typography');

  testWidgets('Pāli card offers all three fonts for Roman', (tester) async {
    await pumpBody(tester, enabled: const [], script: Script.roman);
    expect(await chipsOn(tester, paliCard, 'Pāli'), [
      'Serif',
      'Sans-Serif',
      'Monospace',
    ]);
  });

  testWidgets('Pāli card hides Monospace for Tai Tham', (tester) async {
    await pumpBody(tester, enabled: const [], script: Script.taitham);
    expect(await chipsOn(tester, paliCard, 'Pāli'), ['Serif', 'Sans-Serif']);
  });

  testWidgets('Pāli card hides the font family section for Myanmar', (
    tester,
  ) async {
    await pumpBody(tester, enabled: const [], script: Script.myanmar);
    expect(await chipsOn(tester, paliCard, 'Pāli'), isEmpty);
    expect(
      find.descendant(
        of: find.byKey(paliCard),
        matching: find.text(fontSection),
      ),
      findsNothing,
    );
    // The card is open: its other controls are still there.
    expect(
      find.descendant(of: find.byKey(paliCard), matching: find.text('FONT SIZE')),
      findsOneWidget,
    );
  });
}
