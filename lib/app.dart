import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers/settings_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/indexing/index_gate.dart';
import 'router/app_router.dart';

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

    return MaterialApp.router(
      title: 'ePitaka',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
      builder: (context, child) => IndexGate(child: child!),
    );
  }
}
