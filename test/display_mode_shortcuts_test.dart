/// The four Ctrl+Alt+digit display shortcuts match the Display popup: each one
/// sets both "show Pāli" and "show translation", so a key press can leave
/// "Translation Only" again.
library;

import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/shared/utils/app_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => AppShortcuts.overrides = const {});
  tearDown(() => AppShortcuts.overrides = const {});

  testWidgets('Ctrl+Alt+4 shows only the translation, 1/2/3 bring Pāli back', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    late ProviderContainer c;
    late Map<ShortcutActivator, VoidCallback> bindings;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            c = ProviderScope.containerOf(context);
            bindings = AppShortcuts.bindings(GlobalKey<NavigatorState>(), ref);
            return const SizedBox();
          },
        ),
      ),
    );

    void press(LogicalKeyboardKey digit) {
      bindings.entries
          .firstWhere(
            (e) =>
                e.key is SingleActivator &&
                (e.key as SingleActivator).trigger == digit &&
                (e.key as SingleActivator).control &&
                (e.key as SingleActivator).alt,
          )
          .value();
    }

    AppSettings s() => c.read(settingsProvider);

    press(LogicalKeyboardKey.digit4);
    expect(s().showPali, isFalse);
    expect(s().showTranslation, isTrue);

    press(LogicalKeyboardKey.digit2);
    expect(s().showPali, isTrue);
    expect(s().showTranslation, isTrue);
    expect(s().translationDisplayMode, TranslationDisplayMode.lineByLine);

    press(LogicalKeyboardKey.digit4);
    press(LogicalKeyboardKey.digit3);
    expect(s().showPali, isTrue);
    expect(s().translationDisplayMode, TranslationDisplayMode.sideBySide);

    press(LogicalKeyboardKey.digit4);
    press(LogicalKeyboardKey.digit1);
    expect(s().showPali, isTrue);
    expect(s().showTranslation, isFalse);
  });
}
