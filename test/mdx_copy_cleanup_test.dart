import 'package:epitaka/features/mdx_dictionary/services/mdx_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mdx = '/data/mdx_files/LDOCE6.mdx';

  test('isMdxCopyFileName matches the .mdx and its sidecars', () {
    for (final name in [
      'LDOCE6.mdx',
      'LDOCE6.mdd',
      'LDOCE6.1.mdd',
      'LDOCE6.css',
      'LDOCE6.js',
      'LDOCE6.mcss',
    ]) {
      expect(isMdxCopyFileName(name, mdx), isTrue, reason: name);
    }
  });

  test('isMdxCopyFileName leaves other dictionaries alone', () {
    for (final name in [
      'LDOCE6_1.mdx',
      'LDOCE7.mdx',
      'LDOCE7.mdd',
      'shared.css',
    ]) {
      expect(isMdxCopyFileName(name, mdx), isFalse, reason: name);
    }
  });

  test('isMdxCopyFileName matches a suffixed duplicate copy by its own base', () {
    expect(isMdxCopyFileName('LDOCE6_1.mdd', '/d/LDOCE6_1.mdx'), isTrue);
    expect(isMdxCopyFileName('LDOCE6_1.mdd', mdx), isFalse);
  });
}
