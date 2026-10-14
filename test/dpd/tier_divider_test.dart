/// The "Partial Results" and "Fuzzy Results" headings use the dictionary's
/// font and size, like the cards around them.
library;

import 'package:epitaka/core/theme/app_theme.dart';
import 'package:epitaka/core/providers/settings_provider.dart'
    show ThemePreference;
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/dictionary/providers/dictionary_font_scale_provider.dart';
import 'package:epitaka/features/dpd/widgets/tier_divider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> pump(WidgetTester tester, ResultTier tier) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.forPreference(
            ThemePreference.light,
            platformBrightness: Brightness.light,
          ),
          locale: const Locale('en'),
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [AppLocalizationsDelegate()],
          home: Scaffold(body: TierDivider(tier: tier)),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  TextStyle? headingStyle(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style;

  testWidgets('the heading uses the dictionary font and size', (tester) async {
    final c = await pump(tester, ResultTier.fuzzy);
    final pali = c.read(dictionaryPaliProvider);
    final style = headingStyle(tester, 'Fuzzy Results')!;
    expect(style.fontFamily, pali.fontFamily.fontFamily);
    expect(style.fontSize, pali.fontSize * 0.8);
  });

  testWidgets('the heading follows the dictionary text size', (tester) async {
    final c = await pump(tester, ResultTier.partial);
    final before = headingStyle(tester, 'Partial Results')!.fontSize!;
    await c.read(dictionaryFontScaleProvider.notifier).setScale(1.2);
    await tester.pump();
    final after = headingStyle(tester, 'Partial Results')!.fontSize!;
    expect(after, closeTo(before * 1.2, 1e-6));
  });
}
