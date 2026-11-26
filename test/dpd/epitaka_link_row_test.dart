/// The "Open in ePitaka" row of the DPD sutta block, and ePitaka links in a
/// dictionary card. Sutta rows are copied from dpd.db (`sutta_info`).
library;

import 'package:epitaka/features/dpd/database/dpd_database.dart';
import 'package:epitaka/features/dpd/database/sutta_info_extensions.dart';
import 'package:epitaka/features/dpd/widgets/dict_html_card.dart';
import 'package:epitaka/features/dpd/widgets/sutta_info_section.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sutta_link_harness.dart';

const _an4126 = SuttaInfoData(
  dpdCode: 'AN4.126',
  dpdSutta: 'dutiyamettāsutta',
  dpdSuttaVar: '',
  scCode: 'AN4.126',
  cstCode: 'AN4.3.3.6',
  cstVagga: '3. Bhayavaggo',
  scVagga: '13. Bhayavagga',
  bjtVagga: '2. kesivaggo',
);
const _sn1 = SuttaInfoData(
  dpdCode: 'SN1',
  dpdSutta: 'devatāsaṃyutta',
  dpdSuttaVar: '',
  scCode: 'SN1.1',
  cstCode: 'SN1.1.1.1',
  cstVagga: '1. Naḷavaggo',
  scVagga: '1. Naḷavagga',
  bjtVagga: '1. naḷavaggo',
);
const _mn1To50 = SuttaInfoData(
  dpdCode: 'MN1-50',
  dpdSutta: 'mūlapaṇṇāsapāḷi',
  dpdSuttaVar: 'mūlapaṇṇāsaka 1',
  scCode: 'MN1',
  cstCode: 'MN1.1.1',
  cstVagga: '1. Mūlapariyāyavaggo',
  scVagga: 'Mūlapariyāyavagga',
  bjtVagga: '1. mūlapariyāyavaggo',
);
const _th1 = SuttaInfoData(
  dpdCode: 'TH1',
  dpdSutta: 'subhūtittheragāthā',
  dpdSuttaVar: '',
  scCode: 'THAG1.1',
  cstCode: 'KN8.1.1',
  cstVagga: '1. Paṭhamavaggo',
  scVagga: 'Ekakanipāta, Paṭhamavagga',
  bjtVagga: '4. mahāvaggo',
);
// A real row whose SuttaCentral code is one lower than its DPD (CST) code.
const _sn45172 = SuttaInfoData(
  dpdCode: 'SN45.172',
  dpdSutta: 'oghasutta',
  dpdSuttaVar: '',
  scCode: 'SN45.171',
  cstCode: 'SN5.1.8.1',
  cstVagga: '8. Oghavaggo',
  scVagga: '14. Oghavagga',
  bjtVagga: '16. oghavaggo',
);
// A real row with no SuttaCentral code at all.
const _sn4636 = SuttaInfoData(
  dpdCode: 'SN46.36',
  dpdSutta: 'yonisomanasikārasutta',
  dpdSuttaVar: '',
  scCode: '',
  cstCode: 'SN5.2.4.6',
  cstVagga: '4. Nīvaraṇavaggo',
  scVagga: '',
  bjtVagga: '',
);

void main() {
  group('epitakaLinkCode', () {
    test('the DPD code, in lower case', () {
      expect(_an4126.epitakaLinkCode, 'an4.126');
      expect(_th1.epitakaLinkCode, 'th1');
    });

    test('the DPD code wins where the SuttaCentral code is one off', () {
      expect(_sn45172.epitakaLinkCode, 'sn45.172');
    });

    test('a row with no SuttaCentral code still links by its DPD code', () {
      expect(_sn4636.epitakaLinkCode, 'sn46.36');
    });

    test('a group page has no code', () {
      expect(_sn1.epitakaLinkCode, isNull);
      expect(_mn1To50.epitakaLinkCode, isNull);
    });

    test('a paṇṇāsaka is a group page by its name alone', () {
      expect(_mn1To50.isPannasaka, isTrue);
      expect(_an4126.isPannasaka, isFalse);
    });
  });

  testWidgets('the row shows on a sutta, not on a group page', (tester) async {
    final db = await seedSuttaLinkDb();
    addTearDown(db.close);
    await pumpSuttaLinkApp(
      tester,
      db,
      home: SingleChildScrollView(
        child: Column(
          children: const [
            SuttaInfoSection(suttaInfo: _an4126, headwordId: 1, lemma1: 'a'),
            SuttaInfoSection(suttaInfo: _sn1, headwordId: 2, lemma1: 's'),
          ],
        ),
      ),
    );
    // One row for AN4.126, none for SN1.
    expect(find.text('Open in ePitaka'), findsOneWidget);
    expect(find.text('ePitaka'), findsOneWidget);
  });

  testWidgets('a tap on the row opens the sutta in a reader tab', (
    tester,
  ) async {
    final db = await seedSuttaLinkDb();
    addTearDown(db.close);
    final container = await pumpSuttaLinkApp(
      tester,
      db,
      home: const SingleChildScrollView(
        child: SuttaInfoSection(suttaInfo: _an4126, headwordId: 1, lemma1: 'a'),
      ),
    );

    await tester.tap(find.text('Open in ePitaka'));
    await settleLink(tester);

    final tab = container.read(readerTabsProvider).activeTab!;
    expect((tab.bookId, tab.initialParaId), ('A-iv', 1114));
  });

  testWidgets('an ePitaka link in a dictionary card opens in the app', (
    tester,
  ) async {
    final db = await seedSuttaLinkDb();
    addTearDown(db.close);
    final container = await pumpSuttaLinkApp(
      tester,
      db,
      home: SingleChildScrollView(
        child: DictHtmlCard(
          dictId: 'mw',
          baseStyle: const TextStyle(fontSize: 14),
          entries: const [
            DictEntry(
              id: 1,
              dictId: 'mw',
              word: 'mettā',
              definitionHtml:
                  '<p><a href="epitaka://sutta?code=an4.126">the sutta</a></p>',
            ),
          ],
        ),
      ),
    );

    await tester.tapAt(
      tester.getTopLeft(find.textContaining('the sutta', findRichText: true)) +
          const Offset(8, 8),
    );
    await settleLink(tester);

    expect(container.read(readerTabsProvider).activeTab!.bookId, 'A-iv');
  });
}
