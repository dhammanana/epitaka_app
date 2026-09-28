import 'package:epitaka/features/mdx_dictionary/services/mdx_web.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildMdxWebDocument injects css/js links and bodies', () {
    final doc = buildMdxWebDocument(
      cssHref: 'http://mdx.internal/oald.css',
      jsSrc: 'http://mdx.internal/oald.js',
      bodies: const ['<p>hello</p>'],
    );
    expect(doc, contains('<link rel="stylesheet" href="http://mdx.internal/oald.css">'));
    expect(doc, contains('<script src="http://mdx.internal/oald.js"></script>'));
    expect(doc, contains('<p>hello</p>'));
    expect(doc, startsWith('<!DOCTYPE html>'));
  });

  test('buildMdxWebDocument omits missing bundle files', () {
    final doc = buildMdxWebDocument(
      cssHref: null,
      jsSrc: null,
      bodies: const ['<p>hi</p>'],
    );
    expect(doc, isNot(contains('<link rel="stylesheet"')));
    expect(doc, isNot(contains('<script src=')));
  });
}
