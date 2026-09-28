/// Unit tests for the commentary quote matcher used by section copy.
///
/// Pins the Duṭṭhaṭṭhakasuttaṃ case: Sn verse 786 ("Vadanti ve…") is
/// explained by Pj-ii section 787, so equal-number matching pairs every
/// verse with the previous verse's commentary. The quote match must pick
/// the quoting section (787) over the number-equal one (786).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/features/reader/utils/commentary_quote_match.dart';

void main() {
  group('quoteMatchKey', () {
    test('strips tags, verse number and diacritics', () {
      final key = quoteMatchKey(
        '786. Vadanti ve <b>duṭṭhamanāpi</b> eke, athopi ve saccamanā vadanti;',
      );
      expect(key, startsWith('vadantivedutthamanapie'));
      expect(key.length, lessThanOrEqualTo(quoteMatchKeyLen));
      expect(key, isNot(contains('786')));
    });

    test('tiny lines give short keys', () {
      expect(quoteMatchKey('…pe…').length, lessThan(quoteMatchMinKeyLen));
    });
  });

  group('quoteMatchScore', () {
    const verse786 =
        'Vadanti ve duṭṭhamanāpi eke, athopi ve saccamanā vadanti;';
    const pj786Tail =
        'Saññaṃ pariññā vitareyya oghaṃ, pariggahesu muni nopeti vedaṃ.';
    const pj787Head =
        '787. <b>Vadanti ve duṭṭhamanāpī</b>ti duṭṭhaṭṭhakasuttaṃ. Kā uppatti?';
    const pj788Head = '788. Imañca gāthaṃ vatvā bhagavā ānandattheraṃ pucchi.';

    test('quoting section scores above threshold, others below', () {
      final key = quoteMatchKey('786. $verse786');
      final hit = quoteMatchScore(key, pj787Head);
      final missPrev = quoteMatchScore(key, pj786Tail);
      final missNext = quoteMatchScore(key, pj788Head);
      expect(hit, greaterThanOrEqualTo(quoteMatchThreshold));
      expect(missPrev, lessThan(quoteMatchThreshold));
      expect(missNext, lessThan(quoteMatchThreshold));
    });

    test('sandhi-split quotes still match', () {
      final key = quoteMatchKey('793. Upayo hi dhammesu upeti vādaṃ,');
      final window =
          '794. Yo pana tesaṃ dvinnaṃ bhāvena upayo hoti. '
          '<b>Dhammesu upeti vādan</b>ti ratto vā duṭṭho vā.';
      expect(
        quoteMatchScore(key, window),
        greaterThanOrEqualTo(quoteMatchThreshold),
      );
    });

    test('empty key scores zero', () {
      expect(quoteMatchScore('', pj787Head), 0);
    });
  });
}
