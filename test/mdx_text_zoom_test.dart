import 'package:epitaka/features/mdx_dictionary/widgets/mdx_definition_section.dart';
import 'package:flutter_test/flutter_test.dart';

/// MDX text follows the Pāli size on the same scale as the other
/// dictionaries: 0.8 × Pāli size, clamped to 12–24.
void main() {
  test('default Pāli size keeps MDX text unzoomed', () {
    expect(mdxBodyFontSize(19), closeTo(15.2, 1e-9));
    expect(mdxTextZoom(19), 100);
  });

  test('zoom follows the size slider range and its limits', () {
    // The size slider runs from 10 to 48.
    expect(mdxTextZoom(10), 79);
    expect(mdxTextZoom(48), 158);
    expect(mdxBodyFontSize(10), 12.0);
    expect(mdxBodyFontSize(48), 24.0);
  });
}
