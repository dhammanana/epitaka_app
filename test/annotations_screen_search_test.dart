/// Widget tests for the Annotations screen search field.
///
/// Covers: filtering by quote text / note body / bookmark name / book name,
/// diacritic-insensitive matching (ā=a, ṃ=m …), and the "no results" empty
/// state with a Clear search button.

library;

import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/annotations/models/annotation.dart';
import 'package:epitaka/features/annotations/providers/annotations_provider.dart';
import 'package:epitaka/features/annotations/screens/annotations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/regex_hotkey.dart';
import 'helpers/type_keys.dart';

Annotation _ann({
  required String id,
  required String bookId,
  String? bookName,
  String? exactText,
  String? note,
  String? name,
  AnnotationType type = AnnotationType.highlight,
}) {
  final now = DateTime.now();
  return Annotation(
    id: id,
    type: type,
    bookId: bookId,
    bookName: bookName,
    paraId: 1,
    lineId: 1,
    segment: 'pali',
    startOffset: 0,
    endOffset: 5,
    exactText: exactText,
    note: note,
    name: name,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _build() {
  final router = GoRouter(
    initialLocation: '/annotations',
    routes: [
      GoRoute(
        path: '/annotations',
        builder: (context, state) => const AnnotationsScreen(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      allAnnotationsProvider.overrideWith(
        (ref) => Stream.value([
          _ann(
            id: '1',
            bookId: 'vin',
            bookName: 'Vinaya',
            exactText: 'dhammaṃ saraṇaṃ gacchāmi',
          ),
          _ann(
            id: '2',
            bookId: 'sutta',
            bookName: 'Suttanta',
            exactText: 'sabbe sattā sukhitā',
          ),
          _ann(
            id: '3',
            bookId: 'vin',
            bookName: 'Vinaya',
            type: AnnotationType.bookmark,
            name: 'My saved place',
          ),
          _ann(
            id: '4',
            bookId: 'abhi',
            bookName: 'Abhidhamma',
            note: 'Remember this point',
          ),
          // DN 1, 7 words: `([^ ]+ ?)+x` backtracks on it for about 30 s.
          _ann(
            id: '5',
            bookId: 'dn1',
            bookName: 'Dīgha',
            exactText: 'ekaṃ samayaṃ bhagavā antarā ca rājagahaṃ antarā',
          ),
        ]),
      ),
      settingsProvider.overrideWith((ref) {
        final notifier = SettingsNotifier(null);
        notifier.state = const AppSettings();
        return notifier;
      }),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      supportedLocales: AppLocalizationsDelegate.supportedLocales,
      localizationsDelegates: const [AppLocalizationsDelegate()],
      theme: ThemeData(
        useMaterial3: true,
        // Avoid the ink-sparkle shader asset missing in tests.
        splashFactory: InkSplash.splashFactory,
      ),
    ),
  );
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pumpAndSettle();
  // An Rx search answers from a regex job in another isolate, which the
  // fake clock does not run: let real time pass, then draw the answer.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows all annotations initially', (tester) async {
    await tester.pumpWidget(_build());
    await tester.pumpAndSettle();

    expect(find.textContaining('dhammaṃ'), findsOneWidget);
    expect(find.textContaining('sabbe'), findsOneWidget);
    expect(find.textContaining('My saved place'), findsOneWidget);
    expect(find.textContaining('Remember this point'), findsOneWidget);
  });

  testWidgets('filters by quote text', (tester) async {
    await tester.pumpWidget(_build());
    await tester.pumpAndSettle();

    await _search(tester, 'sabbe');

    // The full quote (not just 'sabbe') so the search field's own text
    // doesn't also match the finder.
    expect(find.textContaining('sabbe sattā'), findsOneWidget);
    expect(find.textContaining('dhammaṃ'), findsNothing);
  });

  testWidgets('is diacritic-insensitive', (tester) async {
    await tester.pumpWidget(_build());
    await tester.pumpAndSettle();

    // "dhamma" must match "dhammaṃ", "satta" must match "sattā".
    await _search(tester, 'dhamma');
    expect(find.textContaining('dhammaṃ'), findsOneWidget);

    await _search(tester, 'satta');
    expect(find.textContaining('sabbe sattā'), findsOneWidget);
  });

  testWidgets('filters by book name', (tester) async {
    await tester.pumpWidget(_build());
    await tester.pumpAndSettle();

    await _search(tester, 'Suttanta');

    expect(find.textContaining('sabbe sattā'), findsOneWidget);
    expect(find.textContaining('dhammaṃ'), findsNothing);
  });

  testWidgets('filters by note body and bookmark name', (tester) async {
    await tester.pumpWidget(_build());
    await tester.pumpAndSettle();

    await _search(tester, 'remember');
    expect(find.textContaining('Remember this point'), findsOneWidget);

    await _search(tester, 'saved');
    expect(find.textContaining('My saved place'), findsOneWidget);
    expect(find.textContaining('Remember this point'), findsNothing);
  });

  testWidgets('no matches shows the search empty state; clear restores', (
    tester,
  ) async {
    await tester.pumpWidget(_build());
    await tester.pumpAndSettle();

    await _search(tester, 'zzzznomatch');

    expect(find.textContaining('No results for'), findsOneWidget);

    // Clearing the search restores every annotation.
    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();
    expect(find.textContaining('dhammaṃ'), findsOneWidget);
    expect(find.textContaining('My saved place'), findsOneWidget);
  });

  group('Rx and Velthuis (spec J)', () {
    Finder field() => find.byType(TextField);
    Future<void> rxOn(WidgetTester tester) =>
        regexToggleByTapIn(tester, field());

    testWidgets('the box ends in X, then the more menu that holds the '
        'help; Velthuis works with Rx off from the menu', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      // The Velthuis card opens from the more menu.
      await openVelthuisHelpIn(tester, field());
      expect(find.textContaining('→'), findsWidgets);
      // Close the dialog before the next step.
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await typeKeys(tester, field(), 'paali');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field()).controller!.text, 'pāli');
      expect(
        tester.getCenter(
          find.descendant(of: field(), matching: find.byIcon(Icons.more_vert)),
        ).dx,
        greaterThan(tester.getCenter(find.byIcon(Icons.clear)).dx),
      );
    });

    testWidgets('Alt+R in the box turns Rx on, then off', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(rxOnIn(tester, field()), isFalse);
      await regexHotkeyIn(tester, field());
      await tester.pumpAndSettle();
      expect(rxOnIn(tester, field()), isTrue);
      await regexHotkeyIn(tester, field());
      await tester.pumpAndSettle();
      expect(rxOnIn(tester, field()), isFalse);
    });

    testWidgets('Rx on keeps `.m`, and matches exact '
        'diacritics', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      await rxOn(tester);
      await typeKeys(tester, field(), 'a.m');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field()).controller!.text, 'a.m');

      await _search(tester, 'sattā');
      expect(find.textContaining('sabbe sattā'), findsOneWidget);
      expect(find.textContaining('dhammaṃ'), findsNothing);
      // `satta` is not `sattā` with Rx on.
      await _search(tester, 'satta');
      expect(find.textContaining('sabbe sattā'), findsNothing);
    });

    testWidgets('a pattern that does not compile says why at the field', (
      tester,
    ) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      await rxOn(tester);
      await _search(tester, '(');
      expect(find.textContaining('Invalid pattern:'), findsOneWidget);
      expect(find.textContaining('dhammaṃ'), findsNothing);
    });

    // The job's time-limit timer runs on the fake clock; its isolate on the
    // real one.
    Future<void> passLimit(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    }

    testWidgets('a runaway pattern ends as "Pattern too slow"', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      await rxOn(tester);
      await tester.enterText(field(), r'([^ ]+ ?)+x');
      await tester.pumpAndSettle();
      await passLimit(tester);
      expect(find.text('Pattern too slow'), findsOneWidget);
    });

    testWidgets('X during a runaway pattern leaves no late answer', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      await rxOn(tester);
      await tester.enterText(field(), r'([^ ]+ ?)+x');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      await passLimit(tester);
      expect(find.text('Pattern too slow'), findsNothing);
      expect(find.textContaining('dhammaṃ'), findsOneWidget);
    });
  });
}
