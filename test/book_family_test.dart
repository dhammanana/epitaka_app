import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/features/reader/services/book_family_service.dart';

// Rows copied from the `books` table of epitaka.db (2026-10-29), in table
// order. A ref to a book outside this list (e.g. `Vin-iv`) is dropped, as it
// would be for a book missing from the database.
const _rows = [
  BookRefsRow(
    bookId: 'A-v',
    category: 'Mūla',
    atthaRef: 'Mp-v',
    tikaRef: 'Mp-t-v',
  ),
  BookRefsRow(bookId: 'Ap-i', category: 'Mūla', atthaRef: 'Ap-a'),
  BookRefsRow(bookId: 'Ap-ii', category: 'Mūla', atthaRef: 'Ap-a'),
  BookRefsRow(bookId: 'Ap-iii', category: 'Mūla', atthaRef: 'Ap-a'),
  BookRefsRow(
    bookId: 'Ja-i',
    category: 'Mūla',
    atthaRef: 'Ja-a-i Ja-a-ii Ja-a-iii Ja-a-iv Ja-a-vi-b',
    tikaRef: 'Ja-ṭ-i Ja-ṭ-ii Ja-ṭ-iii',
  ),
  BookRefsRow(bookId: 'Mil', category: 'Mūla'),
  BookRefsRow(
    bookId: 'Vin-i',
    category: 'Mūla',
    atthaRef: 'Sp-i',
    tikaRef: 'Sp-t-i-a Sp-t-i-b Vjb-prj Vmv-i',
  ),
  BookRefsRow(
    bookId: 'Vin-ii-b',
    category: 'Mūla',
    atthaRef: 'Sp-ii-b',
    tikaRef: 'Sp-t-ii Vjb-bkn Vmv-ii',
  ),
  BookRefsRow(
    bookId: 'Vin-iii',
    category: 'Mūla',
    atthaRef: 'Sp-iii',
    tikaRef: 'Sp-t-iii Vjb-mv Vmv-iii',
  ),
  BookRefsRow(
    bookId: 'Mp-v',
    category: 'Aṭṭhakathā',
    mulaRef: 'A-v',
    tikaRef: 'Mp-t-v',
  ),
  BookRefsRow(
    bookId: 'Ap-a',
    category: 'Aṭṭhakathā',
    mulaRef: 'Ap-i Ap-ii Ap-iii',
  ),
  BookRefsRow(
    bookId: 'Ja-a-i',
    category: 'Aṭṭhakathā',
    mulaRef: 'Ja-i',
    tikaRef: 'Ja-ṭ-i',
  ),
  BookRefsRow(
    bookId: 'Ja-a-ii',
    category: 'Aṭṭhakathā',
    mulaRef: 'Ja-i',
    tikaRef: 'Ja-ṭ-ii',
  ),
  BookRefsRow(
    bookId: 'Ja-a-iii',
    category: 'Aṭṭhakathā',
    mulaRef: 'Ja-i',
    tikaRef: 'Ja-ṭ-iii',
  ),
  BookRefsRow(
    bookId: 'Ja-a-iv',
    category: 'Aṭṭhakathā',
    mulaRef: 'Ja-i',
    tikaRef: 'Ja-ṭ-iii',
  ),
  BookRefsRow(
    bookId: 'Ja-a-vi-b',
    category: 'Aṭṭhakathā',
    mulaRef: 'Ja-i',
    tikaRef: 'Ja-ṭ-iii',
  ),
  BookRefsRow(
    bookId: 'Sp-i',
    category: 'Aṭṭhakathā',
    mulaRef: 'Vin-i',
    tikaRef: 'Sp-t-i-a Sp-t-i-b Vjb-prj Vmv-i',
  ),
  BookRefsRow(
    bookId: 'Sp-ii-b',
    category: 'Aṭṭhakathā',
    mulaRef: 'Vin-ii-b',
    tikaRef: 'Sp-t-ii Vjb-pac Vmv-ii',
  ),
  BookRefsRow(
    bookId: 'Sp-iii',
    category: 'Aṭṭhakathā',
    mulaRef: 'Vin-iii',
    tikaRef: 'Sp-t-iii Vjb-mv Vmv-iii',
  ),
  BookRefsRow(
    bookId: 'Mp-t-v',
    category: 'Ṭīkā',
    mulaRef: 'A-v',
    atthaRef: 'Mp-v',
  ),
  BookRefsRow(
    bookId: 'Sp-t-i-a',
    category: 'Ṭīkā',
    mulaRef: 'Vin-i',
    atthaRef: 'Sp-i',
  ),
  BookRefsRow(
    bookId: 'Sp-t-i-b',
    category: 'Ṭīkā',
    mulaRef: 'Vin-i',
    atthaRef: 'Sp-i',
  ),
  BookRefsRow(
    bookId: 'Sp-t-ii',
    category: 'Ṭīkā',
    mulaRef: 'Vin-ii',
    atthaRef: 'Sp-ii',
  ),
  BookRefsRow(
    bookId: 'Sp-t-iii',
    category: 'Ṭīkā',
    mulaRef: 'Vin-iii',
    atthaRef: 'Sp-iii',
  ),
  BookRefsRow(
    bookId: 'Vjb-prj',
    category: 'Ṭīkā',
    mulaRef: 'Vin-i',
    atthaRef: 'Sp-i',
  ),
  BookRefsRow(
    bookId: 'Vjb-bkn',
    category: 'Ṭīkā',
    mulaRef: 'Vin-iii',
    atthaRef: 'Sp-iii',
  ),
  BookRefsRow(
    bookId: 'Vjb-mv',
    category: 'Ṭīkā',
    mulaRef: 'Vin-iv',
    atthaRef: 'Sp-iv',
  ),
  BookRefsRow(
    bookId: 'Vmv-i',
    category: 'Ṭīkā',
    mulaRef: 'Vin-i',
    atthaRef: 'Sp-i',
  ),
  BookRefsRow(
    bookId: 'Vmv-iii',
    category: 'Ṭīkā',
    mulaRef: 'Vin-iii',
    atthaRef: 'Sp-iii',
  ),
  BookRefsRow(bookId: 'Vin-vn', category: 'Ṭīkā', tikaRef: 'Vin-vn-t'),
  BookRefsRow(bookId: 'Vin-vn-t', category: 'Ṭīkā', atthaRef: 'Vin-vn'),
  BookRefsRow(bookId: 'Vism-i', category: 'Aṭṭhakathā', tikaRef: 'Vism-mht-i'),
  BookRefsRow(bookId: 'Vism-mht-i', category: 'Ṭīkā', mulaRef: 'Vism-i'),
  BookRefsRow(
    bookId: 'Ja-ṭ-i',
    category: 'Ṭīkā',
    mulaRef: 'Ja-i',
    atthaRef: 'Ja-a-i',
  ),
  BookRefsRow(
    bookId: 'Ja-ṭ-ii',
    category: 'Ṭīkā',
    mulaRef: 'Ja-i',
    atthaRef: 'Ja-a-ii',
  ),
  BookRefsRow(
    bookId: 'Ja-ṭ-iii',
    category: 'Ṭīkā',
    mulaRef: 'Ja-i',
    atthaRef: 'Ja-a-iii Ja-a-iv Ja-a-vi-b',
  ),
];

void main() {
  final families = buildBookFamilies(_rows);

  Map<BookLevel, List<String>> booksOf(String bookId) =>
      families[bookId]!.books;

  test('AN 5: the mūla, its aṭṭhakathā and its ṭīkā find each other', () {
    const expected = {
      BookLevel.mula: ['A-v'],
      BookLevel.attha: ['Mp-v'],
      BookLevel.tika: ['Mp-t-v'],
    };
    expect(booksOf('A-v'), expected);
    expect(booksOf('Mp-v'), expected);
    expect(booksOf('Mp-t-v'), expected);
    expect(families['A-v']!.level, BookLevel.mula);
    expect(families['Mp-v']!.level, BookLevel.attha);
    expect(families['Mp-t-v']!.level, BookLevel.tika);
  });

  test('Pārājika has four ṭīkā books, in table order', () {
    expect(families['Vin-i']!.booksAt(BookLevel.tika), [
      'Sp-t-i-a',
      'Sp-t-i-b',
      'Vjb-prj',
      'Vmv-i',
    ]);
    expect(families['Vin-i']!.booksAt(BookLevel.attha), ['Sp-i']);
    expect(families['Vjb-prj']!.booksAt(BookLevel.mula), ['Vin-i']);
  });

  test('Jātaka 1 has five aṭṭhakathā books and three ṭīkā books', () {
    expect(families['Ja-i']!.booksAt(BookLevel.attha), [
      'Ja-a-i',
      'Ja-a-ii',
      'Ja-a-iii',
      'Ja-a-iv',
      'Ja-a-vi-b',
    ]);
    expect(families['Ja-i']!.booksAt(BookLevel.tika), [
      'Ja-ṭ-i',
      'Ja-ṭ-ii',
      'Ja-ṭ-iii',
    ]);
    expect(booksOf('Ja-a-iv'), {
      BookLevel.mula: ['Ja-i'],
      BookLevel.attha: ['Ja-a-iv'],
      BookLevel.tika: ['Ja-ṭ-iii'],
    });
  });

  test('the Apadāna commentary serves three mūla books', () {
    expect(families['Ap-a']!.booksAt(BookLevel.mula), [
      'Ap-i',
      'Ap-ii',
      'Ap-iii',
    ]);
    expect(booksOf('Ap-ii'), {
      BookLevel.mula: ['Ap-ii'],
      BookLevel.attha: ['Ap-a'],
      BookLevel.tika: <String>[],
    });
  });

  test('a book with no refs has no family', () {
    expect(families.containsKey('Mil'), isFalse);
  });

  test(
    'a manual filed as ṭīkā with its own ṭīkā sits at the aṭṭhakathā level',
    () {
      const expected = {
        BookLevel.mula: <String>[],
        BookLevel.attha: ['Vin-vn'],
        BookLevel.tika: ['Vin-vn-t'],
      };
      expect(families['Vin-vn']!.level, BookLevel.attha);
      expect(booksOf('Vin-vn'), expected);
      expect(booksOf('Vin-vn-t'), expected);
    },
  );

  test('the Visuddhimagga sits at the mūla level, as its ṭīkā names it', () {
    const expected = {
      BookLevel.mula: ['Vism-i'],
      BookLevel.attha: <String>[],
      BookLevel.tika: ['Vism-mht-i'],
    };
    expect(families['Vism-i']!.level, BookLevel.mula);
    expect(booksOf('Vism-i'), expected);
    expect(booksOf('Vism-mht-i'), expected);
  });

  test('a link written on one side only still joins both books', () {
    // Vjb-bkn names Vin-iii as its mūla, but Vin-iii does not name Vjb-bkn;
    // Vin-ii-b names Vjb-bkn as a ṭīkā, but Vjb-bkn does not name Vin-ii-b.
    expect(families['Vjb-bkn']!.booksAt(BookLevel.mula), [
      'Vin-ii-b',
      'Vin-iii',
    ]);
    expect(families['Vin-iii']!.booksAt(BookLevel.tika), [
      'Sp-t-iii',
      'Vjb-bkn',
      'Vjb-mv',
      'Vmv-iii',
    ]);
  });
}
