import 'dart:async';
import 'dart:developer' as developer;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers/settings_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/indexing/index_gate.dart';
import 'features/settings/services/tts_audio_handler.dart';
import 'router/app_router.dart';

/// Initializes the Android audio service for lock-screen TTS controls.
///
/// Must be called AFTER [runApp] so the main FlutterEngine is already
/// running. When called before [runApp], `audio_service` creates its own
/// background FlutterEngine, which later differs from the main engine
/// created by [runApp], causing an `IllegalStateException`:
///
/// ```
/// The Activity class declared in your AndroidManifest.xml is wrong or
/// has not provided the correct FlutterEngine.
/// ```
///
/// This widget defers initialization to a post-frame callback from
/// [initState], guaranteeing the engine is fully initialized.
class AudioServiceInitializer extends StatefulWidget {
  final Widget child;
  const AudioServiceInitializer({super.key, required this.child});

  @override
  State<AudioServiceInitializer> createState() =>
      _AudioServiceInitializerState();
}

class _AudioServiceInitializerState extends State<AudioServiceInitializer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (!mounted) return;
    try {
      await AudioService.init(
        builder: () => ttsAudioHandler,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.epitaka.epitaka_app.tts',
          androidNotificationChannelName: 'TTS Playback',
          androidStopForegroundOnPause: false,
          androidNotificationIcon: 'mipmap/ic_launcher',
        ),
      );
      developer.log(
        '[AUDIO_SVC] AudioService.init() succeeded',
        name: 'epitaka.tts',
      );
    } catch (e) {
      developer.log(
        '[AUDIO_SVC] AudioService.init() failed: $e',
        name: 'epitaka.tts',
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class EpitakaApp extends ConsumerStatefulWidget {
  const EpitakaApp({super.key});

  @override
  ConsumerState<EpitakaApp> createState() => _EpitakaAppState();
}

class _EpitakaAppState extends ConsumerState<EpitakaApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter();

    // Initialize settings from SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      ref.read(settingsProvider.notifier).init(prefs);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final isDark = settings.resolveDarkMode(platformBrightness);

    return AudioServiceInitializer(
      child: MaterialApp.router(
        title: 'ePitaka',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(accentColor: settings.accentColor),
        darkTheme: AppTheme.dark(accentColor: settings.accentColor),
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: _router,
        builder: (context, child) => IndexGate(child: child!),
      ),
    );
  }
}
