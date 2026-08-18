/// Verifies the TTS controls dialog never exceeds the fixed card width on a
/// wide (desktop) screen — even when a long Sinhala-fallback notice is shown,
/// which used to stretch the dialog to near full-screen width.
library;

import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/reader/widgets/reader_tts_controls_dialog.dart';
import 'package:epitaka/features/reader/widgets/reader_tts_widgets.dart';
import 'package:epitaka/features/settings/providers/tts_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'TTS controls dialog stays at card width on a wide screen '
    'even with a long fallback notice',
    (tester) async {
      // Wide desktop-like surface.
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsNotifier = SettingsNotifier(prefs)..init(prefs);

      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => settingsNotifier),
          ttsProvider.overrideWith((ref) => TtsNotifier(ref)),
        ],
      );
      addTearDown(container.dispose);

      // A long Sinhala-fallback notice is what used to stretch the dialog
      // to near full-screen width on desktop.
      container.read(ttsProvider.notifier).paliFallbackNotice =
          'Pāli will be read in the Latin script because no Sinhala voice '
          'is installed on this device. Install a Sinhala voice in the '
          'system text-to-speech settings to hear Pāli in Sinhala script.';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            supportedLocales: AppLocalizationsDelegate.supportedLocales,
            localizationsDelegates: const [AppLocalizationsDelegate()],
            theme: ThemeData(
              useMaterial3: true,
              splashFactory: InkSplash.splashFactory,
            ),
            home: Builder(
              builder: (context) {
                // Open the dialog as soon as the frame is up.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showTtsControlsDialog(
                    context,
                    bookId: 'dn1',
                    isTtsLineVisible: true,
                    onFollowTts: () {},
                    onSpeakModeChanged: (_) {},
                  );
                });
                return const Scaffold(body: SizedBox());
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The fallback notice is actually shown…
      expect(find.textContaining('Sinhala voice'), findsOneWidget);
      // …and the dialog (notice + card) never exceeds the card width.
      expect(
        tester.getSize(find.byType(TtsControlsCard)).width,
        lessThanOrEqualTo(kTtsControlsCardWidth),
      );
    },
  );
}
