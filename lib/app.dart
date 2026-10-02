import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/utils/app_initializer.dart';
import 'core/utils/app_localizations.dart';
import 'core/utils/keep_awake.dart';
import 'core/utils/l10n/app_strings.dart';
import 'core/providers/dpd_dictionary_provider.dart';
import 'core/providers/settings_provider.dart';
import 'features/indexing/index_controller.dart';
import 'features/reader/providers/tts_reading_provider.dart';
import 'features/settings/providers/translation_download_provider.dart'
    show DownloadStatus, translationDownloadProvider;
import 'features/settings/services/download_notification_service.dart';
import 'features/settings/providers/tts_provider.dart';
import 'features/settings/services/tts_audio_handler.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_typography.dart';
import 'features/annotations/providers/annotations_provider.dart';
import 'features/annotations/widgets/sync_lifecycle_observer.dart';
import 'features/changelog/changelog_service.dart';
import 'features/update/app_update_dialog.dart';
import 'features/update/app_update_service.dart';
import 'features/deep_links/deep_link_service.dart';
import 'features/mcp/widgets/mcp_autostart.dart';
import 'features/indexing/index_gate.dart';
import 'router/app_router.dart';
import 'shared/utils/app_shortcuts.dart';

/// Fallback initializer for the Android audio service behind the lock-screen
/// TTS controls, and lifecycle listener that stops the engines when the app
/// is killed.
///
/// Primary init happens in `main()` before `runApp()` (the `audio_service`
/// README pattern) via [initAudioServiceOnce]; this widget only retries it
/// post-frame when that first attempt failed (some OEMs refuse the
/// foreground service at cold start), and is a no-op otherwise. Going
/// through [initAudioServiceOnce] instead of calling `AudioService.init()`
/// directly is what keeps it init-once per process — a second init
/// re-registers the handler and can make the plugin create its own
/// FlutterEngine (a second Dart isolate sharing one sqflite database).
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
    // Fallback only: main() already initialised the audio service before
    // runApp, in which case this is a no-op. Going through
    // initAudioServiceOnce() instead of calling AudioService.init() directly
    // is what keeps it init-once per process — a second init re-registers the
    // handler and can make the plugin create its own FlutterEngine (see the
    // class doc above), i.e. a second Dart isolate in the same process.
    await initAudioServiceOnce();
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
  bool _updateCheckDone = false;
  bool _backgroundInitDone = false;

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

    // Run background initializations after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initBackground();
    });
  }

  Future<void> _initBackground() async {
    if (_backgroundInitDone) return;
    _backgroundInitDone = true;

    // Supabase must initialize before the sync service / any sign-in
    // attempt. AppInitializer.initBackground is currently never called, so
    // without this the Supabase singleton stays uninitialized and every
    // Google sign-in degrades to "sign-in failed".
    try {
      await AppInitializer.instance.initSupabaseOnce();
    } catch (_) {}

    // Local notifications must initialize before any show() call: on
    // macOS an un-initialized show() crashes the process natively
    // (Swift force-unwrap), past any Dart try/catch. Desktop show()/cancel()
    // are no-ops; mobile needs the init for its progress notifications.
    try {
      await DownloadNotificationService.instance.init();
    } catch (_) {}

    // Initialize sync service (annotation sync)
    try {
      await ref.read(annotationSyncProvider.future);
    } catch (_) {}

    // Warm the DPD dictionary connection (provider caches the DB instance)
    try {
      await ref.read(dpdDictionaryDbProvider.future);
      developer.log('[DICT] DPD warm-up triggered', name: 'epitaka.dict');
    } catch (_) {}
  }

  Future<void> _checkForDesktopUpdate() async {
    if (_updateCheckDone) return;
    _updateCheckDone = true;
    try {
      final dismissed = await _updateService.getDismissedVersion();
      final update = await _updateService.checkForUpdate(
        dismissedVersion: dismissed,
      );
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

    final themePreference = ref.watch(
      settingsProvider.select((s) => s.themePreference),
    );
    final accentColor = ref.watch(
      settingsProvider.select((s) => s.accentColor),
    );
    final appLanguage = ref.watch(
      settingsProvider.select((s) => s.appLanguage),
    );
    final uiFontFamily = ref.watch(
      settingsProvider.select((s) => s.uiFontFamily),
    );
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    // Update the UI font whenever settings change
    AppTypography.setUiFontFamily(uiFontFamily);
    // Build the exact theme the user chose (System resolves against the
    // platform brightness).  The resolved theme is applied as the single
    // active theme so every preference maps to its own color scheme.
    final theme = AppTheme.forPreference(
      themePreference,
      platformBrightness: platformBrightness,
      accentColor: accentColor,
    );

    return SyncLifecycleObserver(
      child: McpAutoStart(
        child: _KeepAwakeBinder(
          child: Consumer(
            builder: (context, ref, _) {
              AppShortcuts.overrides = ref.watch(
                settingsProvider.select((s) => s.shortcutOverrides),
              );
              final app = CallbackShortcuts(
                bindings: AppShortcuts.bindings(_navigatorKey, ref),
                child: MaterialApp.router(
                  title: 'ePitaka',
                  debugShowCheckedModeBanner: false,
                  theme: theme,
                  routerConfig: _router,
                  locale: _resolveLocale(appLanguage),
                  supportedLocales: AppLocalizationsDelegate.supportedLocales,
                  localizationsDelegates: [
                    const AppLocalizationsDelegate(),
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  builder: (context, child) => IndexGate(
                    child: PendingDeepLinkRunner(child: child!),
                  ),
                ),
              );

              return AppShortcuts.menuBar(
                navigatorKey: _navigatorKey,
                ref: ref,
                child: app,
              );
            },
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
