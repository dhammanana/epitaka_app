import 'package:epitaka/core/models/translation_version.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/providers/translation_manifest_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/core/utils/pali_script_converter.dart';
import 'package:epitaka/core/utils/pali_text_utils.dart';
import 'package:epitaka/features/settings/screens/appearance_settings_screen.dart';
import 'package:epitaka/features/settings/screens/translation_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Pāli and translation typography cards appear on both the appearance
/// and the translations screen. Both edit the one stored setting, so a
/// change on one screen shows on the other.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a font picked on Appearance shows on the translations screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 3000);
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
          home: const Scaffold(
            body: Row(
              children: [
                Expanded(child: AppearanceSettingsBody()),
                Expanded(child: TranslationSettingsBody()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cards = find.byKey(const ValueKey('pali_typography'));
    expect(cards, findsNWidgets(2));
    final appearanceCard = cards.at(0);
    final translationsCard = cards.at(1);
    // The appearance body is the first child of the Row.
    expect(
      find.descendant(
        of: find.byType(AppearanceSettingsBody),
        matching: appearanceCard,
      ),
      findsOneWidget,
    );

    Future<void> open(Finder card) async {
      await tester.tap(
        find.descendant(of: card, matching: find.text('Pāli')).first,
      );
      await tester.pumpAndSettle();
    }

    await open(appearanceCard);
    await open(translationsCard);
    await tester.tap(
      find.descendant(of: appearanceCard, matching: find.text('Sans-Serif')),
    );
    await tester.pumpAndSettle();

    expect(
      container.read(settingsProvider).typography.pali.fontFamily,
      ReadingFontFamily.sansSerif,
    );
    final preview = tester.widget<Text>(
      find.descendant(
        of: translationsCard,
        matching: find.text(convertPaliToScript('Evaṃ me sutaṃ…', Script.roman)),
      ),
    );
    expect(preview.style?.fontFamily, 'DejaVuSans');
  });
}
