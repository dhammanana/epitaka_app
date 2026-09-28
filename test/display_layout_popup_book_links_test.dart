/// Verifies the "Show Inline Commentaries" checkbox in the reader's display layout
/// popup toggles the setting (temporarily, without persisting) and that the
/// checkbox reflects the current setting value. Also covers the "Only
/// translation" layout option and the downloaded-translations toggles added
/// to the same popup.
library;

import 'package:epitaka/core/models/translation_version.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/providers/translation_manifest_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/reader/widgets/display_layout_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overrides shared by every test so the popup's downloaded-translations
/// section is deterministic. The real provider scans the host's database
/// directory, which would both hang the test's pumpAndSettle (loading
/// spinner) and add unexpected checkboxes.
List<Override> baseOverrides({List<TranslationVersion> versions = const []}) =>
    [localTranslationVersionsProvider.overrideWith((ref) async => versions)];

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TranslationLanguageRegistry.registerFromManifest(
      TranslationManifest.fromString('''{
        "version": 1,
        "languages": {
          "en": {"englishName": "English", "nativeName": "English", "versions": {}},
          "my": {"englishName": "Myanmar", "nativeName": "မြန်မာ", "versions": {}},
          "my_nissaya": {"englishName": "Myanmar Nissaya", "nativeName": "မြန်မာနိဿယ", "versions": {}},
          "th": {"englishName": "Thai", "nativeName": "ไทย", "versions": {}}
        }
      }'''),
    );
  });

  Widget wrap(Widget child) => ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) {
        final notifier = SettingsNotifier(null);
        notifier.state = const AppSettings();
        return notifier;
      }),
      ...baseOverrides(),
    ],
    child: MaterialApp(
      supportedLocales: AppLocalizationsDelegate.supportedLocales,
      localizationsDelegates: const [AppLocalizationsDelegate()],
      // The default Material 3 ink-sparkle splash tries to load the
      // 'shaders/ink_sparkle.frag' asset on tap, which doesn't exist in
      // the test environment. The classic ripple needs no shader asset.
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: InkSplash.splashFactory,
      ),
      home: Scaffold(body: child),
    ),
  );

  testWidgets('popup checkbox reflects and toggles showBookLinks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(wrap(const DisplayLayoutPopup()));
    await tester.pumpAndSettle();

    final checkbox = find.byType(Checkbox);
    expect(checkbox, findsOneWidget);
    // Default AppSettings has showBookLinks = true.
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);

    // Tap the row to hide book links.
    await tester.tap(find.text('Show Inline Commentaries'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(checkbox).value, isFalse);

    // Tap again to re-enable.
    await tester.tap(find.text('Show Inline Commentaries'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
  });

  testWidgets('popup toggle is temporary — the saved preference is untouched', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    // Seed a persisted 'show_book_links' preference.
    SharedPreferences.setMockInitialValues({'show_book_links': true});
    final prefs = await SharedPreferences.getInstance();
    final notifier = SettingsNotifier(prefs)..init(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => notifier),
          ...baseOverrides(),
        ],
        child: MaterialApp(
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [AppLocalizationsDelegate()],
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkSplash.splashFactory,
          ),
          home: const Scaffold(body: DisplayLayoutPopup()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Toggle OFF in the popup: the in-memory state flips…
    await tester.tap(find.text('Show Inline Commentaries'));
    await tester.pumpAndSettle();
    expect(notifier.state.showBookLinks, isFalse);

    // …but the persisted preference is NOT written (session-only).
    expect(prefs.getBool('show_book_links'), isTrue);
  });

  testWidgets(
    'popup tap-to-translate row offers Disabled/Single/Double and persists the gesture',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      // Seed a persisted 'word_lookup_gesture' preference (1 = single tap).
      SharedPreferences.setMockInitialValues({'word_lookup_gesture': 1});
      final prefs = await SharedPreferences.getInstance();
      final notifier = SettingsNotifier(prefs)..init(prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => notifier),
            ...baseOverrides(),
          ],
          child: MaterialApp(
            supportedLocales: AppLocalizationsDelegate.supportedLocales,
            localizationsDelegates: const [AppLocalizationsDelegate()],
            theme: ThemeData(
              useMaterial3: true,
              splashFactory: InkSplash.splashFactory,
            ),
            home: const Scaffold(body: DisplayLayoutPopup()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The row shows the current gesture.
      expect(find.text('Tap to translate'), findsOneWidget);
      expect(notifier.state.wordLookupGesture, WordLookupGesture.singleTap);

      // Tapping it opens a menu with all three options.
      await tester.tap(find.text('Tap to translate'));
      await tester.pumpAndSettle();
      expect(find.text('Disabled'), findsOneWidget);
      expect(find.text('Double tap'), findsOneWidget);
      // Row value + menu item.
      expect(find.text('Single tap'), findsNWidgets(2));

      // Selecting "Disabled" updates the setting…
      await tester.tap(find.text('Disabled'));
      await tester.pumpAndSettle();
      expect(notifier.state.wordLookupGesture, WordLookupGesture.disabled);
      // …and persists it.
      expect(
        prefs.getInt('word_lookup_gesture'),
        WordLookupGesture.disabled.index,
      );
    },
  );

  testWidgets('popup "Only translation" hides Pāli but keeps the translation', (
    tester,
  ) async {
    final notifier = SettingsNotifier(null);
    notifier.state = const AppSettings();

    // Open the popup the way the reader does: anchored in a dialog so the
    // layout choice can pop it.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => notifier),
          ...baseOverrides(),
        ],
        child: MaterialApp(
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [AppLocalizationsDelegate()],
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkSplash.splashFactory,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    barrierColor: Colors.transparent,
                    builder: (_) => const Align(
                      alignment: Alignment(0, 0.88),
                      child: DisplayLayoutPopup(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The layout modes are icon segments; "Only translation" is the
    // article icon.
    await tester.tap(find.byIcon(Icons.article_outlined));
    await tester.pumpAndSettle();

    expect(notifier.state.showPali, isFalse);
    expect(notifier.state.showTranslation, isTrue);
    // Choosing a layout closes the popup.
    expect(find.byType(DisplayLayoutPopup), findsNothing);
  });

  testWidgets('popup lists downloaded translations and toggles them', (
    tester,
  ) async {
    final notifier = SettingsNotifier(null);
    notifier.state = const AppSettings();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => notifier),
          ...baseOverrides(
            versions: const [
              TranslationVersion(
                languageCode: 'en',
                filename: 'epitaka_en.db',
                isAvailable: true,
                displayName: 'Default',
              ),
              TranslationVersion(
                languageCode: 'my',
                filename: 'epitaka_my.db',
                isAvailable: true,
                displayName: 'Default',
              ),
            ],
          ),
        ],
        child: MaterialApp(
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [AppLocalizationsDelegate()],
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkSplash.splashFactory,
          ),
          home: const Scaffold(body: DisplayLayoutPopup()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Book-links checkbox + one per downloaded translation.
    expect(find.byType(Checkbox), findsNWidgets(3));

    // Toggling a row enables that language immediately and does not close the popup.
    await tester.tap(find.textContaining('Myanmar'));
    await tester.pumpAndSettle();
    expect(notifier.state.enabledTranslations, contains('my'));
    expect(find.byType(DisplayLayoutPopup), findsOneWidget);

    // Toggling off removes it again.
    await tester.tap(find.textContaining('Myanmar'));
    await tester.pumpAndSettle();
    expect(notifier.state.enabledTranslations, isNot(contains('my')));
  });

  testWidgets('displays both Myanmar and Myanmar Nissaya as toggleable rows', (
    tester,
  ) async {
    final notifier = SettingsNotifier(null);
    notifier.state = const AppSettings(
      showBookLinks: true,
      showTranslation: true,
      enabledTranslations: ['my', 'my_nissaya'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => notifier),
          ...baseOverrides(
            versions: const [
              TranslationVersion(
                languageCode: 'my',
                filename: 'epitaka_my.db',
                isAvailable: true,
                displayName: 'Default',
              ),
              TranslationVersion(
                languageCode: 'my_nissaya',
                filename: 'epitaka_my_nissaya.db',
                isNissaya: true,
                isAvailable: true,
                displayName: 'Default',
              ),
            ],
          ),
        ],
        child: MaterialApp(
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [AppLocalizationsDelegate()],
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkSplash.splashFactory,
          ),
          home: const Scaffold(body: DisplayLayoutPopup()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Checkboxes: 1 for Book links, 1 for Myanmar, 1 for Myanmar Nissaya = 3
    expect(find.byType(Checkbox), findsNWidgets(3));
    expect(find.text('Myanmar · မြန်မာ'), findsOneWidget);
    expect(find.text('Myanmar Nissaya · မြန်မာနိဿယ'), findsOneWidget);

    expect(notifier.state.enabledTranslations, contains('my'));
    expect(notifier.state.enabledTranslations, contains('my_nissaya'));
  });

  testWidgets('popup lets you drag an enabled translation to reorder it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final notifier = SettingsNotifier(null);
    notifier.state = const AppSettings(
      showBookLinks: true,
      enabledTranslations: ['en', 'my'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => notifier),
          ...baseOverrides(
            versions: const [
              TranslationVersion(
                languageCode: 'en',
                filename: 'epitaka_en.db',
                isAvailable: true,
                displayName: 'Default',
              ),
              TranslationVersion(
                languageCode: 'my',
                filename: 'epitaka_my.db',
                isAvailable: true,
                displayName: 'Default',
              ),
            ],
          ),
        ],
        child: MaterialApp(
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [AppLocalizationsDelegate()],
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkSplash.splashFactory,
          ),
          home: const Scaffold(body: DisplayLayoutPopup()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Both rows are enabled, so both show a drag handle.
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));

    // Drag the second row ('my') up above the first ('en').
    await tester.timedDrag(
      find.byIcon(Icons.drag_indicator).at(1),
      const Offset(0, -80),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    // The new order is persisted to the shared enabledTranslations list,
    // which is the same list the Settings screen reorders.
    expect(notifier.state.enabledTranslations, ['my', 'en']);
  });
}
