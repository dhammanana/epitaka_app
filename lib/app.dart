import 'dart:async';
import 'dart:developer' as developer;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/utils/app_localizations.dart';
import 'core/providers/settings_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/deep_links/deep_link_service.dart';
import 'features/indexing/index_gate.dart';
import 'features/settings/services/tts_audio_handler.dart';
import 'router/app_router.dart';
import 'shared/utils/app_shortcuts.dart';

/// Initializes the Android audio service for lock-screen TTS controls
/// and listens for app lifecycle changes to properly stop the foreground
/// service when the app is killed.
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

class _AudioServiceInitializerState extends State<AudioServiceInitializer>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the app is fully killed (swiped from recents), stop the
    // Android foreground service so the process can terminate cleanly.
    // Without this, the AudioService keeps the process alive even after
    // the user explicitly kills the app, preventing a fresh start on
    // next launch.
    if (state == AppLifecycleState.detached) {
      developer.log(
        '[AUDIO_SVC] App detached → stopping AudioService',
        name: 'epitaka.tts',
      );
      try {
        AudioService.stop();
      } catch (_) {
        // Service may already be stopped — ignore.
      }
    }
  }

  Future<void> _init() async {
    if (!mounted) return;
    try {
      await AudioService.init(
        builder: () => ttsAudioHandler,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.dn.epitaka.tts',
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

  /// Passed to GoRouter (see `buildRouter`) so AppShortcuts can resolve a
  /// BuildContext that's under MaterialApp/GoRouter at invocation time —
  /// the context available where CallbackShortcuts/PlatformMenuBar are
  /// wired up (above MaterialApp.router) is not, and using it directly
  /// causes "No MaterialLocalizations found" / broken context.go/push.
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // NOTE: buildRouter must be updated to accept and forward this key to
    // its GoRouter(...) constructor, e.g.:
    //   GoRouter buildRouter({GlobalKey<NavigatorState>? navigatorKey}) {
    //     return GoRouter(navigatorKey: navigatorKey, ...);
    //   }
    _router = buildRouter(navigatorKey: _navigatorKey);

    // Initialize settings from SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      ref.read(settingsProvider.notifier).init(prefs);
    });
  }

  @override
  void dispose() {
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  /// Map [AppLanguage] to a Flutter [Locale].
  Locale _resolveLocale(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.vietnamese:
        return const Locale('vi', 'VN');
      default:
        return const Locale('en', 'US');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialise deep link handling (epitaka:// custom scheme) after the
    // first frame so the GoRouter is already attached to the navigator key.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.instance.init(_navigatorKey);
    });

    final settings = ref.watch(settingsProvider);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final isDark = settings.resolveDarkMode(platformBrightness);

    return AudioServiceInitializer(
      child: Consumer(
        builder: (context, ref, _) {
          final app = CallbackShortcuts(
            bindings: AppShortcuts.bindings(_navigatorKey, ref),
            child: MaterialApp.router(
              title: 'ePitaka',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(accentColor: settings.accentColor),
              darkTheme: AppTheme.dark(accentColor: settings.accentColor),
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              routerConfig: _router,
              locale: _resolveLocale(settings.appLanguage),
              supportedLocales: AppLocalizationsDelegate.supportedLocales,
              localizationsDelegates: [
                const AppLocalizationsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => IndexGate(child: child!),
            ),
          );

          // On macOS, wraps `app` in a native PlatformMenuBar so shortcuts
          // are listed in the system menu bar and macOS's own default
          // Cmd+F ("Find…") no longer swallows ours before CallbackShortcuts
          // sees it. On other platforms this is a no-op passthrough.
          return AppShortcuts.menuBar(
            navigatorKey: _navigatorKey,
            ref: ref,
            child: app,
          );
        },
      ),
    );
  }
}
