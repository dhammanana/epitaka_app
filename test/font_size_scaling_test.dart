/// The global font-size controls (reader display popup, search screen "A"
/// button, Ctrl/Cmd +/- shortcuts) must scale the Pāli size AND every
/// visible translation together.
///
/// Previously `_adjustFontSize` only scaled languages that already had a
/// per-language override, so translations without one fell back to the fixed
/// 17px default and never changed.
library;

import 'package:flutter_test/flutter_test.dart';

import '../lib/core/providers/settings_provider.dart';

void main() {
  SettingsNotifier notifierWith({
    List<String> enabledTranslations = const [],
    bool showTranslation = true,
  }) {
    return SettingsNotifier(null)
      ..state = AppSettings(
        enabledTranslations: enabledTranslations,
        showTranslation: showTranslation,
      );
  }

  group('increaseFontSize / decreaseFontSize', () {
    test('scales Pāli and every enabled translation together', () async {
      final n = notifierWith(enabledTranslations: ['en', 'th']);
      await n.increaseFontSize();

      expect(n.state.typography.pali.fontSize, 20); // 19 + 1
      expect(n.state.typography.typographyFor('en').fontSize, 18); // 17 + 1
      expect(n.state.typography.typographyFor('th').fontSize, 18);
      // A language that is neither enabled nor customized stays at default.
      expect(n.state.typography.typographyFor('si').fontSize, 17);
    });

    test('translations keep compounding on subsequent adjustments', () async {
      final n = notifierWith(enabledTranslations: ['en']);
      await n.increaseFontSize();
      await n.increaseFontSize();
      await n.increaseFontSize();

      expect(n.state.typography.pali.fontSize, 22);
      expect(n.state.typography.typographyFor('en').fontSize, 20);
    });

    test('decreaseFontSize scales translations too', () async {
      final n = notifierWith(enabledTranslations: ['en']);
      await n.decreaseFontSize();

      expect(n.state.typography.pali.fontSize, 18);
      expect(n.state.typography.typographyFor('en').fontSize, 16);
    });

    test('scales the primary language when none are enabled', () async {
      final n = notifierWith(showTranslation: true); // primary is 'en'
      await n.increaseFontSize();

      expect(n.state.typography.typographyFor('en').fontSize, 18);
    });

    test('does not touch translations when translations are hidden', () async {
      final n = notifierWith(showTranslation: false);
      await n.increaseFontSize();

      expect(n.state.typography.pali.fontSize, 20);
      expect(n.state.typography.languageOverrides, isEmpty);
    });

    test('custom per-language sizes scale proportionally', () async {
      final n = SettingsNotifier(null)
        ..state = AppSettings(
          enabledTranslations: const ['en'],
          typography: const TypographySettings(
            languageOverrides: {
              'en': LanguageTypography(fontSize: 20),
            },
          ),
        );
      await n.increaseFontSize();

      expect(n.state.typography.typographyFor('en').fontSize, 21);
    });
  });
}
