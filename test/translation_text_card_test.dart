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
      find.descendant(of: card, matching: find.text('Serif')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sans-Serif').last);
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

  // Opens the font picker from a card: tap the card's title to expand it,
  // then the current-font row.
  Future<void> openPicker(
    WidgetTester tester,
    Key cardKey,
    String title,
  ) async {
    final card = find.byKey(cardKey);
    await tester.tap(
      find.descendant(of: card, matching: find.text(title)).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: card, matching: find.text('Serif')),
    );
    await tester.pumpAndSettle();
  }

  const paliCard = ValueKey('pali_typography');

  // Section labels are drawn upper-cased.
  const fontSection = 'FONT FAMILY';

  testWidgets('every card opens the picker with the bundled families', (
    tester,
  ) async {
    await pumpBody(tester, enabled: ['en', 'my']);

    await openPicker(
      tester,
      const ValueKey('translation_typography_en'),
      'English',
    );
    expect(find.text('Sans-Serif'), findsOneWidget);
    expect(find.text('Monospace'), findsOneWidget);
  });

  testWidgets('the picker searches Google Fonts and picks the match', (
    tester,
  ) async {
    final container = await pumpBody(tester, enabled: const []);
    await openPicker(tester, paliCard, 'Pāli');

    await tester.enterText(find.byType(TextField).last, 'Lora');
    await tester.pumpAndSettle();
    final row = find.descendant(
      of: find.byType(ListView),
      matching: find.text('Lora'),
    );
    expect(row, findsOneWidget);

    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(
      container.read(settingsProvider).typography.pali.fontFamily,
      ReadingFontFamily.google('Lora'),
    );
  });

  testWidgets('a Google font can be chosen for any Pāli script', (
    tester,
  ) async {
    await pumpBody(tester, enabled: const [], script: Script.myanmar);
    // A script with a single bundled font is no longer locked to it: the
    // section is there and opens the full catalog.
    final card = find.byKey(paliCard);
    await tester.tap(
      find.descendant(of: card, matching: find.text('Pāli')).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: card, matching: find.text(fontSection)),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: card, matching: find.text('Serif')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sans-Serif'), findsOneWidget);
  });

  testWidgets('no section when no translation is visible', (tester) async {
    final container = await pumpBody(tester, enabled: const []);
    await container.read(settingsProvider.notifier).setShowTranslation(false);
    await tester.pumpAndSettle();

    expect(find.text('TRANSLATION TEXT'), findsNothing);
  });
}
