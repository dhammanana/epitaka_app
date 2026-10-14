import 'package:flutter_test/flutter_test.dart';
import 'package:epitaka/features/dpd/utils/query_cleaning.dart';

void main() {
  group('cleanDpdQuery', () {
    test('turns dhamma in four scripts into Roman', () {
      expect(cleanDpdQuery('ධම්ම'), 'dhamma'); // Sinhala
      expect(cleanDpdQuery('ธมฺม'), 'dhamma'); // Thai
      expect(cleanDpdQuery('ဓမ္မ'), 'dhamma'); // Myanmar
      expect(cleanDpdQuery('धम्म'), 'dhamma'); // Devanāgarī
    });

    test('folds niggahīta and strips ? and !', () {
      expect(cleanDpdQuery('dhammaṁ?'), 'dhammaṃ');
      expect(cleanDpdQuery('dhammaŋ!'), 'dhammaṃ');
      expect(cleanDpdQuery('  dhamma  '), 'dhamma');
    });

    test('still reads Velthuis', () {
      expect(cleanDpdQuery('dhamma.m'), 'dhammaṃ');
    });

    test('a query of only ? is empty', () {
      expect(cleanDpdQuery('?!'), '');
    });
  });

  group('cleanTappedWord', () {
    test('a dot between digits stays: a sutta number', () {
      expect(cleanTappedWord('SN1.16'), 'SN1.16');
      expect(cleanTappedWord('(SN1.16),'), 'SN1.16');
      expect(cleanTappedWord('DN2.5.'), 'DN2.5');
    });

    test('other punctuation and dots go', () {
      expect(cleanTappedWord('dhammaṁ.'), 'dhammaṃ');
      expect(cleanTappedWord('"kamma,"'), 'kamma');
      expect(cleanTappedWord('a.b'), 'ab');
      expect(cleanTappedWord('.5'), '5');
    });

    test('any script becomes Roman', () {
      expect(cleanTappedWord('ධම්ම'), 'dhamma');
    });
  });
}
