import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/features/reader/services/paragraph_number_index.dart';

// Every numbered line of AN 5 (`A-v`), its aṭṭhakathā (`Mp-v`) and its ṭīkā
// (`Mp-t-v`), copied from epitaka.db.
final _an5 =
    jsonDecode(
          File('test/fixtures/an5_paragraph_numbers.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

ParagraphNumberIndex _an5Index(String bookId) {
  final book = _an5[bookId] as Map<String, dynamic>;
  return ParagraphNumberIndex.fromRows([
    for (final row in book['rows'] as List)
      (paraId: row[0] as int, vripara: row[1] as String?),
  ], lastParaId: book['last'] as int);
}

ParagraphNumberIndex _index(List<(int, String)> rows, int lastParaId) =>
    ParagraphNumberIndex.fromRows([
      for (final (paraId, vripara) in rows) (paraId: paraId, vripara: vripara),
    ], lastParaId: lastParaId);

void main() {
  final mula = _an5Index('A-v');
  final attha = _an5Index('Mp-v');
  final tika = _an5Index('Mp-t-v');

  test('the start of a VRI number is the paragraph number', () {
    expect(parseParagraphNumber('36'), 36);
    expect(parseParagraphNumber('36-37'), 36);
    expect(parseParagraphNumber('18-19-20'), 18);
    expect(parseParagraphNumber(''), isNull);
    expect(parseParagraphNumber(null), isNull);
  });

  test('AN 5.36 lines up in the mūla, aṭṭhakathā and ṭīkā', () {
    expect(matchParagraph(mula, 222, attha), 99);
    expect(matchParagraph(attha, 99, tika), 96);
    expect(matchParagraph(mula, 222, tika), 96);
    expect(matchParagraph(tika, 96, mula), 222);
  });

  test('a ṭīkā range 36-37 also matches sutta 37', () {
    expect(matchParagraph(mula, 231, tika), 96);
  });

  test('a paragraph between numbers uses the number above it', () {
    expect(matchParagraph(mula, 225, attha), 99);
  });

  test('a sutta with no commentary entry lands on the highest lower one', () {
    // Mp-v comments on suttas 1, 2 and 6; sutta 4 is A-v paragraph 21.
    // The "4. Catutthapaṇṇāsakaṃ" heading at Mp-v 310 is not sutta 4.
    expect(matchParagraph(mula, 21, attha), 9);
  });

  test('section headings that carry a number are left out of the index', () {
    final paraIds = attha.entries.map((e) => e.paraId).toSet();
    for (final heading in [128, 227, 310, 417]) {
      expect(paraIds.contains(heading), isFalse, reason: 'Mp-v $heading');
    }
    expect(paraIds.contains(99), isTrue);
  });

  test('a sutta title belongs to the sutta it introduces', () {
    // A-v 261 is the title "10. Mahāsālaputtasuttaṃ"; number 40 is at 262.
    // Titles copied from the A-v headings (level below 10).
    final book = _an5['A-v'] as Map<String, dynamic>;
    final mulaWithTitles = ParagraphNumberIndex.fromRows(
      [
        for (final row in book['rows'] as List)
          (paraId: row[0] as int, vripara: row[1] as String?),
      ],
      lastParaId: book['last'] as int,
      titleParaIds: const {215, 221, 230, 236, 249, 261},
    );
    expect(matchParagraph(mulaWithTitles, 261, attha), 108);
    expect(matchParagraph(mulaWithTitles, 221, attha), 99);
    // Without the titles, 261 counts as the end of sutta 39.
    expect(matchParagraph(mula, 261, attha), 105);
  });

  test('a title with text after it keeps the number before it', () {
    // Sp-i, the Pārājika commentary: titles 3, 4, 69, 76, 223, 259 sit in
    // its opening, with text between them; 490 "Verañjakaṇḍavaṇṇanā" is
    // right before the first number, 491. Copied from epitaka.db.
    final opening = ParagraphNumberIndex.fromRows(
      [(paraId: 491, vripara: '1'), (paraId: 492, vripara: '2')],
      lastParaId: 495,
      titleParaIds: const {3, 4, 69, 76, 223, 259, 490},
      paraIds: [for (var id = 1; id <= 495; id++) id],
    );
    expect(opening.numberFor(259), isNull, reason: 'openings never match');
    expect(opening.numberFor(4), isNull);
    expect(opening.numberFor(490)?.paraId, 491);
  });

  test('missing paragraph ids between a title and its number are skipped', () {
    final index = ParagraphNumberIndex.fromRows(
      [(paraId: 13, vripara: '5')],
      lastParaId: 20,
      titleParaIds: const {10},
      paraIds: const [9, 10, 13, 14],
    );
    expect(index.numberFor(10)?.paraId, 13);
  });

  test('a commentary opening before the first number never matches', () {
    // Mp-v's first number is on paragraph 4.
    expect(matchParagraph(attha, 2, mula), isNull);
    expect(attha.entries.first.paraId, 4);
  });

  test('a number below every target number leaves the target alone', () {
    // D-i starts at 1; its later ṭīkā Sv-nt-ii starts at 150.
    final digha = _index([(6, '1'), (7, '2'), (8, '3')], 1074);
    final nissaya = _index([
      (7, '150'),
      (44, '151'),
      (47, '152'),
      (48, '153'),
    ], 1366);
    expect(matchParagraph(digha, 7, nissaya), isNull);
  });

  group('a number that repeats in the target', () {
    // The Jātaka mūla (Ja-i) restarts its numbers 16 times; its aṭṭhakathā
    // book 3 (Ja-a-iii) opens with number 1 at paragraph 14 and comments on
    // the mūla from paragraph 2330. Rows and links copied from epitaka.db.
    final jatakaAttha3 = _index([(14, '1'), (21, '2')], 4868);
    final jataka = _index([
      for (final paraId in [
        9, 855, 1746, 2330, 3069, 3561, 4045, 4592, //
        4905, 5278, 5874, 6267, 6695, 7191, 8126, 9342,
      ])
        (paraId, '1'),
    ], 10506);
    const links = [
      (sourceParaId: 16, targetParaId: 2330),
      (sourceParaId: 16, targetParaId: 2331),
    ];

    test('the word links pick the copy the commentary is about', () {
      expect(matchParagraph(jatakaAttha3, 14, jataka, links: links), 2330);
    });

    test('with no links, the place in the book decides', () {
      // 14 / 4868 is nearest 9 / 10506, the start of the mūla.
      expect(matchParagraph(jatakaAttha3, 14, jataka), 9);
      // A source near the end of its book takes the last copy, not the first.
      final lateSource = _index([(4800, '1')], 4868);
      expect(matchParagraph(lateSource, 4800, jataka), 9342);
    });
  });
}
