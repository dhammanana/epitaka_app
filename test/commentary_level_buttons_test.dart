/// The m a ṭ buttons: one look per level state, and a list for a level with
/// several books. Families built from `books` rows copied from epitaka.db.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/providers/pali_definition_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/reader/providers/reader_columns_controller.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:epitaka/features/reader/services/book_family_service.dart';
import 'package:epitaka/features/reader/services/paragraph_number_index.dart';
import 'package:epitaka/features/reader/widgets/commentary_level_buttons.dart';

final _families = buildBookFamilies([
  BookRefsRow(
    bookId: 'Vin-i',
    category: 'Mūla',
    atthaRef: 'Sp-i',
    tikaRef: 'Sp-t-i-a Sp-t-i-b Vjb-prj Vmv-i',
  ),
  BookRefsRow(
    bookId: 'Sp-i',
    category: 'Aṭṭhakathā',
    mulaRef: 'Vin-i',
    tikaRef: 'Sp-t-i-a Sp-t-i-b Vjb-prj Vmv-i',
  ),
  for (final tika in ['Sp-t-i-a', 'Sp-t-i-b', 'Vjb-prj', 'Vmv-i'])
    BookRefsRow(
      bookId: tika,
      category: 'Ṭīkā',
      mulaRef: 'Vin-i',
      atthaRef: 'Sp-i',
    ),
  BookRefsRow(bookId: 'Vism-i', category: 'Aṭṭhakathā', tikaRef: 'Vism-mht-i'),
  BookRefsRow(bookId: 'Vism-mht-i', category: 'Ṭīkā', mulaRef: 'Vism-i'),
]);

const _names = {
  'Sp-t-i-a': 'Sāratthadīpanī-Pārājika1-ṭīkā',
  'Sp-t-i-b': 'Sāratthadīpanī-Pārājika2-ṭīkā',
  'Vjb-prj': 'Vajirabuddhi-Pārājikavaṇṇanā',
  'Vmv-i': 'Vimativinodnī-Pārājika',
};

ReaderTabInfo _tab(String bookId) =>
    ReaderTabInfo(bookId: bookId, bookName: bookId);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  ReaderTabsState tabs,
) async {
  final container = ProviderContainer(
    overrides: [
      readerColumnsAvailableProvider.overrideWith((ref) => true),
      bookFamiliesProvider.overrideWith((ref) async => _families),
      canonBookNamesProvider.overrideWith((ref) async => _names),
      readerTabsProvider.overrideWith((ref) => ReaderTabsNotifier(tabs)),
      paragraphNumberIndexProvider.overrideWith(
        (ref, bookId) async =>
            const ParagraphNumberIndex(entries: [], lastParaId: 0),
      ),
      paragraphLinksProvider.overrideWith((ref, books) async => []),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(body: Center(child: CommentaryLevelButtons())),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

BoxDecoration _box(WidgetTester tester, String level) =>
    tester
            .widget<Container>(find.byKey(ValueKey('commentary-level-$level')))
            .decoration!
        as BoxDecoration;

Color _letterColor(WidgetTester tester, String level) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey('commentary-level-$level')),
        matching: find.byType(Text),
      ),
    )
    .style!
    .color!;

void main() {
  testWidgets('the own level is outlined and a shown level is filled', (
    tester,
  ) async {
    await _pump(
      tester,
      ReaderTabsState(
        tabs: [_tab('Vin-i'), _tab('Sp-i')],
        columns: const ['Vin-i', 'Sp-i'],
      ),
    );
    expect(_box(tester, 'mula').border, isNotNull);
    expect(_box(tester, 'mula').color, isNull);
    expect(_box(tester, 'attha').color, isNotNull);
    expect(_box(tester, 'attha').border, isNull);
    expect(_box(tester, 'tika').color, isNull);
    expect(_box(tester, 'tika').border, isNull);
  });

  testWidgets('a level with no book is greyed out', (tester) async {
    await _pump(tester, ReaderTabsState(tabs: [_tab('Vism-i')]));
    // Vism-i sits at the mūla level and has a ṭīkā but no aṭṭhakathā.
    expect(_letterColor(tester, 'attha').a, lessThan(0.5));
    expect(_letterColor(tester, 'tika').a, 1);
  });

  testWidgets('a level with several books lists them and opens the chosen', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      ReaderTabsState(tabs: [_tab('Vin-i')]),
    );
    await tester.tap(find.byKey(const ValueKey('commentary-level-tika')));
    await tester.pumpAndSettle();
    expect(find.byType(CheckedPopupMenuItem<String>), findsNWidgets(4));
    for (final name in _names.values) {
      expect(find.text(name), findsOneWidget);
    }

    await tester.tap(find.text('Vajirabuddhi-Pārājikavaṇṇanā'));
    await tester.pumpAndSettle();
    expect(container.read(readerTabsProvider).columns, ['Vin-i', 'Vjb-prj']);
  });
}
