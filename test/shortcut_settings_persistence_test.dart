import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:epitaka/core/providers/settings_provider.dart';

const _ctrlShiftK = SingleActivator(
  LogicalKeyboardKey.keyK,
  control: true,
  shift: true,
);

Future<SettingsNotifier> _freshNotifier() async {
  final prefs = await SharedPreferences.getInstance();
  final notifier = SettingsNotifier(prefs);
  notifier.init(prefs);
  return notifier;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a saved shortcut is there after a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await _freshNotifier();
    expect(first.state.shortcutOverrides, isEmpty);
    await first.setShortcutOverride('dictionary', _ctrlShiftK);

    final second = await _freshNotifier();
    final loaded = second.state.shortcutOverrides['dictionary'];
    expect(loaded?.trigger, LogicalKeyboardKey.keyK);
    expect(loaded?.control, isTrue);
    expect(loaded?.shift, isTrue);
    expect(loaded?.meta, isFalse);
  });

  test('a shortcut left with no keys stays that way after a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await _freshNotifier();
    await first.setShortcutOverride('find-in-book', null);

    final second = await _freshNotifier();
    expect(second.state.shortcutOverrides.containsKey('find-in-book'), isTrue);
    expect(second.state.shortcutOverrides['find-in-book'], isNull);
  });

  test('clearing one shortcut keeps the others', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await _freshNotifier();
    await notifier.setShortcutOverride('dictionary', _ctrlShiftK);
    await notifier.setShortcutOverride(
      'search-next',
      const SingleActivator(LogicalKeyboardKey.keyN),
    );
    await notifier.clearShortcutOverride('dictionary');

    final restarted = await _freshNotifier();
    expect(restarted.state.shortcutOverrides.keys, ['search-next']);
  });

  test('reset removes the stored preference', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await _freshNotifier();
    await notifier.setShortcutOverride('dictionary', _ctrlShiftK);
    await notifier.resetShortcutOverrides();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('shortcut_overrides'), isFalse);
    expect(notifier.state.shortcutOverrides, isEmpty);
  });

  test('a corrupt stored value loads as no overrides', () async {
    SharedPreferences.setMockInitialValues({'shortcut_overrides': '{oops'});
    final notifier = await _freshNotifier();
    expect(notifier.state.shortcutOverrides, isEmpty);
  });
}
