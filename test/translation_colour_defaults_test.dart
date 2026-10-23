import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/theme/color_pair.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/core/utils/pali_script_converter.dart';
import 'package:epitaka/features/reader/providers/reader_provider.dart'
    show LineData, ParagraphData;
import 'package:epitaka/features/settings/screens/reading_colors_screen.dart';
import 'package:epitaka/features/settings/widgets/color_swatch.dart';
import 'package:epitaka/shared/widgets/reading_paragraph.dart';
import 'package:flutter/material.dart' hide ColorSwatch;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Translations must not all draw in one colour, and the palette must work
/// for however many languages exist — no per-language table.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Pāli defaults to black in light mode and light text in dark mode', () {
    expect(ColorPair.pali.light, const Color(0xFF000000));
    expect(
      ColorPair.pali.dark.computeLuminance(),
      greaterThan(ColorPair.pali.light.computeLuminance()),
    );
  });

  test('each visible translation gets a different colour', () {
    final settings = AppSettings(enabledTranslations: const ['en', 'my', 'th']);
    for (final brightness in Brightness.values) {
      final colors = [
        for (final code in settings.visibleTranslationLangs)
          settings.translationColorForLang(brightness, code),
      ];
      expect(colors.toSet(), hasLength(colors.length), reason: '$brightness');
    }
  });

  test('any number of languages resolves without a language table', () {
    final codes = [for (var i = 0; i < 25; i++) 'lang$i'];
    final settings = AppSettings(enabledTranslations: codes);
    final colors = [
      for (final code in codes)
        settings.translationColorForLang(Brightness.light, code),
    ];
    expect(colors, hasLength(codes.length));
    expect(colors.toSet(), hasLength(ColorPair.translationPalette.length));
  });

  test('a colour picked for one language leaves the others alone', () {
    final picked = ColorPair.fromLight(const Color(0xFF123456));
    final settings = AppSettings(
      enabledTranslations: const ['en', 'my'],
      translationColorOverrides: {'en': picked},
    );
    expect(settings.hasCustomTranslationColor, isTrue);
    expect(
      settings.translationColorForLang(Brightness.light, 'en'),
      picked.light,
    );
    expect(
      settings.translationColorForLang(Brightness.light, 'my'),
      ColorPair.translationAt(1).light,
    );
  });

  test(
    'picking one language keeps the other, and both survive a restart',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = SettingsNotifier(null)..init(prefs);
      await notifier.setTranslationEnabled('en', true);
      await notifier.setTranslationEnabled('my', true);
      final before = notifier.state.translationColorPairFor('my');

      await notifier.setTranslationColorForLang('en', const Color(0xFF123456));

      expect(
        notifier.state.translationColorPairFor('en').light,
        const Color(0xFF123456),
      );
      expect(notifier.state.translationColorPairFor('my'), before);

      final again = SettingsNotifier(null)..init(prefs);
      expect(
        again.state.translationColorPairFor('en').light,
        const Color(0xFF123456),
      );
      expect(again.state.translationColorPairFor('my'), before);
    },
  );

  testWidgets('the reading-colours screen changes one language at a time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(settingsProvider.notifier)
      ..init(await SharedPreferences.getInstance());
    await notifier.setTranslationEnabled('en', true);
    await notifier.setTranslationEnabled('my', true);

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
          theme: ThemeData.light(),
          home: const ReadingColorsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final myGroup = find.byKey(const ValueKey('translation_colour_my'));
    await tester.scrollUntilVisible(myGroup, 300);
    const picked = Color(0xFF2E7D32);
    final swatch = find.descendant(
      of: myGroup,
      matching: find.byWidgetPredicate(
        (w) => w is ColorSwatch && w.color == picked,
      ),
    );
    await tester.ensureVisible(swatch);
    await tester.tap(swatch);
    await tester.pumpAndSettle();

    final settings = container.read(settingsProvider);
    expect(settings.translationColorPairFor('my').light, picked);
    expect(settings.translationColorPairFor('en'), ColorPair.translationAt(0));
  });

  testWidgets('the reader draws each translation in its own colour', (
    tester,
  ) async {
    const enColor = Color(0xFF4A6FA5);
    const myColor = Color(0xFF3C6E47);
    final paragraph = ParagraphData(
      paraId: 1,
      lines: const [
        LineData(
          lineId: 1,
          paliText: 'dhamma',
          normalizedText: '',
          translations: {'en': 'the teaching', 'my': 'တရား'},
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadingParagraph(
            paragraph: paragraph,
            script: Script.roman,
            pageNumberingSystem: 'vri',
            enabledLangCodes: const ['en', 'my'],
            translationColors: const {'en': enColor, 'my': myColor},
          ),
        ),
      ),
    );

    // Collected straight from the rendered spans, merged down from their
    // ancestors the way Flutter resolves text styles.
    final colors = <Color>{};
    void walk(InlineSpan span, Color? parent) {
      if (span is TextSpan) {
        final color = span.style?.color ?? parent;
        final text = span.text ?? '';
        if (text.contains('teaching') || text.contains('တရား')) {
          colors.add(color!);
        }
        for (final child in span.children ?? const <InlineSpan>[]) {
          walk(child, color);
        }
      }
    }

    for (final w in find.byType(RichText).evaluate()) {
      final rich = w.widget as RichText;
      walk(rich.text, null);
    }

    // No per-language typography in play, so the reader softens the colour
    // slightly.
    expect(
      colors,
      containsAll(<Color>[
        enColor.withValues(alpha: 0.8),
        myColor.withValues(alpha: 0.8),
      ]),
    );
  });
}
