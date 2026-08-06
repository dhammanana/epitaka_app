/// Verifies that inlined book-link (commentary) chips are rendered below a
/// linked Pāli line only when `showBookLinks` is enabled, and hidden when
/// the setting is turned off in Reading Options.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/reader/providers/reader_provider.dart'
    show LineData, ParagraphData;
import '../lib/features/reader/data/book_link_data.dart';
import '../lib/features/reader/widgets/book_link_chip.dart';
import '../lib/core/utils/pali_script_converter.dart';
import '../lib/shared/widgets/reading_paragraph.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  ParagraphData paragraphWithLink() => ParagraphData(
        paraId: 1,
        lines: const [
          LineData(lineId: 1, paliText: 'dhamma', normalizedText: ''),
        ],
      );

  ParaBookLinks linksForLine(int lineId) => {
        lineId: [
          BookLinkData(
            word: 'dhamma',
            linkedBookId: 'dn1a',
            linkedParaId: 2,
            linkedLineId: 1,
            isSource: true,
          ),
        ],
      };

  testWidgets('book-link chip is shown when showBookLinks is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ReadingParagraph(
          paragraph: paragraphWithLink(),
          script: Script.roman,
          pageNumberingSystem: 'vri',
          enabledLangCodes: const [],
          bookLinks: linksForLine(1),
          showBookLinks: true,
        ),
      ),
    );

    expect(find.byType(BookLinkChip), findsOneWidget);
  });

  testWidgets('book-link chip is hidden when showBookLinks is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ReadingParagraph(
          paragraph: paragraphWithLink(),
          script: Script.roman,
          pageNumberingSystem: 'vri',
          enabledLangCodes: const [],
          bookLinks: linksForLine(1),
          showBookLinks: false,
        ),
      ),
    );

    expect(find.byType(BookLinkChip), findsNothing);
  });
}
