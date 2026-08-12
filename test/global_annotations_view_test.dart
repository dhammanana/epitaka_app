/// Widget tests for the redesigned global annotations view.
///
/// Covers the new behaviors:
///   • per-type counts rendered inside the filter chips,
///   • book groups with more than 5 annotations start collapsed and expand
///     when their header is tapped,
///   • the book filter narrows the list to the selected books.

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

Widget _build(List<Annotation> annotations) {
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
        (ref) => Stream.value(annotations),
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

void main() {
  testWidgets('per-type counts are rendered inside the filter chips', (
    tester,
  ) async {
    await tester.pumpWidget(
      _build([
        _ann(id: '1', bookId: 'vin', bookName: 'Vinaya', exactText: 'quote a'),
        _ann(
          id: '2',
          bookId: 'vin',
          bookName: 'Vinaya',
          type: AnnotationType.note,
          note: 'my note',
        ),
        _ann(
          id: '3',
          bookId: 'vin',
          bookName: 'Vinaya',
          type: AnnotationType.bookmark,
          name: 'saved place',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    // The "All" chip carries the total count (3); the per-type chips carry
    // their own counts (1 each).
    expect(find.text('3'), findsWidgets);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('book with more than 5 annotations starts collapsed; header '
      'expands it', (tester) async {
    await tester.pumpWidget(
      _build([
        for (var i = 1; i <= 7; i++)
          _ann(
            id: 'vin-$i',
            bookId: 'vin',
            bookName: 'Vinaya',
            exactText: 'quote $i',
          ),
        _ann(
          id: 'sutta-1',
          bookId: 'sutta',
          bookName: 'Suttanta',
          exactText: 'other book quote',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    // Collapsed by default: none of the 7 quotes is visible.
    expect(find.textContaining('quote 1'), findsNothing);
    expect(find.text('other book quote'), findsOneWidget);

    // Tapping the Vinaya header expands the group.
    await tester.tap(find.text('Vinaya'));
    await tester.pumpAndSettle();
    expect(find.textContaining('quote 7'), findsOneWidget);

    // Tapping again collapses it.
    await tester.tap(find.text('Vinaya'));
    await tester.pumpAndSettle();
    expect(find.textContaining('quote 7'), findsNothing);
  });

  testWidgets('book filter narrows the list to the selected book', (
    tester,
  ) async {
    await tester.pumpWidget(
      _build([
        _ann(id: '1', bookId: 'vin', bookName: 'Vinaya', exactText: 'vin quote'),
        _ann(
          id: '2',
          bookId: 'sutta',
          bookName: 'Suttanta',
          exactText: 'sutta quote',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    // Both books visible initially.
    expect(find.textContaining('vin quote'), findsOneWidget);
    expect(find.textContaining('sutta quote'), findsOneWidget);

    // Open the book filter panel and select "Vinaya" (the filter chips live
    // in a Wrap, so scope the tap to it to avoid the book section header).
    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Filter by book'), findsOneWidget);

    await tester.tap(
      find.descendant(of: find.byType(Wrap), matching: find.text('Vinaya')),
    );
    await tester.pumpAndSettle();

    // Only Vinaya's annotation remains.
    expect(find.textContaining('vin quote'), findsOneWidget);
    expect(find.textContaining('sutta quote'), findsNothing);

    // "All books" clears the filter.
    await tester.tap(find.text('All books'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sutta quote'), findsOneWidget);
  });
}
