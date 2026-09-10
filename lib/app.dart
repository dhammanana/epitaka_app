import 'dart:async';
import 'dart:developer' as developer;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/utils/app_localizations.dart';
import 'core/utils/keep_awake.dart';
import 'core/utils/l10n/app_strings.dart';
import 'core/providers/dpd_dictionary_provider.dart';
import 'core/providers/settings_provider.dart';
import 'features/indexing/index_controller.dart';
import 'features/reader/providers/tts_reading_provider.dart';
import 'features/settings/providers/translation_download_provider.dart';
import 'features/settings/providers/tts_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_typography.dart';
import 'features/annotations/widgets/sync_lifecycle_observer.dart';
import 'features/changelog/changelog_service.dart';
import 'features/update/app_update_dialog.dart';
import 'features/update/app_update_service.dart';
import 'features/deep_links/deep_link_service.dart';
import 'features/mcp/widgets/mcp_autostart.dart';
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
class AudioServiceInitializer extends ConsumerStatefulWidget {
  final Widget child;
  const AudioServiceInitializer({super.key, required this.child});

  @override
  ConsumerState<AudioServiceInitializer> createState() =>
      _AudioServiceInitializerState();
}

class _AudioServiceInitializerState
    extends ConsumerState<AudioServiceInitializer>
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
    developer.log(
      '[TTS_LIFECYCLE] AudioServiceInitializer.dispose() called',
      name: 'epitaka.tts',
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    developer.log('[TTS_LIFECYCLE] App lifecycle: $state', name: 'epitaka.tts');
    // `paused`/`inactive` (Home, screen off) intentionally do nothing here:
    // background playback must continue via the foreground service.
    //
    // `detached` means the engine is being torn down (swipe-kill). The
    // native TTS engine would otherwise finish the queued utterance with
    // no UI left — so emergency-stop the engines and dismiss the
    // notification. The audio service itself is init-once per process and
    // is never `stop()`-ed here, so the next launch can reuse it.
    if (state == AppLifecycleState.detached) {
      try {
        ref.read(ttsReadingProvider.notifier).handleAppDetached();
      } catch (_) {}
      try {
        ref.read(ttsProvider.notifier).emergencyStop();
      } catch (_) {}
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
  final _updateService = AppUpdateService();

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
      // Initialize the UI font from persisted settings
      final settings = ref.read(settingsProvider);
      AppTypography.setUiFontFamily(settings.uiFontFamily);
    });

    // Warm the DPD dictionary connection shortly after startup. Opening
    // dpd-dictionary.db takes ~100+ ms of synchronous sqlite work on first
    // use; doing it while the app idles means the first double-tap lookup
    // (reader, book-link sheet, …) only pays the query itself instead of
    // open + query. The handle is cached by [dpdDictionaryDbProvider].
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 2), _warmUpDictionary);
    });
  }

  void _warmUpDictionary() {
    if (!mounted) return;
    // Ignore errors: if the DB is missing/not yet downloaded, the lazy open
    // path on first lookup reports the same error as before.
    ref.read(dpdDictionaryDbProvider.future).ignore();
    developer.log('[DICT] DPD warm-up triggered', name: 'epitaka.dict');
  }

  Future<void> _checkForDesktopUpdate() async {
    try {
      final update = await _updateService.checkForUpdate();
      if (!mounted || update == null) return;
      final context = _navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      await AppUpdateDialog.show(context, update, _updateService);
    } catch (error, stackTrace) {
      developer.log(
        'Desktop update check failed: $error',
        name: 'epitaka.update',
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void dispose() {
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  /// Map [AppLanguage] to a Flutter [Locale]. Registry-driven: any
  /// language in `AppStrings.supportedCodes` resolves to its locale code.
  Locale _resolveLocale(AppLanguage lang) {
    if (AppStrings.supportedCodes.contains(lang.code)) {
      return Locale(lang.code);
    }
    return const Locale('en');
  }

  @override
  Widget build(BuildContext context) {
    // Initialise deep link handling (epitaka:// custom scheme) after the
    // first frame so the GoRouter is already attached to the navigator key.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.instance.init(_navigatorKey);
    });

    // After the first frame, show the "What's New" dialog when a freshly
    // installed build differs from the last-seen one. Runs on the navigator
    // key so the dialog appears above whatever screen the user lands on.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ChangelogService.showIfNewBuild(_navigatorKey);
      _checkForDesktopUpdate();
    });

    final settings = ref.watch(settingsProvider);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    // Update the UI font whenever settings change
    AppTypography.setUiFontFamily(settings.uiFontFamily);
    // Build the exact theme the user chose (System resolves against the
    // platform brightness).  The resolved theme is applied as the single
    // active theme so every preference maps to its own color scheme.
    final theme = AppTheme.forPreference(
      settings.themePreference,
      platformBrightness: platformBrightness,
      accentColor: settings.accentColor,
    );

    return SyncLifecycleObserver(
      child: McpAutoStart(
        child: AudioServiceInitializer(
          child: _KeepAwakeBinder(
            child: Consumer(
              builder: (context, ref, _) {
                final app = CallbackShortcuts(
                  bindings: AppShortcuts.bindings(_navigatorKey, ref),
                  child: MaterialApp.router(
                    title: 'ePitaka',
                    debugShowCheckedModeBanner: false,
                    // The resolved theme is set as the app theme; when no
                    // darkTheme is provided MaterialApp falls back to [theme] in
                    // every brightness, so the chosen scheme is always applied.
                    theme: theme,
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
          ),
        ),
      ),
    );
  }
}

/// Keeps the screen awake while long work runs.
///
/// Watches the global reading setting, any active translation/core download,
/// the index build, and the setup wizard's manual switch, then applies the
/// OR-ed result through [KeepAwake]. Placed above [MaterialApp] so it is
/// always mounted, whichever screen the user is on.
class _KeepAwakeBinder extends ConsumerWidget {
  final Widget child;

  const _KeepAwakeBinder({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final global = ref.watch(settingsProvider.select((s) => s.keepScreenOn));
    final downloads = ref.watch(translationDownloadProvider);
    final building = ref.watch(
      indexControllerProvider.select((s) => s.isBuilding),
    );
    final override = ref.watch(keepAwakeOverrideProvider);
    final busy =
        building ||
        downloads.values.any(
          (d) =>
              d.status == DownloadStatus.downloading ||
              d.status == DownloadStatus.extracting,
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      KeepAwake.apply(global: global, busy: busy, override: override);
    });
    return child;
  }
}
