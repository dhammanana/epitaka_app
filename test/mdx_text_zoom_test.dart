import 'package:epitaka/features/mdx_dictionary/widgets/mdx_definition_section.dart';
import 'package:flutter_test/flutter_test.dart';

/// MDX text follows the Pāli size on the same scale as the other
/// dictionaries: 0.8 × the dictionary's Pāli size, kept between 6 and 24.
void main() {
  test('default Pāli size keeps MDX text unzoomed', () {
    expect(mdxBodyFontSize(19), closeTo(15.2, 1e-9));
    expect(mdxTextZoom(19), 100);
  });

  test('zoom follows the size slider range and its limits', () {
    // The dictionary text size runs from 50% to 120% of 19, so about 9.5 to
    // 22.8. Below 6 the floor holds.
    expect(mdxTextZoom(9.5), 50);
    expect(mdxTextZoom(22.8), 120);
    expect(mdxBodyFontSize(10), 8.0);
    expect(mdxBodyFontSize(4), 6.0);
    expect(mdxBodyFontSize(48), 24.0);
  });
}
