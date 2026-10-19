/// The Rx button in the filter boxes (spec H): Contents and Outline (phone
/// screen and desktop panel each) and Library. Each box filters a list already in
/// memory; with Rx on the pattern runs over the lower-cased title (or book
/// name and id) with exact diacritics.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/models/app_models.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/contents/providers/contents_provider.dart';
import 'package:epitaka/features/contents/screens/contents_screen.dart';
import 'package:epitaka/features/contents/widgets/contents_panel.dart';
import 'package:epitaka/features/library/widgets/library_browser.dart';
import 'package:epitaka/features/outline/models/outline_models.dart';
import 'package:epitaka/features/outline/providers/outline_provider.dart';
import 'package:epitaka/features/outline/screens/outline_screen.dart';
import 'package:epitaka/features/outline/widgets/outline_panel.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:epitaka/features/annotations/providers/annotations_provider.dart';
import 'package:epitaka/features/annotations/widgets/global_annotations_view.dart';
import 'package:epitaka/shared/providers/side_panel_provider.dart';
import 'package:epitaka/features/desktop/desktop_shell.dart';
import 'package:epitaka/shared/utils/app_shortcuts.dart';
import 'package:epitaka/shared/widgets/regex_toggle_button.dart';
import 'package:epitaka/shared/widgets/velthuis_help_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/regex_hotkey.dart';
import 'helpers/type_keys.dart';

/// Differ by one long vowel, so a pattern can tell them apart and the plain
/// (folded) filter cannot.
const _long = 'Sāmaññaphalasutta';
const _short = 'Samaññāsutta';
const _other = 'Brahmajālasutta';
const _titles = [_long, _short, _other];

/// DN 1, 7 words: `([^ ]+ ?)+x` backtracks on it for about 30 s (spec K).
const _slowTitle = 'ekaṃ samayaṃ bhagavā antarā ca rājagahaṃ antarā';
const _runaway = r'([^ ]+ ?)+x';

/// Every list holds the three titles plus [_slowTitle].
const _fixtureTitles = [..._titles, _slowTitle];

final _settings = settingsProvider.overrideWith((ref) {
  final n = SettingsNotifier(null);
  n.state = const AppSettings();
  return n;
});

Widget _app(List<Override> overrides, Widget home) => ProviderScope(
  overrides: [_settings, ...overrides],
  child: MaterialApp(
    supportedLocales: AppLocalizationsDelegate.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  ),
);

final _contents = contentsProvider('dn1').overrideWith(
  (ref) async => [
    for (var i = 0; i < _fixtureTitles.length; i++)
      HeadingInfo(
        bookId: 'dn1',
        paraId: i + 1,
        level: 1,
        title: _fixtureTitles[i],
      ),
  ],
);

Future<void> _openContentsScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    _app([_contents], const ContentsScreen(bookId: 'dn1')),
  );
  await tester.pumpAndSettle();
}

// Every box shows at once (spec I): nothing to tap.
Future<void> _openContentsPanel(WidgetTester tester) async {
  await tester.pumpWidget(
    _app([_contents], const Scaffold(body: ContentsPanel(bookId: 'dn1'))),
  );
  await tester.pumpAndSettle();
}

final _outline = outlineProvider('dn1').overrideWith(
  (ref) async => [
    OutlineGroup(
      title: 'Sīlakkhandhavagga',
      suttas: [
        OutlineSutta(
          title: '',
          items: [
            for (var i = 0; i < _fixtureTitles.length; i++)
              OutlineItem(
                paraId: i + 1,
                sectionEnd: i + 1,
                title: _fixtureTitles[i],
                level: 1,
              ),
          ],
        ),
      ],
    ),
  ],
);

Future<void> _openOutline(WidgetTester tester) async {
  await tester.pumpWidget(_app([_outline], const OutlineScreen(bookId: 'dn1')));
  await tester.pumpAndSettle();
}

Future<void> _openOutlinePanel(WidgetTester tester) async {
  await tester.pumpWidget(
    _app([
      _outline,
      readerTabsProvider.overrideWith(
        (ref) => ReaderTabsNotifier(
          const ReaderTabsState(
            tabs: [ReaderTabInfo(bookId: 'dn1', bookName: 'DN 1')],
          ),
        ),
      ),
    ], const Scaffold(body: OutlinePanel())),
  );
  await tester.pumpAndSettle();
}

Future<void> _openLibrary(WidgetTester tester) async {
  final db = EpitakaDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.runAsync(() async {
    await db.customStatement(
      'CREATE TABLE books ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ref_id INTEGER, vri_id TEXT, '
      'book_id TEXT, category TEXT, nikaya TEXT, sub_nikaya TEXT, '
      'book_name TEXT, description TEXT, mula_ref TEXT, attha_ref TEXT, '
      'tika_ref TEXT, para_id INTEGER, chapter_len INTEGER)',
    );
    for (final (id, name) in [
      ('sp', _long),
      ('sa', _short),
      ('bj', _other),
      ('sl', _slowTitle),
    ]) {
      await db
          .into(db.books)
          .insert(
            BooksCompanion.insert(
              bookId: id,
              category: const Value('Mūla'),
              nikaya: const Value('Dīgha Nikāya'),
              subNikaya: const Value(''),
              bookName: Value(name),
            ),
          );
    }
  });
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app([
      epitakaDbProvider.overrideWith((ref) async => db),
    ], const Scaffold(body: LibraryBrowser())),
  );
  await tester.pumpAndSettle();
  // The phone hides the field until the list is pulled down.
  await tester.drag(find.byType(ListView).first, const Offset(0, 100));
  await tester.pumpAndSettle();
}

Finder get _field => find.byType(TextField).first;
Finder get _rx => find.byType(RegexToggleButton);
Finder get _help =>
    find.descendant(of: _field, matching: find.byType(VelthuisHelpIcon));

/// Which of the three titles the list shows.
Set<String> _shown() => {
  for (final t in _titles)
    if (find
        .textContaining(t, findRichText: true, skipOffstage: false)
        .evaluate()
        .isNotEmpty)
      t,
};

Future<void> _type(WidgetTester tester, String keys) async {
  await tester.enterText(_field, '');
  await typeKeys(tester, _field, keys);
  await _settle(tester);
}

/// Let the job's isolate start on the real clock, then move the fake
/// clock, which holds the job's time-limit timer, past the 3 s limit.
Future<void> _passLimit(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

/// Rx filters answer from a regex job in another isolate, which the fake
/// clock does not run: let real time pass, then draw the answer.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (name, open) in [
    ('Contents screen', _openContentsScreen),
    ('Contents panel', _openContentsPanel),
    ('Outline screen', _openOutline),
    ('Outline panel', _openOutlinePanel),
    ('Library', _openLibrary),
  ]) {
    group(name, () {
      testWidgets('Rx sits after the Velthuis help and the other icons, and stays put; '
          'on, it keeps `.m` and hides the help', (tester) async {
        await open(tester);
        expect(_rx, findsOneWidget);
        expect(_help, findsOneWidget);
        expect(
          tester.getCenter(_rx).dx,
          greaterThan(tester.getCenter(_help).dx),
        );
        final rxBefore = tester.getCenter(_rx);
        for (final icon in [Icons.close, Icons.clear]) {
          final other = find.descendant(
            of: _field,
            matching: find.byIcon(icon),
          );
          if (other.evaluate().isNotEmpty) {
            expect(
              tester.getCenter(_rx).dx,
              greaterThan(tester.getCenter(other).dx),
            );
          }
        }

        await tester.tap(_rx);
        await tester.pumpAndSettle();
        await _type(tester, 'a.m');
        expect(tester.widget<TextField>(_field).controller!.text, 'a.m');
        expect(tester.getCenter(_rx), rxBefore);
        expect(_help, findsNothing);
      });

      testWidgets('a pattern filters with exact diacritics; off, the plain '
          'filter folds them', (tester) async {
        await open(tester);
        await tester.tap(_rx);
        await tester.pumpAndSettle();

        await _type(tester, '^sām');
        expect(_shown(), {_long});
        await _type(tester, '^sam');
        expect(_shown(), {_short});

        await tester.tap(_rx);
        await tester.pumpAndSettle();
        await _type(tester, 'sam');
        expect(_shown(), {_long, _short});
      });

      testWidgets('a runaway pattern ends as "Pattern too slow" at the '
          'field', (tester) async {
        await open(tester);
        await tester.tap(_rx);
        await tester.pumpAndSettle();
        await tester.enterText(_field, _runaway);
        await tester.pumpAndSettle();
        await _passLimit(tester);
        expect(find.text('Pattern too slow'), findsOneWidget);
      });

      testWidgets('X during a runaway pattern leaves no late answer', (tester) async {
        await open(tester);
        await tester.tap(_rx);
        await tester.pumpAndSettle();
        await tester.enterText(_field, _runaway);
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.clear));
        await tester.pumpAndSettle();
        await _passLimit(tester);
        expect(find.text('Pattern too slow'), findsNothing);
        expect(_shown(), _titles.toSet(), reason: 'the whole list is back');
      });

      testWidgets('a pattern that does not compile shows at the field and '
          'empties the list', (tester) async {
        await open(tester);
        await tester.tap(_rx);
        await tester.pumpAndSettle();
        await _type(tester, '(');
        expect(find.textContaining('Invalid pattern:'), findsOneWidget);
        expect(_shown(), isEmpty);
      });

      testWidgets('Alt+R in the box turns Rx on, then off', (tester) async {
        await open(tester);
        expect(rxOnIn(tester, _field), isFalse);
        await regexHotkeyIn(tester, _field);
        await _settle(tester);
        expect(rxOnIn(tester, _field), isTrue);
        await regexHotkeyIn(tester, _field);
        await _settle(tester);
        expect(rxOnIn(tester, _field), isFalse);
      });
    });
  }

  // The phone screens keep their own title (the Contents title row, the
  // Outline app bar); the panels drop theirs, which the sidebar shows.
  for (final (name, open, title) in [
    ('Contents screen', _openContentsScreen, null),
    ('Contents panel', _openContentsPanel, 'Contents'),
    ('Outline screen', _openOutline, null),
    ('Outline panel', _openOutlinePanel, 'Outline'),
  ]) {
    testWidgets('$name shows its search box at once, with no search '
        'toggle; X clears the box', (tester) async {
      await open(tester);
      expect(_field, findsOneWidget);
      // The only search icon is the one inside the box: no toggle.
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(
        find.descendant(of: _field, matching: find.byIcon(Icons.search)),
        findsOneWidget,
      );
      if (title != null) expect(find.text(title), findsNothing);
      expect(find.byIcon(Icons.clear), findsNothing);

      await _type(tester, 'sam');
      expect(_shown(), {_long, _short});
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_field).controller!.text, '');
      expect(_shown(), _titles.toSet());
      expect(_field, findsOneWidget, reason: 'X clears; it does not close');
    });
  }

  group('opening a panel puts the cursor in its box (spec J)', () {
    test('a tab or button toggle asks for focus; a word lookup does not', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final panels = c.read(sidePanelProvider.notifier);
      panels.toggle(SidePanelType.contents);
      expect(c.read(sidePanelProvider).left.autoFocus, isTrue);
      panels.open(SidePanelType.dictionary, data: 'dhamma', pin: true);
      final slot = c.read(sidePanelProvider);
      final dict = slot.left.openPanel == SidePanelType.dictionary
          ? slot.left
          : slot.right;
      expect(dict.autoFocus, isFalse);
    });

    bool boxHasFocus(WidgetTester tester) => tester
        .widget<EditableText>(
          find.descendant(of: _field, matching: find.byType(EditableText)),
        )
        .focusNode
        .hasFocus;

    final tabs = readerTabsProvider.overrideWith(
      (ref) => ReaderTabsNotifier(
        const ReaderTabsState(
          tabs: [ReaderTabInfo(bookId: 'dn1', bookName: 'DN 1')],
        ),
      ),
    );
    for (final (name, overrides, panel) in [
      (
        'Contents',
        [_contents],
        const ContentsPanel(bookId: 'dn1', autoFocus: true) as Widget,
      ),
      ('Outline', [_outline, tabs], const OutlinePanel(autoFocus: true)),
      (
        'Annotations',
        [allAnnotationsProvider.overrideWith((ref) => Stream.value(const []))],
        const GlobalAnnotationsView(autoFocus: true),
      ),
    ]) {
      testWidgets('$name panel', (tester) async {
        await tester.pumpWidget(_app(overrides, Scaffold(body: panel)));
        await tester.pumpAndSettle();
        expect(boxHasFocus(tester), isTrue);
      });
    }
  });

  group('the sidebar hands its focus flag to every panel (review item 8)', () {
    for (final (type, overrides) in [
      (SidePanelType.contents, [_contents]),
      (SidePanelType.outline, [_outline]),
      (
        SidePanelType.annotations,
        [allAnnotationsProvider.overrideWith((ref) => Stream.value(const []))],
      ),
    ]) {
      testWidgets('${type.name} panel', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _app(
            [
              ...overrides,
              readerTabsProvider.overrideWith(
                (ref) => ReaderTabsNotifier(
                  const ReaderTabsState(
                    tabs: [ReaderTabInfo(bookId: 'dn1', bookName: 'DN 1')],
                  ),
                ),
              ),
            ],
            Scaffold(
              body: SizedBox(
                width: 340,
                child: DesktopSidebar(
                  panel: type,
                  title: type.name,
                  onRight: false,
                  autoFocus: true,
                  onClose: () {},
                  onMoveSidebarRight: () {},
                  onMoveSidebarLeft: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final editable = tester.widget<EditableText>(
          find.descendant(of: _field, matching: find.byType(EditableText)),
        );
        expect(editable.focusNode.hasFocus, isTrue);
      });
    }
  });

  testWidgets('the Alt+R key reaches the box with the cursor through the '
      "app's bindings; in a field with no Rx it does nothing", (tester) async {
    AppShortcuts.overrides = const {};
    const plain = Key('plain');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [_settings, _contents],
        child: withAppShortcuts(
          MaterialApp(
            supportedLocales: AppLocalizationsDelegate.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(
              body: Column(
                children: [
                  Expanded(child: ContentsPanel(bookId: 'dn1')),
                  TextField(key: plain),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final box = find.descendant(
      of: find.byType(ContentsPanel),
      matching: find.byType(TextField),
    );

    await tester.showKeyboard(find.byKey(plain));
    await sendAltR(tester);
    await _settle(tester);
    expect(rxOnIn(tester, box), isFalse);

    await tester.showKeyboard(box);
    await sendAltR(tester);
    await _settle(tester);
    expect(rxOnIn(tester, box), isTrue);
    await sendAltR(tester);
    await _settle(tester);
    expect(rxOnIn(tester, box), isFalse);
  });
}
