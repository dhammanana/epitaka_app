import 'dart:io';

import 'package:epitaka/features/sutta_jump/services/sutta_code_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Lines copied from the generated assets/sutta_codes.tsv.
const _fixture = '''
# header line
an1\tA-i\t3\tAN1\tekakanipātapāḷi\t
an1.1\tA-i\t3\tAN1.1\trūpādivagga\tAN1.1-10
an1.1-10\tA-i\t3\tAN1.1-10\trūpādivagga\t
an1.5\tA-i\t10\tAN1.5\trūpādivagga\tAN1.1-10
an2.11-21\tA-ii\t35\tAN2.11-21\tadhikaraṇavagga\t
an2.21\tA-ii\t58\tAN2.21\tadhikaraṇavagga\tAN2.11-21
an10\tA-x\t3\tAN10\tdasakanipātapāḷi\t
an10.1\tA-x\t3\tAN10.1\tkimatthiyasutta\t
mn10\tM-i\t280\tMN10\tmahāsatipaṭṭhānasutta\t
sn1.1\tS-i\t3\tSN1.1\toghataraṇasutta\t
sn1.1-10\tS-i\t3\tSN1.1-10\tnaḷavagga\t
sn1.3\tS-i\t17\tSN1.3\tupanīyasutta\t
thi28\tThī\t175\tTHI28\tsāmātherīgāthā\t\tTHIG2.10
thig2.10\tThī\t175\tTHI28\tsāmātherīgāthā\t\tTHIG2.10
''';

void main() {
  final codes = parseSuttaCodes(_fixture);

  group('normaliseCode', () {
    test('ignores case and spaces', () {
      expect(normaliseCode('MN 10'), 'mn10');
      expect(normaliseCode('Mn10'), 'mn10');
      expect(normaliseCode(' mn 1 0 '), 'mn10');
    });

    test('treats en and em dashes as hyphens', () {
      expect(normaliseCode('AN1.1–10'), 'an1.1-10');
      expect(normaliseCode('AN1.1—10'), 'an1.1-10');
    });
  });

  group('lookupSuttaCodes', () {
    test('parse skips the header', () {
      expect(codes.length, 14);
    });

    test('a CRLF copy of the map parses the same (Windows checkout)', () {
      final crlf = parseSuttaCodes(_fixture.replaceAll('\n', '\r\n'));
      expect(crlf['mn10']!.label, 'MN10');
      expect(crlf['thi28']!.altCode, 'THIG2.10');
      expect(crlf.length, codes.length);
    });

    test('labels show the SuttaCentral code or the range', () {
      expect(lookupSuttaCodes(codes, 'thig2.10').single.label, 'THI28 = THIG2.10');
      expect(lookupSuttaCodes(codes, 'thi28').single.label, 'THI28 = THIG2.10');
      expect(lookupSuttaCodes(codes, 'an1.5').single.label, 'AN1.5 (AN1.1-10)');
      expect(lookupSuttaCodes(codes, 'mn10').first.label, 'MN10');
    });

    test('MN 10 finds mn10', () {
      final r = lookupSuttaCodes(codes, 'MN 10');
      expect(r.first.bookId, 'M-i');
      expect(r.first.paraId, 280);
    });

    test('exact sutta beats the vagga range', () {
      final r = lookupSuttaCodes(codes, 'sn1.3');
      expect(r.first.displayCode, 'SN1.3');
      expect(r.first.paraId, 17);
    });

    test('exact match comes first even when a longer code is listed first', () {
      final reversed = parseSuttaCodes(_fixture.split('\n').reversed.join('\n'));
      final r = lookupSuttaCodes(reversed, 'sn1.1');
      expect(r.first.displayCode, 'SN1.1');
      expect(r.map((t) => t.displayCode), contains('SN1.1-10'));
    });

    test('a code inside a range opens its own paragraph', () {
      final r = lookupSuttaCodes(codes, 'an1.5');
      expect((r.single.bookId, r.single.paraId), ('A-i', 10));
      expect(r.single.rangeCode, 'AN1.1-10');
      expect(r.single.title, 'rūpādivagga');
    });

    test('suttas inside a range show only as the exact match', () {
      final shown = lookupSuttaCodes(codes, 'an1').map((t) => t.displayCode);
      expect(shown, isNot(contains('AN1.5')));
      expect(lookupSuttaCodes(codes, 'an2.21').first.rangeCode, 'AN2.11-21');
    });

    test('prefix list keeps natural order: an1… before an10…', () {
      final shown = lookupSuttaCodes(codes, 'an1').map((t) => t.displayCode).toList();
      expect(shown.first, 'AN1');
      expect(shown.indexOf('AN1.1-10'), lessThan(shown.indexOf('AN10')));
      expect(shown.indexOf('AN10'), lessThan(shown.indexOf('AN10.1')));
    });

    test('one line per target', () {
      final shown = lookupSuttaCodes(codes, 'an1.').map((t) => t.displayCode).toList();
      expect(shown, ['AN1.1-10']);
    });

    test('unknown code and empty input give nothing', () {
      expect(lookupSuttaCodes(codes, 'zz99'), isEmpty);
      expect(lookupSuttaCodes(codes, '  '), isEmpty);
    });
  });

  test('the shipped asset resolves real codes, DPD before SuttaCentral', () {
    final real = parseSuttaCodes(File(suttaCodesAsset).readAsStringSync());
    expect(real.length, greaterThan(13000));

    final mn10 = lookupSuttaCodes(real, 'mn10').first;
    expect((mn10.bookId, mn10.paraId), ('M-i', 280));

    final ja431 = lookupSuttaCodes(real, 'ja431').first;
    expect((ja431.bookId, ja431.paraId), ('Ja-i', 5032));

    final thag = lookupSuttaCodes(real, 'thag1.1').first;
    expect((thag.bookId, thag.paraId, thag.displayCode), ('Th', 11, 'TH1'));

    final an221 = lookupSuttaCodes(real, 'an2.21').first;
    expect((an221.paraId, an221.rangeCode), (58, 'AN2.11-21'));

    // THIG2.10 is SuttaCentral's code for DPD's THI28.
    final thi28 = lookupSuttaCodes(real, 'thi28').first;
    final thig = lookupSuttaCodes(real, 'THIG 2.10').first;
    expect((thig.bookId, thig.paraId), (thi28.bookId, thi28.paraId));
    expect(thi28.label, 'THI28 = THIG2.10');

    // SuttaCentral calls AN3.49 'an3.48'; the DPD code must win.
    final an348 = lookupSuttaCodes(real, 'an3.48').first;
    expect((an348.displayCode, an348.paraId), ('AN3.48', 370));
  });
}
