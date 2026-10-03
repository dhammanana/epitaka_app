import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/database/dpd_dictionary_database.dart';
import 'package:epitaka/features/reader/utils/reader_word_hit_test.dart';

/// Tests for [quoteJoinCandidate]: the CST quote-run join rule.
///
/// CST texts write closing quote runs (and the verse elision mark `’`)
/// space-separated from the words: `oghamatarin ’’’ ti`, `dhammapuṇṇo ’ va`.
/// The dictionary only knows the joined form, so when a tapped word is
/// directly followed by `space + closing-quote-run + space + token`, the
/// candidate is `word + letters-of-token`, joined verbatim.
///
/// See kamma thread 20261003_quote_word_lookup.
void main() {
  // Helper: wordEnd = end of the first occurrence of [word] in [text].
  String? join(String text, String word) {
    final idx = text.indexOf(word);
    expect(idx, greaterThanOrEqualTo(0), reason: 'word "$word" not in text');
    return quoteJoinCandidate(text, idx + word.length, word);
  }

  group('quoteJoinCandidate — joining cases', () {
    test('triple closing quote before ti (the reported case)', () {
      final r = join(
        'Evaṃ khvāhaṃ, āvuso, appatiṭṭhaṃ anāyūhaṃ oghamatarin ’’’ ti.',
        'oghamatarin',
      );
      expect(r, 'oghamatarinti');
    });

    test('single quote-run length 1 before ti', () {
      final r = join('‘ Appatiṭṭhaṃ khvāhaṃ, āvuso, anāyūhaṃ oghamatarin ’ ti.', 'oghamatarin');
      expect(r, 'oghamatarinti');
    });

    test('verse elision: ’ va (eva elided)', () {
      final r = join('Dhammadhārako dhoreyho, dhammapuṇṇo ’ va puṇṇindu;', 'dhammapuṇṇo');
      expect(r, 'dhammapuṇṇova');
    });

    test('verse elision with punctuation after the token', () {
      final r = join('59. Mahānīvaraṇā ’ tīto, mahāmohasamūhato;', 'Mahānīvaraṇā');
      expect(r, 'Mahānīvaraṇātīto');
    });

    test('letters kept verbatim — no folding, no case change', () {
      final r = join('sabbaguṇasusampanno, sīlālaṅkāra ’ laṅkato;', 'sīlālaṅkāra');
      expect(r, 'sīlālaṅkāralaṅkato');
    });

    test('ascii apostrophe counts as closing quote', () {
      final r = join("oghamatarin ''' ti.", 'oghamatarin');
      expect(r, 'oghamatarinti');
    });

    test('non-letter junk inside the following token is stripped', () {
      // Source contains HTML like `’’’</b>ti` — the rendered text has no
      // tags, but the helper must strip any non-letter residue regardless.
      final r = join('anāyūhaṃ oghamatarin ’’’ tiādi,', 'oghamatarin');
      expect(r, 'oghamatarintiādi');
    });
  });

  group('quoteJoinCandidate — non-joining cases', () {
    test('opening quote run: never join across ‘‘', () {
      final r = join('Aṅguttaraṭīkāyaṃ pana ‘‘ sobhanaṃ gataṃ gamanaṃ', 'pana');
      expect(r, isNull);
    });

    test('single opening quote ‘: never join', () {
      final r = join('Vuttañhetaṃ bhagavatā ‘ yāvatā bhikkhave', 'bhagavatā');
      expect(r, isNull);
    });

    test('nothing after the word (end of text)', () {
      expect(join('… oghamatarin', 'oghamatarin'), isNull);
    });

    test('next token is only punctuation', () {
      expect(join('oghamatarin ’’’ .', 'oghamatarin'), isNull);
    });

    test('word followed by ordinary word (no quote run)', () {
      expect(join('anāyūhaṃ oghamatarin ti.', 'anāyūhaṃ'), isNull);
    });

    test('quote run at end of text with no following token', () {
      expect(join('oghamatarin ’’’', 'oghamatarin'), isNull);
    });

    test('NBSP gaps (\\s class, not just U+0020)', () {
      final r = join('oghamatarin\u00A0’’’\u00A0ti.', 'oghamatarin');
      expect(r, 'oghamatarinti');
    });

    test('display-script token is converted to Roman before joining', () {
      // Sinhala-rendered paragraph: the quotes survive conversion, the
      // words do not — the token must go through convertToRomanPali.
      final r = join('anāyūhaṃ oghamatarin ’’’ ති.', 'oghamatarin');
      expect(r, 'oghamatarinti');
    });
  });

  group('pickLookupWord — two-stage decision', () {
    DpdLookupRow row({List<int> headwords = const [], List<String> decon = const []}) {
      return DpdLookupRow(lookupKey: 'k', headwords: headwords, deconstructor: decon);
    }

    test('bare word resolves → bare word routed, candidate ignored', () {
      expect(
        pickLookupWord('khitto', 'khittoti', row(headwords: [1]), row(headwords: [2])),
        'khitto',
      );
    });

    test('bare misses, joined resolves → joined routed', () {
      expect(
        pickLookupWord('oghamatarin', 'oghamatarinti', null, row(headwords: [18419])),
        'oghamatarinti',
      );
    });

    test('bare row exists but empty → treated as miss, joined routed', () {
      expect(
        pickLookupWord('oghamatarin', 'oghamatarinti', row(), row(decon: ['ogha + tara'])),
        'oghamatarinti',
      );
    });

    test('both miss → bare word routed (usual empty state)', () {
      expect(pickLookupWord('xyz', 'xyztī', null, null), 'xyz');
    });

    test('no candidate → bare word routed', () {
      expect(pickLookupWord('khitto', null, null, null), 'khitto');
    });
  });

  group('hitTestWordAt wiring (real render path)', () {
    // Renders the sentence exactly like the reader does and runs the real
    // hitTestWordAt over it, so the joinedWord field is exercised end to
    // end — not just the pure helper. Pattern follows
    // probe_hit_test_widget_test.dart.
    /// Taps the middle of the first occurrence of [needle] in the rendered
    /// [line] and runs the real [hitTestWordAt]. The tap point comes from
    /// `getOffsetForCaret` because SelectionArea expands the paragraph's
    /// box (fraction-of-box taps would miss the painted text line).
    Future<ReaderWordHitResult?> tapWord(
      WidgetTester tester,
      String line,
      String needle, {
      Object? metaData,
    }) async {
      final contentKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: Listener(
              key: contentKey,
              child: SelectionArea(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: metaData == null
                      ? Text(line, style: const TextStyle(fontSize: 20))
                      : MetaData(
                          metaData: metaData,
                          child: Text(line,
                              style: const TextStyle(fontSize: 20)),
                        ),
                ),
              ),
            ),
          ),
        ),
      );

      // Find the RenderParagraph whose plain text is [line] — inside
      // SelectionArea the Text's own render object is a wrapper.
      RenderParagraph? paragraph;
      void visit(RenderObject node) {
        if (paragraph != null) return;
        if (node is RenderParagraph && node.text.toPlainText() == line) {
          paragraph = node;
          return;
        }
        node.visitChildren(visit);
      }

      visit(contentKey.currentContext!.findRenderObject()!);
      final render = paragraph!;
      final plain = render.text.toPlainText();
      final mid = plain.indexOf(needle) + needle.length ~/ 2;
      final local = render.getOffsetForCaret(
        TextPosition(offset: mid),
        const Rect.fromLTWH(0, 0, 1, 20),
      );
      final origin = render.localToGlobal(Offset.zero);
      return hitTestWordAt(contentKey, origin + local + const Offset(2, 10));
    }

    testWidgets('paragraph with quote run yields word + joinedWord',
        (tester) async {
      const line = 'Appatiṭṭhaṃ anāyūhaṃ oghamatarin ’’’ ti.';
      final hit = await tapWord(tester, line, 'oghamatarin');
      expect(hit, isNotNull);
      expect(hit!.word, 'oghamatarin');
      expect(hit.joinedWord, 'oghamatarinti');
    });

    testWidgets('translation segments get no joinedWord', (tester) async {
      const meta = ReaderLineMetadata(
        paraId: 1,
        segment: 'translation',
        langCode: 'en',
      );
      const line = 'He said oghamatarin ’’’ ti aloud.';
      final hit = await tapWord(tester, line, 'oghamatarin', metaData: meta);
      expect(hit, isNotNull);
      expect(hit!.word, 'oghamatarin');
      expect(hit.joinedWord, isNull);
    });
  });
}
