/// A small app with the real link service, the real "Go to sutta" box and the
/// real lookup provider, over an in-memory database that holds rows copied
/// from the real `headings` and `books` tables (epitaka.db).
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/features/sutta_jump/providers/sutta_lookup_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/theme/app_theme.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/deep_links/deep_link_service.dart';
import 'package:epitaka/router/app_router.dart';

Future<EpitakaDatabase> seedSuttaLinkDb() async {
  final db = EpitakaDatabase(NativeDatabase.memory());
  await db.customStatement(
    'CREATE TABLE books (id INTEGER PRIMARY KEY, ref_id INTEGER, vri_id TEXT, '
    'book_id TEXT NOT NULL UNIQUE, category TEXT, nikaya TEXT, '
    'sub_nikaya TEXT, book_name TEXT, description TEXT, mula_ref TEXT, '
    'attha_ref TEXT, tika_ref TEXT, para_id INTEGER, chapter_len INTEGER)',
  );
  await db.customStatement(
    'CREATE TABLE headings (book_id TEXT, para_id INT, level INT, '
    'title TEXT, chapter_len INT, parent INT, sc_id TEXT)',
  );
  await db.customStatement(
    "INSERT INTO books(book_id, book_name) VALUES "
    "('A-iv', 'AN4-Catukkanipātapāḷi'), ('Th', 'Theragāthāpāḷi')",
  );
  await db.customStatement(
    "INSERT INTO headings(book_id, para_id, level, title, sc_id) VALUES "
    "('A-iv', 1108, 4, '4. Dutiyanānākaraṇasuttaṃ', 'an4.124'), "
    "('A-iv', 1111, 4, '5. Paṭhamamettāsuttaṃ', 'an4.125'), "
    "('A-iv', 1114, 4, '6. Dutiyamettāsuttaṃ', 'an4.126'), "
    "('A-iv', 1117, 4, '7. Paṭhamatathāgataacchariyasuttaṃ', 'an4.127'), "
    "('A-iv', 1109, 10, '124', NULL), "
    "('A-iv', 1115, 10, '126', NULL), "
    "('Th', 13, 4, '1. Subhūtittheragāthā', 'thag1.1')",
  );
  return db;
}

/// Mounts the app. While [gateOpen] is false only a loading text shows, like
/// the index gate on a cold start. Returns the container.
Future<ProviderContainer> pumpSuttaLinkApp(
  WidgetTester tester,
  EpitakaDatabase db, {
  ValueNotifier<bool>? gateOpen,
  GlobalKey<NavigatorState>? navigatorKey,
  Widget? home,
  void Function(ProviderContainer container)? beforeLinks,
}) async {
  SharedPreferences.setMockInitialValues({});
  final key = navigatorKey ?? GlobalKey<NavigatorState>();
  final gate = gateOpen ?? ValueNotifier(true);
  final router = GoRouter(
    navigatorKey: key,
    routes: [
      GoRoute(
        path: AppRoutes.library,
        builder: (context, state) =>
            Scaffold(body: home ?? const Text('home')),
      ),
      GoRoute(
        path: AppRoutes.reader,
        builder: (context, state) => const Scaffold(body: Text('reader')),
      ),
    ],
  );
  // Wide enough for the desktop layout, where opening a tab needs no route.
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(() => DeepLinkService.instance.dispose());
  final container = ProviderContainer(
    overrides: [
      // The asset cannot load on the fake clock; the seeded database holds the codes.
      suttaCodeCellsProvider.overrideWith((ref) async => null),
      epitakaDbProvider.overrideWith((ref) async => db),
      settingsProvider.overrideWith((ref) => SettingsNotifier(null)),
    ],
  );
  addTearDown(container.dispose);
  // Runs before the link service starts, which is when a launch link opens.
  beforeLinks?.call(container);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.forPreference(
          ThemePreference.light,
          platformBrightness: Brightness.light,
        ),
        supportedLocales: AppLocalizationsDelegate.supportedLocales,
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => ValueListenableBuilder<bool>(
          valueListenable: gate,
          builder: (context, open, _) => open
              ? PendingDeepLinkRunner(child: child!)
              : const Text('loading'),
        ),
      ),
    ),
  );
  // A test that fakes the launch link also reaches the plugin's event stream,
  // which has no implementation here; an empty answer lets it subscribe.
  const events = MethodChannel('com.llfbandit.app_links/events');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    events,
    (call) async => null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      events,
      null,
    ),
  );
  // The app_links plugin call inside init only answers on the real clock.
  await tester.runAsync(() => DeepLinkService.instance.init(key));
  await tester.pump();
  return container;
}

/// Lets the in-memory database answer, then settles the frames.
Future<void> settleLink(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}
