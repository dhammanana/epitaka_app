/// Regression: selection anchoring must map normalized offsets back into
/// STRIPPED-text space.
///
/// `buildAnchors` used to compose the normalized→stripped map with the
/// stripped→tagged map (mirroring the copy service, which cuts into the
/// *tagged* text and therefore needs tagged-space indices). Here the
/// composed map was used to cut into `strippedText` instead, so any
/// selection touching HTML markup (<b>, <i>, …) produced tagged-space
/// indices that overshoot `strippedText.length`, throwing RangeError inside
/// `buildAnchors`. That killed highlight/note creation entirely: the
/// palette / note editor never opened and nothing was ever saved or synced.
library;

import 'package:flutter_test/flutter_test.dart';

import '../lib/core/utils/pali_script_converter.dart';
import '../lib/features/annotations/services/selection_anchor_builder.dart';
import '../lib/features/reader/providers/reader_provider.dart'
    show LineData, ParagraphData;

void main() {
  test('anchors bold (<b>) Pāli text: no throw, stripped-space offsets', () {
    final paragraphs = [
      ParagraphData(
        paraId: 10,
        lines: const [
          LineData(
            lineId: 1,
            paliText: 'dhamma <b>khetta</b>',
            normalizedText: '',
          ),
        ],
      ),
    ];

    // SelectionArea reports the bold word as plain text.
    final anchors = SelectionAnchorBuilder.buildAnchors(
      paragraphs: paragraphs,
      plainText: 'khetta',
      script: Script.roman,
      enabledLangCodes: const {},
    );

    expect(anchors, hasLength(1));
    final a = anchors.single;
    expect(a.paraId, 10);
    expect(a.lineId, 1);
    expect(a.segment, 'pali');
    // Offsets are in the STRIPPED text "dhamma khetta" — "khetta" starts
    // at index 7 and is 6 characters long.
    expect(a.startOffset, 7);
    expect(a.endOffset, 13);
    expect(a.exactText, 'khetta');
  });

  test('anchors italic (<i>) translation text: no throw, correct offsets', () {
    final paragraphs = [
      ParagraphData(
        paraId: 3,
        lines: const [
          LineData(
            lineId: 2,
            paliText: 'dhamma',
            translations: {'en': 'the <i>teaching</i>'},
            normalizedText: '',
          ),
        ],
      ),
    ];

    final anchors = SelectionAnchorBuilder.buildAnchors(
      paragraphs: paragraphs,
      plainText: 'the teaching',
      script: Script.roman,
      enabledLangCodes: const {'en'},
    );

    expect(anchors, hasLength(1));
    final a = anchors.single;
    expect(a.segment, 'translation');
    expect(a.langCode, 'en');
    expect(a.startOffset, 0);
    expect(a.endOffset, 12);
    expect(a.exactText, 'the teaching');
  });

  test('selection spanning a closing tag boundary maps to stripped offsets', () {
    final paragraphs = [
      ParagraphData(
        paraId: 1,
        lines: const [
          LineData(
            lineId: 1,
            paliText: 'dhamma <b>khetta</b> dāna',
            normalizedText: '',
          ),
        ],
      ),
    ];

    // Selection boundary falls right after a closing </b> tag.
    final anchors = SelectionAnchorBuilder.buildAnchors(
      paragraphs: paragraphs,
      plainText: 'khetta dāna',
      script: Script.roman,
      enabledLangCodes: const {},
    );

    expect(anchors, hasLength(1));
    final a = anchors.single;
    expect(a.exactText, 'khetta dāna');
    // stripped = 'dhamma khetta dāna'; 'khetta dāna' spans [7, 18).
    expect(a.startOffset, 7);
    expect(a.endOffset, 18);
  });

  test('repeated phrase anchors to the VISIBLE paragraph, not the first occurrence',
      () {
    // Real Vin-iii end-of-book data: the closing formula sentence
    // "Yasmiṃ, upāli, vatthusmiṃ hoti saṅghassa bhaṇḍanaṃ …" repeats at
    // para 2701 line 4, para 2702 line 2, and para 2703 lines 5 & 7. The
    // anchor builder searches a window around the visible paragraph range
    // and used to take the FIRST `indexOf` match — so a highlight made at
    // the END of the book (para 2703, on screen) was anchored to the
    // EARLIER para 2701 instead, and the render path (which paints only
    // the exact stored paraId/lineId) showed nothing at the user's
    // location. At the top of a book the first occurrence is the right
    // one (unique opening text), which is why only the top worked.
    final paragraphs = [
      ParagraphData(
        paraId: 2701,
        lines: const [
          LineData(
            lineId: 4,
            paliText:
                'Yasmiṃ, upāli, vatthusmiṃ hoti saṅghassa bhaṇḍanaṃ '
                'kalaho viggaho vivādo saṅghabhedo saṅgharāji '
                'saṅghavavatthānaṃ saṅghanānākaraṇaṃ, saṅgho taṃ vatthuṃ '
                'avinicchinitvā amūlā mūlaṃ gantvā saṅghasāmaggiṃ karoti, '
                'adhammikā sā, upāli, saṅghasāmaggī.',
            normalizedText: '',
          ),
        ],
      ),
      ParagraphData(
        paraId: 2702,
        lines: const [
          LineData(
            lineId: 2,
            paliText:
                'Yasmiṃ, upāli, vatthusmiṃ hoti saṅghassa bhaṇḍanaṃ '
                'kalaho viggaho vivādo saṅghabhedo saṅgharāji '
                'saṅghavavatthānaṃ saṅghanānākaraṇaṃ, saṅgho taṃ vatthuṃ '
                'vinicchinitvā mūlā mūlaṃ gantvā saṅghasāmaggiṃ karoti, '
                'dhammikā sā, upāli, saṅghasāmaggī.',
            normalizedText: '',
          ),
        ],
      ),
      ParagraphData(
        paraId: 2703,
        lines: const [
          LineData(
            lineId: 5,
            paliText:
                'Yasmiṃ, upāli, vatthusmiṃ hoti saṅghassa bhaṇḍanaṃ '
                'kalaho viggaho vivādo saṅghabhedo saṅgharāji '
                'saṅghavavatthānaṃ saṅghanānākaraṇaṃ, saṅgho taṃ vatthuṃ '
                'avinicchinitvā amūlā mūlaṃ gantvā saṅghasāmaggiṃ karoti, '
                'ayaṃ vuccati, upāli, saṅghasāmaggī atthāpetā byañjanupetā.',
            normalizedText: '',
          ),
        ],
      ),
    ];

    // The user is scrolled to the LAST paragraph (list index 2) when they
    // make the highlight. The exact text they selected exists in para 2701
    // too — but that's off-screen, so the anchor must land on 2703.
    final anchors = SelectionAnchorBuilder.buildAnchors(
      paragraphs: paragraphs,
      plainText:
          'Yasmiṃ, upāli, vatthusmiṃ hoti saṅghassa bhaṇḍanaṃ kalaho '
          'viggaho vivādo saṅghabhedo saṅgharāji saṅghavavatthānaṃ '
          'saṅghanānākaraṇaṃ, saṅgho taṃ vatthuṃ avinicchinitvā amūlā '
          'mūlaṃ gantvā saṅghasāmaggiṃ karoti,',
      script: Script.roman,
      enabledLangCodes: const {},
      visibleStartIndex: 2,
      visibleEndIndex: 2,
    );

    expect(anchors, hasLength(1));
    expect(anchors.single.paraId, 2703);
    expect(anchors.single.lineId, 5);
  });

  test('without a visible range, first occurrence still wins (backward compat)',
      () {
    // When the caller supplies no visible range (both 0 — e.g. tests or
    // fallback call sites), behaviour must stay the legacy first-match so
    // nothing else changes for callers that don't track scroll position.
    final paragraphs = [
      ParagraphData(
        paraId: 100,
        lines: const [
          LineData(
            lineId: 1,
            paliText: 'Yasmiṃ, upāli, vatthusmiṃ hoti saṅghassa bhaṇḍanaṃ.',
            normalizedText: '',
          ),
        ],
      ),
      ParagraphData(
        paraId: 200,
        lines: const [
          LineData(
            lineId: 1,
            paliText: 'Yasmiṃ, upāli, vatthusmiṃ hoti saṅghassa bhaṇḍanaṃ.',
            normalizedText: '',
          ),
        ],
      ),
    ];

    final anchors = SelectionAnchorBuilder.buildAnchors(
      paragraphs: paragraphs,
      plainText: 'Yasmiṃ, upāli, vatthusmiṃ',
      script: Script.roman,
      enabledLangCodes: const {},
    );

    expect(anchors, hasLength(1));
    expect(anchors.single.paraId, 100);
  });
}
