import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/features/reader/providers/display_mode_override.dart';

const _side = TranslationDisplayMode.sideBySide;
const _line = TranslationDisplayMode.lineByLine;
const _hide = TranslationDisplayMode.hideJoinLines;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late ProviderContainer container;

  Future<void> start(TranslationDisplayMode saved) async {
    SharedPreferences.setMockInitialValues({
      'translation_display_mode': saved.name,
    });
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) {
          final notifier = SettingsNotifier(prefs);
          notifier.init(prefs);
          return notifier;
        }),
      ],
    );
    addTearDown(container.dispose);
  }

  TranslationDisplayMode mode() =>
      container.read(settingsProvider).translationDisplayMode;
  DisplayModeOverride owner() => container.read(displayModeOverrideProvider);
  void pick(TranslationDisplayMode m) => container
      .read(settingsProvider.notifier)
      .setTranslationDisplayModeTemporary(m);

  test('side-by-side becomes line-by-line while columns show', () async {
    await start(_side);
    expect(mode(), _side);
    owner().add(DisplayModeReason.columns);
    expect(mode(), _line);
    owner().remove(DisplayModeReason.columns);
    expect(mode(), _side);
  });

  test('columns leave line-by-line and hide-join-lines alone', () async {
    await start(_hide);
    owner().add(DisplayModeReason.columns);
    expect(mode(), _hide);
    owner().remove(DisplayModeReason.columns);
    expect(mode(), _hide);

    pick(_line);
    owner().add(DisplayModeReason.columns);
    owner().remove(DisplayModeReason.columns);
    expect(mode(), _line);
  });

  test('a mode picked by hand while columns show is kept', () async {
    await start(_side);
    owner().add(DisplayModeReason.columns);
    pick(_hide);
    owner().remove(DisplayModeReason.columns);
    expect(mode(), _hide);
  });

  test('read-aloud stopping while columns show keeps line-by-line', () async {
    await start(_side);
    owner().add(DisplayModeReason.columns);
    owner().add(DisplayModeReason.tts);
    owner().remove(DisplayModeReason.tts);
    expect(mode(), _line);
    owner().remove(DisplayModeReason.columns);
    expect(mode(), _side);
  });

  test('columns closing while read-aloud plays keeps line-by-line', () async {
    await start(_side);
    owner().add(DisplayModeReason.tts);
    owner().add(DisplayModeReason.columns);
    owner().remove(DisplayModeReason.columns);
    expect(mode(), _line);
    owner().remove(DisplayModeReason.tts);
    expect(mode(), _side);
  });

  test(
    'hide-join-lines comes back when read-aloud stops beside columns',
    () async {
      // Columns do not need line-by-line for hide-join-lines; read-aloud does.
      await start(_hide);
      owner().add(DisplayModeReason.tts);
      owner().add(DisplayModeReason.columns);
      expect(mode(), _line);
      owner().remove(DisplayModeReason.tts);
      expect(mode(), _hide);
      owner().remove(DisplayModeReason.columns);
      expect(mode(), _hide);
    },
  );

  test('a mode picked by hand before read-aloud is the one restored', () async {
    await start(_side);
    owner().add(DisplayModeReason.columns);
    pick(_hide);
    owner().add(DisplayModeReason.tts);
    expect(mode(), _line);
    owner().remove(DisplayModeReason.tts);
    expect(mode(), _hide);
    owner().remove(DisplayModeReason.columns);
    expect(mode(), _hide);
  });

  test('the saved setting is never written', () async {
    await start(_side);
    owner().add(DisplayModeReason.columns);
    owner().add(DisplayModeReason.tts);
    owner().remove(DisplayModeReason.columns);
    owner().remove(DisplayModeReason.tts);
    owner().add(DisplayModeReason.columns);
    expect(prefs.getString('translation_display_mode'), _side.name);
  });
}
