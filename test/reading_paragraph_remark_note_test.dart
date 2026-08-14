/// Regression: translation remarks (notes from each translation DB's
/// `translation_remarks` table) must render as a small tappable MARK under
/// the affected line's translation — never as inline note text that reads
/// like a second translation. Tapping the mark opens the full remark in a
/// dialog. Lines without a remark must not render any mark.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/utils/app_localizations.dart';
import '../lib/core/utils/pali_script_converter.dart';
import '../lib/features/reader/providers/reader_provider.dart'
    show LineData, ParagraphData;
import '../lib/shared/widgets/reading_paragraph.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        localizationsDelegates: const [AppLocalizationsDelegate()],
        supportedLocales: AppLocalizationsDelegate.supportedLocales,
        home: Scaffold(body: child),
      );

  /// Pump the widget and settle frames. Localizations load asynchronously,
  /// so the paragraph's build (which reads localized labels) completes one
  /// frame after the first pump.
  Future<void> pumpParagraph(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(wrap(child));
    await tester.pumpAndSettle();
  }

  const remark = 'In this context it acts as a linker, not a contrastive '
      '"but".';

  ParagraphData paragraph({Map<String, String>? remarks, bool secondLine = false}) =>
      ParagraphData(
        paraId: 1,
        lines: [
          LineData(
            lineId: 1,
            paliText: 'ca pana',
            normalizedText: '',
            translations: const {'en': 'and indeed'},
            remarks: remarks ?? const {'en': remark},
          ),
          if (secondLine)
            LineData(
              lineId: 2,
              paliText: 'dhamma',
              normalizedText: '',
              translations: const {'en': 'dhamma'},
            ),
        ],
      );

  /// The note mark chip: a tappable container with the "Translation note"
  /// label and an info icon.
  Finder noteMark() => find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.data == 'Translation note' &&
            (w.style?.fontSize ?? 0) <= 10,
      );

  /// The remark body rendered inline (italic, 12px — the old behavior).
  Finder inlineNoteText() => find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.style?.fontStyle == FontStyle.italic &&
            w.style?.fontSize == 12,
      );

  testWidgets('lineByLine: remark renders as a mark, not inline text', (
    tester,
  ) async {
    await pumpParagraph(
      tester,
      ReadingParagraph(
        paragraph: paragraph(),
        script: Script.roman,
        pageNumberingSystem: 'vri',
        enabledLangCodes: const ['en'],
      ),
    );

    expect(noteMark(), findsOneWidget,
        reason: 'a note mark must appear under the line with a remark');
    expect(inlineNoteText(), findsNothing,
        reason: 'the remark must not render inline like a translation');
  });

  testWidgets('tapping the mark opens a dialog with the remark text', (
    tester,
  ) async {
    await pumpParagraph(
      tester,
      ReadingParagraph(
        paragraph: paragraph(),
        script: Script.roman,
        pageNumberingSystem: 'vri',
        enabledLangCodes: const ['en'],
      ),
    );

    await tester.tap(noteMark());
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(remark), findsOneWidget,
        reason: 'the dialog must show the full remark text');
  });

  testWidgets('lineByLine: line without remark renders no mark', (
    tester,
  ) async {
    await pumpParagraph(
      tester,
      ReadingParagraph(
        paragraph: paragraph(remarks: const {}),
        script: Script.roman,
        pageNumberingSystem: 'vri',
        enabledLangCodes: const ['en'],
      ),
    );

    expect(noteMark(), findsNothing, reason: 'no mark without a remark');
  });

  testWidgets('hideJoinLines (translations hidden): no remark mark renders', (
    tester,
  ) async {
    await pumpParagraph(
      tester,
      ReadingParagraph(
        paragraph: paragraph(secondLine: true),
        script: Script.roman,
        pageNumberingSystem: 'vri',
        enabledLangCodes: const ['en'],
        displayMode: ParagraphDisplayMode.hideJoinLines,
      ),
    );

    expect(noteMark(), findsNothing,
        reason: 'hideJoinLines shows no translations, so no remark mark');
  });

  testWidgets('sideBySide: remark mark renders in the translation column', (
    tester,
  ) async {
    await pumpParagraph(
      tester,
      ReadingParagraph(
        paragraph: paragraph(),
        script: Script.roman,
        pageNumberingSystem: 'vri',
        enabledLangCodes: const ['en'],
        displayMode: ParagraphDisplayMode.sideBySide,
      ),
    );

    expect(noteMark(), findsOneWidget,
        reason: 'side-by-side mode must still show the remark mark');
    expect(inlineNoteText(), findsNothing);
  });

  testWidgets('translation hidden: no remark mark renders', (tester) async {
    await pumpParagraph(
      tester,
      ReadingParagraph(
        paragraph: paragraph(),
        script: Script.roman,
        pageNumberingSystem: 'vri',
        enabledLangCodes: const ['en'],
        showTranslation: false,
      ),
    );

    expect(noteMark(), findsNothing,
        reason: 'no mark when the translation itself is hidden');
  });
}
