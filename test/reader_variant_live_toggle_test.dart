/// Regression test for live re-render of variant readings.
///
/// Toggling "Show variant readings" must update the reader text
/// immediately, with no interaction. The reader list memoizes paragraph
/// widgets and only rebuilds them when `_ReaderContentConfig` changes —
/// the strip flag was missing from that config, so toggling the setting
/// left every unchanged paragraph showing stale text until something
/// else (a tap, a scroll highlight) rebuilt it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/reader/providers/reader_provider.dart'
    show LineData, ParagraphData, ReaderDataState;
import 'package:epitaka/features/reader/widgets/reader_content_list.dart';
import 'package:epitaka/features/reader/widgets/reader_highlight_bundle.dart';

void main() {
  final data = ReaderDataState(
    bookId: 'mn1',
    paragraphs: [
      ParagraphData(
        paraId: 1,
        lines: const [
          LineData(
            lineId: 1,
            paliText: 'evaṃ me sutaṃ [iti] ekaṃ samayaṃ',
            normalizedText: '',
          ),
        ],
      ),
    ],
  );

  Future<void> pumpReader(
    WidgetTester tester, {
    required bool strip,
    bool hasQuery = false,
  }) async {
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
          body: ReaderContentList(
            bookId: 'mn1',
            data: data,
            settings: AppSettings(stripVariantAnnotations: strip),
            colors: ColorScheme.fromSeed(seedColor: Colors.blue),
            paliColor: Colors.black87,
            translationColor: Colors.black54,
            enabledLangs: const [],
            langTypographies: const {},
            itemScrollController: ItemScrollController(),
            itemPositionsListener: ItemPositionsListener.create(),
            scrollOffsetListener: ScrollOffsetListener.create(),
            onScrollDelta: (_) {},
            highlightBundle: hasQuery
                ? const ReaderHighlightBundle(
                    bookId: 'mn1',
                    searchQuery: 'sutaṃ',
                  )
                : const ReaderHighlightBundle(bookId: 'mn1'),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('hidden (strip=true): variant text is omitted', (tester) async {
    await pumpReader(tester, strip: true);
    expect(find.textContaining('iti', findRichText: true), findsNothing);
  });

  testWidgets('toggling the setting re-renders without interaction', (
    tester,
  ) async {
    await pumpReader(tester, strip: true);
    expect(find.textContaining('iti', findRichText: true), findsNothing);

    // Same widget position → didUpdateWidget path, exactly like the real
    // reader rebuilding from settingsProvider. No tap, no scroll, no
    // highlight change: the memo alone must invalidate.
    await pumpReader(tester, strip: false);
    // Variant renders inline, CST-style with brackets.
    expect(find.textContaining('[iti]', findRichText: true), findsOneWidget);

    // And back.
    await pumpReader(tester, strip: true);
    expect(find.textContaining('iti', findRichText: true), findsNothing);
  });

  /// Walk every rendered RichText and return the TextSpan whose text
  /// contains [needle] (null when absent).
  TextSpan? spanContaining(WidgetTester tester, String needle) {
    TextSpan? found;
    void walk(InlineSpan span) {
      if (span is TextSpan) {
        if (span.text != null && span.text!.contains(needle)) {
          found = span;
        }
        for (final child in span.children ?? const <InlineSpan>[]) {
          walk(child);
        }
      }
    }

    for (final w in find.byType(RichText).evaluate()) {
      final rich = w.widget as RichText;
      walk(rich.text as TextSpan);
    }
    return found;
  }

  testWidgets('variant colours survive an active search highlight', (
    tester,
  ) async {
    await pumpReader(tester, strip: false, hasQuery: true);

    // The query ('sutaṃ') matches, so the line renders through the
    // highlight path — the variant reading must STILL carry its recessive
    // background + text colour.
    final variantSpan = spanContaining(tester, 'iti');
    expect(variantSpan, isNotNull, reason: 'variant reading is rendered');
    expect(
      variantSpan!.style?.backgroundColor,
      isNotNull,
      reason: 'variant background survives the search highlight',
    );
    expect(
      variantSpan.style!.color,
      isNot(equals(Colors.black87)),
      reason:
          'variant text colour is the recessive derived colour, not the '
          'base line colour (test runs light mode, paliColor: black87)',
    );

    // And the bracket characters themselves are unstyled.
    final bracketSpan = spanContaining(tester, '[');
    expect(bracketSpan!.style?.backgroundColor, isNull);
  });
}
