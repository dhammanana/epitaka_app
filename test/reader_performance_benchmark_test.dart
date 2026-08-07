/// Performance benchmark for the reader + dictionary hot paths.
///
/// This is NOT a pass/fail functional test — it measures wall-clock time for
/// the operations that dominate the reader's per-frame work (Pāli script
/// conversion, HTML parsing, paragraph widget builds) and the dictionary
/// sheet's per-keystroke work (velthuis conversion, HTML stripping,
/// clickable-word linking).
///
/// Run with:
///   flutter test test/reader_performance_benchmark_test.dart
///
/// Timings are printed to stdout. Use `--reporter expanded` to see them.
/// Compare runs before/after an optimization to verify the change helps.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/utils/pali_script_converter.dart';
import '../lib/core/utils/pali_text_utils.dart';
import '../lib/core/utils/velthuis.dart';
import '../lib/features/dictionary/widgets/dictionary_search_shared.dart';
import '../lib/features/reader/providers/reader_provider.dart'
    show LineData, ParagraphData, ParagraphHeading;
import '../lib/shared/utils/html_text_parser.dart';
import '../lib/shared/widgets/reading_paragraph.dart';

/// A realistic Pāli line as stored in the database (with HTML markup).
const _paliLineWithHtml = 'evaṃ me sutaṃ — <b>ekaṃ samayaṃ</b> bhagavā '
    'sāvatthiyaṃ viharati <i>jetavane</i> anāthapiṇḍikassa ārāme. '
    'tatra kho bhagavā bhikkhū āmantesi: "bhikkhavo" ti.';

/// A longer line (commentary length) to stress conversion.
const _longPaliLine =
    'idha pana bhikkhave bhikkhu kāye kāyānupassī viharati ātāpī '
    'sampajāno satimā vineyya loke abhijjhādomanassaṃ — tassa kāye '
    'kāyānupassino viharato yo kāyasmiṃ chando so pahīyati.';

/// A translation line (may contain HTML).
const _translationLine =
    'Thus have I heard — on one occasion the Blessed One was dwelling '
    'at Sāvatthī in <b>Jeta\'s Grove</b>, the park of Anāthapiṇḍika. '
    'There the Blessed One addressed the bhikkhus: "Bhikkhus!"';

/// A DPD-style meaning_html fragment (the dictionary's most expensive render).
const _dpdMeaningHtml =
    '<summary>free from desire</summary><p>One who has destroyed the '
    '<b>cankers</b> (āsava) and is <i>without desire</i> for future '
    'existence. See <a href="lookup://khina">khīṇa</a>.</p>'
    '<details><summary>Grammar</summary><p>khīṇa + āsa + va → k+hi+ṇa+ā+sa+va '
    '<b>Root:</b> <i>khi</i> (to destroy)</p></details>';

/// Sample Pāli text with a variant reading (bracketed segment).
const _paliWithVariant =
    'evaṃ me sutaṃ [evaṃ me sutam] ekaṃ samayaṃ bhagavā rājagahe viharati '
    'gijjhakūṭe pabbate.';

void main() {
  const iterations = 2000;
  final samples = <String>[
    _paliLineWithHtml,
    _longPaliLine,
    _translationLine,
    _paliWithVariant,
  ];

  group('script conversion (hot path: every paragraph build)', () {
    for (final script in [Script.roman, Script.sinhala, Script.taitham]) {
      test('convertPaliToScriptPreservingHtml ×$iterations ($script)', () {
        // Warm the memo caches.
        for (final s in samples) {
          convertPaliToScriptPreservingHtml(s, script);
        }
        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          for (final s in samples) {
            convertPaliToScriptPreservingHtml(s, script);
          }
        }
        sw.stop();
        final us = sw.elapsedMicroseconds;
        // ignore: avoid_print
        print('[BENCH] convertPaliToScriptPreservingHtml $script: '
            '${us ~/ iterations}µs/round (${samples.length} samples)');
      });

      test('convertPaliToScriptSegments ×$iterations ($script)', () {
        for (final s in samples) {
          convertPaliToScriptSegments(s, script);
        }
        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          for (final s in samples) {
            convertPaliToScriptSegments(s, script);
          }
        }
        sw.stop();
        final us = sw.elapsedMicroseconds;
        // ignore: avoid_print
        print('[BENCH] convertPaliToScriptSegments $script: '
            '${us ~/ iterations}µs/round (${samples.length} samples)');
      });
    }

    test('convertPaliToScriptSegments (unique strings) ×2000', () {
      // Conversion of *different* lines each time — the real scroll case,
      // where the cache (if any) never hits.
      final sw = Stopwatch()..start();
      for (var i = 0; i < 2000; i++) {
        convertPaliToScriptSegments(
          'para $i evaṃ me sutaṃ [variant $i] ekaṃ samayaṃ '
          '<b>bhagavā</b> sāvatthiyaṃ viharati',
          Script.sinhala,
        );
      }
      sw.stop();
      // ignore: avoid_print
      print('[BENCH] convertPaliToScriptSegments unique: '
          '${sw.elapsedMicroseconds ~/ 2000}µs/line (uncached)');
    });
  });

  group('HTML parsing', () {
    test('HtmlTextParser.parse ×$iterations', () {
      for (final s in samples) {
        HtmlTextParser.parse(s, const TextStyle(fontSize: 19));
      }
      final sw = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        for (final s in samples) {
          HtmlTextParser.parse(s, const TextStyle(fontSize: 19));
        }
      }
      sw.stop();
      final us = sw.elapsedMicroseconds;
      // ignore: avoid_print
      print('[BENCH] HtmlTextParser.parse: ${us ~/ iterations}µs/round');
    });

    test('stripHtmlToPlainText ×$iterations', () {
      final sw = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        stripHtmlToPlainText(_dpdMeaningHtml);
      }
      sw.stop();
      final us = sw.elapsedMicroseconds;
      // ignore: avoid_print
      print('[BENCH] stripHtmlToPlainText: ${us ~/ iterations}µs/call');
    });
  });

  group('dictionary textbox flow', () {
    test('velthuis ×20000 (per keystroke conversion)', () {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 20000; i++) {
        velthuis('dhamma.m');
        velthuis('evam me sutam');
        velthuis('rājagaha');
      }
      sw.stop();
      // ignore: avoid_print
      print('[BENCH] velthuis: ${sw.elapsedMicroseconds ~/ 20000}µs/3-calls');
    });
  });

  group('ReadingParagraph widget build (scroll frame cost)', () {
    ParagraphData paragraph({int paraId = 1, int lineCount = 4}) {
      return ParagraphData(
        paraId: paraId,
        heading: paraId == 1
            ? ParagraphHeading(title: 'Section', level: 1, paraId: 1)
            : null,
        lines: List.generate(lineCount, (i) {
          return LineData(
            lineId: i + 1,
            paliText: i == 0 ? _longPaliLine : _paliLineWithHtml,
            translations: {'en': _translationLine},
            normalizedText: '',
          );
        }),
      );
    }

    testWidgets('pump a 30-paragraph list, measure frame time', (tester) async {
      final paragraphs = List.generate(30, (i) => paragraph(paraId: i + 1));
      final sw = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                for (final p in paragraphs)
                  RepaintBoundary(
                    child: ReadingParagraph(
                      paragraph: p,
                      script: Script.roman,
                      pageNumberingSystem: 'vri',
                      enabledLangCodes: const ['en'],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      sw.stop();
      // ignore: avoid_print
      print('[BENCH] ReadingParagraph 30-paragraph first build: '
          '${sw.elapsedMilliseconds}ms');

      // Second build (rebuild cost — happens on every scroll-driven rebuild).
      final sw2 = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                for (final p in paragraphs)
                  RepaintBoundary(
                    child: ReadingParagraph(
                      paragraph: p,
                      script: Script.roman,
                      pageNumberingSystem: 'vri',
                      enabledLangCodes: const ['en'],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      sw2.stop();
      // ignore: avoid_print
      print('[BENCH] ReadingParagraph 30-paragraph rebuild: '
          '${sw2.elapsedMilliseconds}ms');
    });
  });
}
