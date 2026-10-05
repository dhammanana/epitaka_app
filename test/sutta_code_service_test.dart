import 'package:drift/native.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/features/sutta_jump/services/sutta_code_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Token cells as scripts/import_sutta_codes.py writes them into
// headings.sc_id (plus one old-style single-code row).
SuttaLookupCache _fixture() {
  SuttaLookupRow row(
    String bookId,
    int paraId,
    String title,
    String scId,
  ) => SuttaLookupRow(
    bookId: bookId,
    paraId: paraId,
    title: title,
    tokens: [
      for (final part in scId.split(' '))
        if (part.isNotEmpty) parseToken(part),
    ],
  );
  return SuttaLookupCache(
    rows: [
      row('M-i', 280, 'Mahāsatipaṭṭhānasuttaṃ', 'mn10'),
      row('M-ii', 1653, 'Saṅgāravasuttaṃ', 'mn100'),
      row('Thī', 175, 'Sāmātherīgāthā', 'thi28 =thig2.10 =thi2.10'),
      row('A-i', 3, 'Rūpādivagga', 'an1 an1.1-10 >an1.1'),
      row('A-i', 10, 'Rūpādivagga', '>an1.5'),
      row('A-i', 162, 'Etadaggavagga', 'an1.188-267 +an1.188'),
      row('Vibh', 4, '1. Khandhavibhaṅgo', 'vb1'),
      row('Vibh', 1520, '10. Bojjhaṅgavibhaṅgo', 'vb10'),
      row('S-iv', 1570, 'Sāmaṇḍakasuttaṃ', 'sn39.1 sn39 sn39.1-2 =sn39.1-15'),
      // Bare ranges with no member tokens of their own.
      row('A-ii', 35, 'Adhikaraṇavagga', 'an2.11-21'),
      row('A-iv', 100, 'Outer range', 'an4.274-783'),
      row('A-iv', 200, 'Inner range', 'an4.277-303'),
    ],
    bookNames: const {
      'M-i': 'Mūlapaṇṇāsapāḷi',
      'M-ii': 'Majjhimapaṇṇāsapāḷi',
      'Thī': 'Therīgāthāpāḷi',
      'A-i': 'Ekakanipātapāḷi',
      'Vibh': 'Vibhaṅgapāḷi',
      'S-iv': 'Saḷāyatanavaggasaṃyuttaṃ',
    },
  );
}

void main() {
  final cache = _fixture();

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

  group('parseToken', () {
    test('plain, member, kept, alias and payload tokens', () {
      expect(parseToken('mn10').key, 'mn10');
      expect(parseToken('>an1.5').isMember, isTrue);
      expect(parseToken('+an1.188').isKept, isTrue);
      expect(parseToken('=thig2.10').isRangeAlias, isTrue);
      final payload = parseToken('an5.303-1151=an5.303');
      expect(payload.key, 'an5.303-1151');
      expect(payload.payload, 'an5.303');
    });
  });

  group('searchSuttaCodes', () {
    test('MN 10 finds mn10', () {
      final r = searchSuttaCodes(cache, 'MN 10');
      expect(r.first.bookId, 'M-i');
      expect(r.first.paraId, 280);
      expect(r.first.label, 'MN10');
    });

    test('labels show the SuttaCentral code or the range', () {
      expect(
        searchSuttaCodes(cache, 'thig2.10').single.label,
        'THI28 = THIG2.10',
      );
      expect(
        searchSuttaCodes(cache, 'thi28').single.label,
        'THI28 = THIG2.10',
      );
      expect(
        searchSuttaCodes(cache, 'an1.5').single.label,
        'AN1.5 (AN1.1-10)',
      );
      expect(searchSuttaCodes(cache, 'mn10').first.label, 'MN10');
    });

    test('a kept-range member shows the range', () {
      expect(
        searchSuttaCodes(cache, 'an1.188').single.label,
        'AN1.188-267',
      );
    });

    test('a samyutta code next to an alias row keeps its own label', () {
      final shown = searchSuttaCodes(cache, 'sn39').map((t) => t.label).toList();
      expect(shown.first, 'SN39');
      expect(shown, contains('SN39.1 = SN39.1-15'));
      expect(
        searchSuttaCodes(cache, 'sn39.1').first.label,
        'SN39.1 = SN39.1-15',
      );
    });

    test('an exact range member shows itself with its range', () {
      final r = searchSuttaCodes(cache, 'an1.1');
      expect(r.first.displayCode, 'AN1.1 (AN1.1-10)');
      expect(r.first.paraId, 3);
    });

    test('suttas inside a range show only as the exact match', () {
      final shown = searchSuttaCodes(cache, 'an1').map((t) => t.label);
      expect(shown, isNot(contains('AN1.5')));
      expect(shown.first, 'AN1');
      expect(shown, contains('AN1.1-10'));
    });

    test('old single-code headings still resolve by prefix', () {
      final shown = searchSuttaCodes(cache, 'vb1').map((t) => t.label);
      expect(shown, containsAll(['VB1', 'VB10']));
    });

    test('a member with no token opens its covering range', () {
      final r = searchSuttaCodes(cache, 'an2.15');
      expect(r.single.label, 'AN2.15 (AN2.11-21)');
      expect((r.single.bookId, r.single.paraId), ('A-ii', 35));
    });

    test('a stored member token beats range synthesis', () {
      final r = searchSuttaCodes(cache, 'an1.5');
      expect(r.single.label, 'AN1.5 (AN1.1-10)');
      expect((r.single.bookId, r.single.paraId), ('A-i', 10));
    });

    test('nested ranges resolve to the widest covering one', () {
      final r = searchSuttaCodes(cache, 'an4.278');
      expect(r.single.label, 'AN4.278 (AN4.274-783)');
      expect((r.single.bookId, r.single.paraId), ('A-iv', 100));
    });

    test('codes outside every range and dashed inputs stay empty', () {
      expect(searchSuttaCodes(cache, 'an2.99'), isEmpty);
      expect(searchSuttaCodes(cache, 'an2.1-5'), isEmpty);
    });

    test('unknown code and empty input give nothing', () {
      expect(searchSuttaCodes(cache, 'zz99'), isEmpty);
      expect(searchSuttaCodes(cache, '  '), isEmpty);
    });

    test('typed % and _ match literally, not as wildcards', () {
      expect(searchSuttaCodes(cache, '%'), isEmpty);
      expect(searchSuttaCodes(cache, 'vb_'), isEmpty);
    });
  });

  group('searchSuttaNames', () {
    test('a sutta name finds the sutta without diacritics', () {
      final r = searchSuttaNames(cache, 'satipatthana');
      expect(r, isNotEmpty);
      expect(r.first.bookId, 'M-i');
      expect(r.first.paraId, 280);
    });

    test('a spaced name still matches', () {
      final r = searchSuttaNames(cache, 'maha satipatthana');
      expect(r.map((t) => t.paraId), contains(280));
    });

    test('a book name finds that book’s headings', () {
      final r = searchSuttaNames(cache, 'vibhanga');
      expect(r.map((t) => t.bookId).toSet(), {'Vibh'});
    });

    test('codes do not match names and short queries give nothing', () {
      expect(searchSuttaNames(cache, 'mn10'), isEmpty);
      expect(searchSuttaNames(cache, 'a'), isEmpty);
      expect(searchSuttaNames(cache, '  '), isEmpty);
    });
  });

  test('loadSuttaLookup reads headings and books from the database',
      () async {
    final db = EpitakaDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
      'CREATE TABLE books (id INTEGER PRIMARY KEY, ref_id INTEGER, vri_id TEXT, '
      'book_id TEXT NOT NULL UNIQUE, category TEXT, nikaya TEXT, '
      'sub_nikaya TEXT, book_name TEXT, description TEXT, mula_ref TEXT, '
      'attha_ref TEXT, tika_ref TEXT, para_id INTEGER, chapter_len INTEGER)',
    );
    await db.customStatement(
      'CREATE TABLE headings (book_id TEXT, para_id INT, level INT, '
      'title TEXT, chapter_len INT, parent INT, sc_id TEXT)',
    );
    await db.customStatement(
      "INSERT INTO books(book_id, book_name) VALUES ('M-i', 'Mūlapaṇṇāsapāḷi')",
    );
    await db.customStatement(
      "INSERT INTO headings(book_id, para_id, level, title, sc_id) VALUES "
      "('M-i', 280, 2, 'Mahāsatipaṭṭhānasuttaṃ', 'mn10'), "
      "('M-i', 281, 10, '2', '>mn2'), "
      "('M-i', 282, 11, 'sub-note', 'zz9')",
    );

    final loaded = await loadSuttaLookup(db);
    expect(loaded.rows, hasLength(2));
    expect(loaded.rows.last.tokens.single.key, 'mn2');
    expect(loaded.bookNames['M-i'], 'Mūlapaṇṇāsapāḷi');
    expect(searchSuttaCodes(loaded, 'mn10').single.paraId, 280);
    expect(searchSuttaCodes(loaded, 'mn2').single.paraId, 281);
  });
}
