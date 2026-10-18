import 'package:epitaka/features/dpd/utils/text_filters.dart';
import 'package:flutter_test/flutter_test.dart';

/// Strings copied from real DPD rows (`example_1`, `commentary`, `meaning_1`).
void main() {
  String off(String t) => filterSandhi(t, show: false);

  test('shown: nothing changes', () {
    expect(filterSandhi("kaṇṭh'oṭṭhajo", show: true), "kaṇṭh'oṭṭhajo");
  });

  test('an apostrophe between letters goes', () {
    expect(off("kaṇṭh'oṭṭhajo"), 'kaṇṭhoṭṭhajo');
    expect(off("saṅgho'va tassā"), 'saṅghova tassā');
    expect(off("yāva'd'eva"), 'yāvadeva');
  });

  test('a hyphen between letters goes, also beside a tag', () {
    expect(off('akaṇha-asukkaṃ'), 'akaṇhaasukkaṃ');
    expect(off('na paresaṃ kata-<b>akataṃ</b>'), 'na paresaṃ kata<b>akataṃ</b>');
    expect(off("rogato'ti-ādīsu"), 'rogatotiādīsu');
  });

  test('a mark after a closing tag goes', () {
    expect(off("<b>kammenā</b>'ti dhammikena"), '<b>kammenā</b>ti dhammikena');
  });

  test('a mark beside a space or the end stays', () {
    expect(off("(end of direct speech) ' '"), "(end of direct speech) ' '");
    expect(off("'ti vuccati"), "'ti vuccati");
    expect(off('ending-'), 'ending-');
    expect(off('1-3'), '1-3');
  });
}
