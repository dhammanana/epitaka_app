import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:epitaka/core/models/shortcut_override.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/desktop/desktop_activity_bar.dart';
import 'package:epitaka/features/settings/screens/shortcut_settings_screen.dart';
import 'package:epitaka/shared/utils/app_shortcuts.dart';

const _ctrlShiftK = SingleActivator(
  LogicalKeyboardKey.keyK,
  control: true,
  shift: true,
);

/// Pumps the page the way the app shows it: app.dart copies the setting
/// into [AppShortcuts.overrides] above everything else, and wraps the app
/// in the app-wide [CallbackShortcuts]. [rootBindings] stands in for that.
Future<SettingsNotifier> _pumpPage(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  Map<ShortcutActivator, VoidCallback> rootBindings = const {},
  double width = 1200,
}) async {
  // Tall enough that the lazy list builds all 46 rows.
  tester.view.physicalSize = Size(width, 8000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefs);
  final sharedPrefs = await SharedPreferences.getInstance();
  final settings = SettingsNotifier(sharedPrefs)..init(sharedPrefs);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [settingsProvider.overrideWith((ref) => settings)],
      child: Consumer(
        builder: (context, ref, _) {
          AppShortcuts.overrides = ref.watch(
            settingsProvider.select((s) => s.shortcutOverrides),
          );
          return CallbackShortcuts(
            bindings: rootBindings,
            child: MaterialApp(
              locale: const Locale('en'),
              supportedLocales: AppLocalizationsDelegate.supportedLocales,
              localizationsDelegates: const [
                AppLocalizationsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const Scaffold(body: ShortcutSettingsBody()),
            ),
          );
        },
      ),
    ),
  );
  // The translations load asynchronously; the first frame is empty.
  await tester.pumpAndSettle();
  return settings;
}

void main() {
  setUp(() => AppShortcuts.overrides = const {});
  tearDown(() => AppShortcuts.overrides = const {});

  testWidgets('lists every shortcut under eight sections in order', (
    tester,
  ) async {
    await _pumpPage(tester);
    const titles = [
      'Sidebar',
      'Reading',
      'Tabs',
      'Text & display',
      'App',
      'Reader',
      'Search results',
      'Vīmaṃsā chat',
    ];
    final tops = [
      for (final title in titles) tester.getTopLeft(find.text(title)).dy,
    ];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]), reason: titles[i]);
    }
    expect(find.byTooltip('Change'), findsNWidgets(46));
    expect(find.byTooltip('Restore default'), findsNothing);
  });

  testWidgets('the Sidebar section follows the activity bar order', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizationsDelegate.supportedLocales,
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: DesktopActivityBar(
            activeSidebar: null,
            vimamsaActive: false,
            onToggleSidebar: (_) {},
            onToggleVimamsa: () {},
            onResetLayout: () {},
            onOpenSettings: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final sidebar = AppShortcuts.shortcutCatalog
        .where((b) => b.section == ShortcutSection.sidebar)
        .toList();
    // Each bar tooltip ends with its shortcut hint; map it back to an id.
    final barOrder = [
      for (final tip in tester.widgetList<Tooltip>(find.byType(Tooltip)))
        for (final b in sidebar)
          if (tip.message!.endsWith(' ${AppShortcuts.hintFor(b.id)}')) b.id,
    ];
    expect(barOrder, hasLength(sidebar.length));
    expect(barOrder, sidebar.map((b) => b.id).toList());

    await _pumpPage(tester);
    final rowTops = [
      for (final b in sidebar)
        tester.getTopLeft(find.byKey(ValueKey('keycap-${b.id}'))).dy,
    ];
    for (var i = 1; i < rowTops.length; i++) {
      expect(rowTops[i], greaterThan(rowTops[i - 1]), reason: sidebar[i].id);
    }
  });

  testWidgets('Restore default gives a custom row its keys back', (
    tester,
  ) async {
    final settings = await _pumpPage(
      tester,
      prefs: {
        'shortcut_overrides': encodeOverrides({'dictionary': _ctrlShiftK}),
      },
    );
    expect(find.text('Ctrl+Shift+K'), findsOneWidget);
    expect(find.text('Ctrl+D'), findsNothing);
    expect(find.byTooltip('Restore default'), findsOneWidget);

    await tester.tap(find.byTooltip('Restore default'));
    await tester.pumpAndSettle();

    expect(find.text('Ctrl+D'), findsOneWidget);
    expect(find.text('Ctrl+Shift+K'), findsNothing);
    expect(find.byTooltip('Restore default'), findsNothing);
    expect(settings.state.shortcutOverrides, isEmpty);
  });

  group('recording', () {
    late int ctrlShiftKFired;
    late int ctrlFFired;
    Map<ShortcutActivator, VoidCallback> rootBindings() => {
      _ctrlShiftK: () => ctrlShiftKFired++,
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
          ctrlFFired++,
    };

    setUp(() {
      ctrlShiftKFired = 0;
      ctrlFFired = 0;
    });

    Future<void> press(
      WidgetTester tester,
      LogicalKeyboardKey key, {
      bool control = false,
      bool shift = false,
    }) async {
      if (control)
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(key);
      if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    testWidgets('a new combination is saved and no shortcut fires', (
      tester,
    ) async {
      final settings = await _pumpPage(tester, rootBindings: rootBindings());
      await tester.tap(find.byKey(const ValueKey('change-dictionary')));
      await tester.pumpAndSettle();
      expect(find.text('Press new shortcut… (Esc to cancel)'), findsOneWidget);

      await press(tester, LogicalKeyboardKey.keyK, control: true, shift: true);

      expect(ctrlShiftKFired, 0);
      expect(find.text('Press new shortcut… (Esc to cancel)'), findsNothing);
      expect(find.text('Ctrl+Shift+K'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(
        decodeOverrides(
          prefs.getString('shortcut_overrides'),
        )['dictionary']?.trigger,
        LogicalKeyboardKey.keyK,
      );
      expect(settings.state.shortcutOverrides.keys, ['dictionary']);
    });

    testWidgets('a clashing key replaces the other row and names it', (
      tester,
    ) async {
      final settings = await _pumpPage(tester, rootBindings: rootBindings());
      await tester.tap(find.byKey(const ValueKey('change-dictionary')));
      await tester.pumpAndSettle();

      await press(tester, LogicalKeyboardKey.keyF, control: true);

      expect(ctrlFFired, 0);
      expect(find.text('Press new shortcut… (Esc to cancel)'), findsNothing);
      expect(
        find.text('Find in Book no longer has a shortcut'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Shared with Search in chat. When the full-screen chat has focus, '
          'Search in chat wins.',
        ),
        findsOneWidget,
      );
      expect(find.text('None'), findsOneWidget);
      // Both messages start at the same left edge, under the row's name.
      final replacedLeft = tester
          .getTopLeft(find.text('Find in Book no longer has a shortcut'))
          .dx;
      final sharedLeft = tester
          .getTopLeft(find.textContaining('Shared with Search in chat'))
          .dx;
      expect(replacedLeft, sharedLeft);
      expect(
        replacedLeft,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('keycap-dictionary'))).dx,
        ),
      );
      final overrides = settings.state.shortcutOverrides;
      expect(overrides['dictionary']?.trigger, LogicalKeyboardKey.keyF);
      expect(overrides.containsKey('find-in-book'), isTrue);
      expect(overrides['find-in-book'], isNull);
      expect(AppShortcuts.activatorsFor('find-in-book'), isEmpty);
    });

    testWidgets('restoring a default takes it back from the row that has it', (
      tester,
    ) async {
      final settings = await _pumpPage(
        tester,
        prefs: {
          'shortcut_overrides': encodeOverrides({
            'dictionary': const SingleActivator(
              LogicalKeyboardKey.keyF,
              control: true,
            ),
            'find-in-book': null,
          }),
        },
      );
      await tester.tap(find.byKey(const ValueKey('restore-find-in-book')));
      await tester.pumpAndSettle();

      expect(find.text('Dictionary no longer has a shortcut'), findsOneWidget);
      expect(
        settings.state.shortcutOverrides.containsKey('find-in-book'),
        isFalse,
      );
      expect(settings.state.shortcutOverrides['dictionary'], isNull);
      expect(
        settings.state.shortcutOverrides.containsKey('dictionary'),
        isTrue,
      );
    });

    testWidgets('tapping the key cap starts recording', (tester) async {
      await _pumpPage(tester);
      await tester.tap(find.byKey(const ValueKey('keycap-dictionary')));
      await tester.pumpAndSettle();
      expect(find.text('Press new shortcut… (Esc to cancel)'), findsOneWidget);
    });

    testWidgets('Esc cancels and keeps the old combination', (tester) async {
      final settings = await _pumpPage(tester);
      await tester.tap(find.byKey(const ValueKey('change-dictionary')));
      await tester.pumpAndSettle();

      await press(tester, LogicalKeyboardKey.escape);

      expect(find.text('Press new shortcut… (Esc to cancel)'), findsNothing);
      expect(find.text('Ctrl+D'), findsOneWidget);
      expect(settings.state.shortcutOverrides, isEmpty);
    });

    testWidgets('a bare letter on an app-wide row asks for a modifier', (
      tester,
    ) async {
      await _pumpPage(tester);
      await tester.tap(find.byKey(const ValueKey('change-dictionary')));
      await tester.pumpAndSettle();

      await press(tester, LogicalKeyboardKey.keyK);

      expect(
        find.text('Add Ctrl, Alt or Cmd/Win, or use F1–F12'),
        findsOneWidget,
      );
    });

    testWidgets('pressing the default again leaves no custom shortcut', (
      tester,
    ) async {
      final settings = await _pumpPage(
        tester,
        prefs: {
          'shortcut_overrides': encodeOverrides({'dictionary': _ctrlShiftK}),
        },
      );
      await tester.tap(find.byKey(const ValueKey('change-dictionary')));
      await tester.pumpAndSettle();

      await press(tester, LogicalKeyboardKey.keyD, control: true);

      expect(settings.state.shortcutOverrides, isEmpty);
      expect(find.byTooltip('Restore default'), findsNothing);
    });

    testWidgets('re-recording a default checks its Cmd twin for clashes', (
      tester,
    ) async {
      final settings = await _pumpPage(
        tester,
        prefs: {
          'shortcut_overrides': encodeOverrides({
            'jump': const SingleActivator(LogicalKeyboardKey.keyD, meta: true),
            'dictionary': null,
          }),
        },
      );
      await tester.tap(find.byKey(const ValueKey('change-dictionary')));
      await tester.pumpAndSettle();

      await press(tester, LogicalKeyboardKey.keyD, control: true);

      // Dictionary's defaults are back, so Jump must lose its Cmd+D.
      final overrides = settings.state.shortcutOverrides;
      expect(overrides.containsKey('dictionary'), isFalse);
      expect(overrides.containsKey('jump'), isTrue);
      expect(overrides['jump'], isNull);
      expect(find.textContaining('no longer has a shortcut'), findsOneWidget);
    });

    testWidgets('Caps Lock alone does not become a shortcut', (tester) async {
      final settings = await _pumpPage(tester);
      await tester.tap(find.byKey(const ValueKey('change-reader-next-line')));
      await tester.pumpAndSettle();

      await press(tester, LogicalKeyboardKey.capsLock);

      expect(find.text('Press new shortcut… (Esc to cancel)'), findsOneWidget);
      expect(settings.state.shortcutOverrides, isEmpty);
    });

    testWidgets('Esc after a refusal clears the refusal', (tester) async {
      await _pumpPage(tester);
      await tester.tap(find.byKey(const ValueKey('change-dictionary')));
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.keyK);
      expect(
        find.text('Add Ctrl, Alt or Cmd/Win, or use F1–F12'),
        findsOneWidget,
      );

      await press(tester, LogicalKeyboardKey.escape);

      expect(
        find.text('Add Ctrl, Alt or Cmd/Win, or use F1–F12'),
        findsNothing,
      );
    });
  });

  testWidgets('the recording prompt fits a narrow settings pane', (
    tester,
  ) async {
    await _pumpPage(tester, width: 380);
    await tester.tap(find.byKey(const ValueKey('change-reader-next-line')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
