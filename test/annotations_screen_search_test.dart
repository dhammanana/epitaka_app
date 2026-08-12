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
}
