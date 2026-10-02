import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/settings/screens/help_screen.dart';
import 'package:epitaka/shared/utils/app_shortcuts.dart';

const _ctrlShiftK = SingleActivator(
  LogicalKeyboardKey.keyK,
  control: true,
  shift: true,
);

KeyDownEvent _down(LogicalKeyboardKey key) => KeyDownEvent(
  physicalKey: PhysicalKeyboardKey.keyA,
  logicalKey: key,
  timeStamp: Duration.zero,
);

ShortcutBinding _binding(String id) =>
    AppShortcuts.shortcutCatalog.firstWhere((b) => b.id == id);

void main() {
  setUp(() => AppShortcuts.overrides = const {});
  tearDown(() => AppShortcuts.overrides = const {});

  group('catalog', () {
    test('holds 46 shortcuts with unique ids, 32 of them app-wide', () {
      final catalog = AppShortcuts.shortcutCatalog;
      expect(catalog, hasLength(46));
      expect(catalog.map((b) => b.id).toSet(), hasLength(46));
      expect(catalog.where((b) => b.section.isAppWide), hasLength(32));
    });
  });

  group('overrides', () {
    test('a user combination replaces the default hint', () {
      expect(AppShortcuts.hintFor('dictionary'), 'Ctrl+D');
      AppShortcuts.overrides = {'dictionary': _ctrlShiftK};
      expect(AppShortcuts.hintFor('dictionary'), 'Ctrl+Shift+K');
    });

    test('an override replaces every default and is the macOS menu key', () {
      AppShortcuts.overrides = {'dictionary': _ctrlShiftK};
      final binding = AppShortcuts.effective(_binding('dictionary'));
      expect(binding.activators, hasLength(1));
      expect(
        identical(binding.activators.single, binding.macActivator),
        isTrue,
      );
    });

    test('an entry with no menu key gets no menu key from its override', () {
      AppShortcuts.overrides = {'tab-1': _ctrlShiftK};
      expect(AppShortcuts.effective(_binding('tab-1')).macActivator, isNull);
    });

    test('a row with no keys has no hint and no activators', () {
      AppShortcuts.overrides = {'dictionary': null};
      expect(AppShortcuts.hintFor('dictionary'), '');
      expect(AppShortcuts.activatorsFor('dictionary'), isEmpty);
      expect(
        AppShortcuts.effective(_binding('dictionary')).macActivator,
        isNull,
      );
    });

    test('an override for an unknown id is ignored', () {
      AppShortcuts.overrides = {'no-such-shortcut': _ctrlShiftK};
      expect(AppShortcuts.activatorsFor('no-such-shortcut'), isEmpty);
      expect(AppShortcuts.hintFor('dictionary'), 'Ctrl+D');
    });
  });

  group('refusalFor', () {
    SingleActivator ctrl(LogicalKeyboardKey key, {bool shift = false}) =>
        SingleActivator(key, control: true, shift: shift);

    test('accepts a free combination', () {
      expect(AppShortcuts.refusalFor('dictionary', _ctrlShiftK), isNull);
    });

    test('refuses a plain UI key, even for an in-place row', () {
      expect(
        AppShortcuts.refusalFor(
          'reader-next-line',
          const SingleActivator(LogicalKeyboardKey.space),
        ),
        AppShortcuts.refusalUiKey,
      );
    });

    test('an app-wide row needs Ctrl, Alt or Meta', () {
      expect(
        AppShortcuts.refusalFor(
          'dictionary',
          const SingleActivator(LogicalKeyboardKey.keyK),
        ),
        AppShortcuts.refusalNeedsModifier,
      );
      expect(
        AppShortcuts.refusalFor(
          'dictionary',
          const SingleActivator(LogicalKeyboardKey.keyK, shift: true),
        ),
        AppShortcuts.refusalNeedsModifier,
      );
    });

    test('an app-wide row may use a bare function key', () {
      expect(
        AppShortcuts.refusalFor(
          'dictionary',
          const SingleActivator(LogicalKeyboardKey.f5),
        ),
        isNull,
      );
    });

    test('an in-place row that is not a movement key needs a modifier', () {
      // Its CallbackShortcuts also sees keys typed into the chat box.
      expect(
        AppShortcuts.refusalFor(
          'chat-new',
          const SingleActivator(LogicalKeyboardKey.keyN),
        ),
        AppShortcuts.refusalNeedsModifier,
      );
      expect(
        AppShortcuts.refusalFor(
          'reader-copy',
          const SingleActivator(LogicalKeyboardKey.keyK),
        ),
        AppShortcuts.refusalNeedsModifier,
      );
    });

    test('an in-place row may use a bare letter', () {
      expect(
        AppShortcuts.refusalFor(
          'reader-next-line',
          const SingleActivator(LogicalKeyboardKey.keyN),
        ),
        isNull,
      );
    });

    test('refuses plain Ctrl+V but not Ctrl+Shift+V', () {
      expect(
        AppShortcuts.refusalFor('dictionary', ctrl(LogicalKeyboardKey.keyV)),
        AppShortcuts.refusalReserved,
      );
      expect(
        AppShortcuts.refusalFor(
          'dictionary',
          ctrl(LogicalKeyboardKey.keyV, shift: true),
        ),
        isNull,
      );
    });

    test('a row may always go back to its own default', () {
      AppShortcuts.overrides = {'reader-copy': _ctrlShiftK};
      expect(
        AppShortcuts.refusalFor('reader-copy', ctrl(LogicalKeyboardKey.keyC)),
        isNull,
      );
    });
  });

  group('clashesWith and overlapsWith', () {
    SingleActivator ctrl(LogicalKeyboardKey key) =>
        SingleActivator(key, control: true);

    test('two app-wide rows clash; an app-wide and a chat row overlap', () {
      final ctrlF = ctrl(LogicalKeyboardKey.keyF);
      expect(AppShortcuts.clashesWith('dictionary', ctrlF), ['find-in-book']);
      expect(AppShortcuts.overlapsWith('dictionary', ctrlF), ['chat-find']);
    });

    test('an in-place key over an app-wide one is an overlap', () {
      final ctrlD = ctrl(LogicalKeyboardKey.keyD);
      expect(AppShortcuts.clashesWith('reader-next-line', ctrlD), isEmpty);
      expect(AppShortcuts.overlapsWith('reader-next-line', ctrlD), [
        'dictionary',
      ]);
    });

    test('two rows of the same place clash', () {
      const h = SingleActivator(LogicalKeyboardKey.keyH);
      expect(AppShortcuts.clashesWith('reader-next-line', h), [
        'reader-prev-link',
      ]);
    });

    test('in-place rows of different places neither clash nor overlap', () {
      const h = SingleActivator(LogicalKeyboardKey.keyH);
      expect(AppShortcuts.clashesWith('search-next', h), isEmpty);
      expect(AppShortcuts.overlapsWith('search-next', h), isEmpty);
    });

    test('sees the Cmd twin of an untouched default', () {
      expect(
        AppShortcuts.clashesWith(
          'jump',
          const SingleActivator(LogicalKeyboardKey.keyD, meta: true),
        ),
        ['dictionary'],
      );
    });

    test('checks current keys, not defaults, of other rows', () {
      AppShortcuts.overrides = {'dictionary': _ctrlShiftK, 'history': null};
      expect(
        AppShortcuts.clashesWith('jump', ctrl(LogicalKeyboardKey.keyD)),
        isEmpty,
      );
      expect(AppShortcuts.clashesWith('jump', _ctrlShiftK), ['dictionary']);
      expect(
        AppShortcuts.clashesWith('jump', ctrl(LogicalKeyboardKey.keyY)),
        isEmpty,
      );
    });
  });

  group('bindings', () {
    bool hasCombo(Iterable<ShortcutActivator> keys, SingleActivator combo) =>
        keys.whereType<SingleActivator>().any(
          (a) =>
              a.trigger == combo.trigger &&
              a.control == combo.control &&
              a.shift == combo.shift &&
              a.alt == combo.alt &&
              a.meta == combo.meta,
        );

    testWidgets('an override replaces the app-wide keys of its action', (
      tester,
    ) async {
      AppShortcuts.overrides = {'dictionary': _ctrlShiftK};
      late Map<ShortcutActivator, VoidCallback> bindings;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              bindings = AppShortcuts.bindings(
                GlobalKey<NavigatorState>(),
                ref,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(hasCombo(bindings.keys, _ctrlShiftK), isTrue);
      expect(
        hasCombo(
          bindings.keys,
          const SingleActivator(LogicalKeyboardKey.keyD, control: true),
        ),
        isFalse,
      );
      expect(
        hasCombo(
          bindings.keys,
          const SingleActivator(LogicalKeyboardKey.keyD, meta: true),
        ),
        isFalse,
      );
    });

    testWidgets('a row with no keys is not bound at all', (tester) async {
      AppShortcuts.overrides = {'dictionary': null};
      late Map<ShortcutActivator, VoidCallback> bindings;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              bindings = AppShortcuts.bindings(
                GlobalKey<NavigatorState>(),
                ref,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      for (final combo in const [
        SingleActivator(LogicalKeyboardKey.keyD, control: true),
        SingleActivator(LogicalKeyboardKey.keyD, meta: true),
      ]) {
        expect(hasCombo(bindings.keys, combo), isFalse);
      }
    });

    testWidgets('in-place shortcuts are not bound at the app root', (
      tester,
    ) async {
      late Map<ShortcutActivator, VoidCallback> bindings;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              bindings = AppShortcuts.bindings(
                GlobalKey<NavigatorState>(),
                ref,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        hasCombo(bindings.keys, const SingleActivator(LogicalKeyboardKey.keyJ)),
        isFalse,
      );
    });
  });

  group('help list', () {
    testWidgets('shows a changed shortcut and splits the tab range', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsNotifier(prefs)..init(prefs);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsProvider.overrideWith((ref) => settings)],
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizationsDelegate.supportedLocales,
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(body: HelpScreenBody()),
          ),
        ),
      );
      // The translations load asynchronously; the first frame is empty.
      await tester.pumpAndSettle();
      expect(find.text('Ctrl+D'), findsOneWidget);
      expect(find.text('Switch to Tab 1-9'), findsOneWidget);

      // app.dart copies the setting into AppShortcuts.overrides; do both.
      final overrides = {
        'dictionary': _ctrlShiftK,
        'tab-3': const SingleActivator(LogicalKeyboardKey.f3),
        'history': null,
      };
      AppShortcuts.overrides = overrides;
      await settings.setShortcutOverride('dictionary', _ctrlShiftK);
      await settings.setShortcutOverride('tab-3', overrides['tab-3']!);
      await settings.setShortcutOverride('history', null);
      await tester.pump();

      expect(find.text('Ctrl+D'), findsNothing);
      expect(find.text('Ctrl+Shift+K'), findsOneWidget);
      expect(find.text('Switch to Tab 1-9'), findsNothing);
      expect(find.text('Switch to Tab 3'), findsOneWidget);
      expect(find.text('F3'), findsOneWidget);
      // A shortcut with no keys reads "None", as on the settings page.
      expect(find.text('None'), findsOneWidget);
    });
  });

  group('matches', () {
    testWidgets('a bare J matches only with no modifier held', (tester) async {
      expect(
        AppShortcuts.matches('search-next', _down(LogicalKeyboardKey.keyJ)),
        isTrue,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      expect(
        AppShortcuts.matches('search-next', _down(LogicalKeyboardKey.keyJ)),
        isFalse,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    });

    test('a rebound key matches and the old one does not', () {
      AppShortcuts.overrides = {
        'search-next': const SingleActivator(LogicalKeyboardKey.keyN),
      };
      expect(
        AppShortcuts.matches('search-next', _down(LogicalKeyboardKey.keyN)),
        isTrue,
      );
      expect(
        AppShortcuts.matches('search-next', _down(LogicalKeyboardKey.keyJ)),
        isFalse,
      );
    });
  });
}
