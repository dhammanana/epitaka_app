import 'package:epitaka/core/utils/pali_search_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = <String, String>{
    "dhamma'": 'dhamma',
    '-dhamma-': 'dhamma',
    'dhamma-vinayaṃ': 'dhammavinayaṃ',
    'āha\u2014mayhaṃ': 'āha mayhaṃ',
    '“saṃsāra,”': 'saṃsāra',
    "kho'ti": 'khoti',
    'kho’ti': 'khoti',
    'ဓမ္မ': 'ဓမ္မ',
    '"dhamma" https://example.org/a#:~:text=dhamma': 'dhamma',
    '  evaṃ   me  sutaṃ. ': 'evaṃ me sutaṃ',
    "'": '',
  };

  cases.forEach((input, expected) {
    test('cleans ${input.replaceAll('\n', r'\n')}', () {
      expect(cleanIncomingSearchText(input), expected);
    });
  });
}
