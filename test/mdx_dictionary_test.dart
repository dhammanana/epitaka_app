import 'package:epitaka/features/mdx_dictionary/models/mdx_dictionary_info.dart';
import 'package:epitaka/features/mdx_dictionary/services/mdx_errors.dart';
import 'package:epitaka/features/mdx_dictionary/services/mdx_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mdxNorm lowercases and trims', () {
    expect(mdxNorm('  Dhamma '), 'dhamma');
  });

  test('mdxSanitize strips scripts but keeps markup', () {
    final out = mdxSanitize('<p>hi</p><script>alert(1)</script>');
    expect(out.contains('<p>hi</p>'), true);
    expect(out.contains('<script>'), false);
  });

  test('MdxDictionaryInfo round-trips json', () {
    const info = MdxDictionaryInfo(
      id: 'a',
      title: 't',
      mdxPath: '/x/y.mdx',
      userOrder: 0,
      enabled: true,
      entryCount: 5,
    );
    final back = MdxDictionaryInfo.fromJson(info.toJson());
    expect(back.id, 'a');
    expect(back.entryCount, 5);
  });

  test('MdxDictionaryInfo round-trips mddPaths', () {
    const info = MdxDictionaryInfo(
      id: 'a',
      title: 't',
      mdxPath: '/x/y.mdx',
      userOrder: 0,
      enabled: true,
      entryCount: 5,
      mddPaths: ['/x/y.mdd', '/x/y.1.mdd'],
    );
    final back = MdxDictionaryInfo.fromJson(info.toJson());
    expect(back.mddPaths, ['/x/y.mdd', '/x/y.1.mdd']);
  });

  test('legacy json without mddPaths defaults to empty', () {
    final back = MdxDictionaryInfo.fromJson({
      'id': 'a',
      'title': 't',
      'mdxPath': '/x/y.mdx',
      'userOrder': 0,
      'enabled': true,
      'entryCount': 1,
    });
    expect(back.mddPaths, isEmpty);
  });

  test('mdxLinkTargets parses single redirect', () {
    expect(mdxLinkTargets('@@@LINK=hello'), ['hello']);
  });

  test('mdxLinkTargets strips BOM and takes first line', () {
    expect(mdxLinkTargets('\uFEFF@@@LINK=hello\r\njunk'), ['hello']);
  });

  test('mdxLinkTargets ignores plain html', () {
    expect(mdxLinkTargets('<p>hello</p>'), isEmpty);
  });

  test('mdxResourceKeys covers slash variants', () {
    final keys = mdxResourceKeys('pic/a.png');
    expect(keys, contains('pic/a.png'));
    expect(keys, contains(r'pic\a.png'));
    expect(keys, contains('/pic/a.png'));
  });

  test('typed errors carry paths', () {
    expect(const MdxMissingFile('/x/y.mdx').toString(), contains('/x/y.mdx'));
    expect(
      const MdxNotReady('Index missing.', path: '/x/i.sqlite').toString(),
      contains('Index missing.'),
    );
  });

  test('mdxStylesheetHrefs harvests stylesheet links', () {
    const html =
        '<link type="text/css" rel="stylesheet" href="LDOCE6.css"/>'
        '<link href="extra.css" rel="stylesheet">'
        "<link rel='icon' href='fav.ico'>"
        '<a href="entry://x">x</a>';
    expect(mdxStylesheetHrefs(html), ['LDOCE6.css', 'extra.css']);
  });

  test('mdxStylesheetHrefs dedupes case-insensitively', () {
    expect(
      mdxStylesheetHrefs(
        '<link rel="stylesheet" href="A.css"><LINK REL=stylesheet HREF="a.css">',
      ),
      ['A.css'],
    );
  });

  test('mdxStripStylesheetLinks removes only stylesheet links', () {
    const html =
        '<link rel="stylesheet" href="a.css"><link rel="icon" href="f.ico"><p>t</p>';
    final out = mdxStripStylesheetLinks(html);
    expect(out.contains('a.css'), false);
    expect(out.contains('f.ico'), true);
    expect(out.contains('<p>t</p>'), true);
  });

  test('mdxApplyMaxChars leaves null uncapped (WebView documents)', () {
    final big = 'x' * 50000;
    expect(mdxApplyMaxChars(big, null).length, 50000);
  });

  test('mdxApplyMaxChars truncates only when over the cap', () {
    expect(mdxApplyMaxChars('abcde', 3), 'abc');
    expect(mdxApplyMaxChars('ab', 3), 'ab');
  });

  test('mdxSanitizeCss unhides display none and visibility hidden', () {
    const css =
        '.hwd{display:none}.x{color:red;display: none !important}.y{visibility:hidden}';
    final out = mdxSanitizeCss(css);
    expect(out.contains('none'), false);
    expect(out.contains('hidden'), false);
    expect(out.contains('color:red'), true);
  });

  test('mdxSanitizeCss unhides none-dash hack without corrupting', () {
    const css = '.a{display: none-;color:red}.b{display:none-foo}';
    final out = mdxSanitizeCss(css);
    expect(out.contains('-;'), false);
    expect(out.contains('color:red'), true);
    expect(out.contains('none-foo'), true);
  });

  test('mdxSanitizeCss strips at-rules but unwraps media', () {
    const css =
        '@charset "utf-8";@import "x.css";'
        '@font-face{font-family:f;src:url(f.woff)}'
        '@media screen{.a{color:red}}'
        '.b{color:blue}';
    final out = mdxSanitizeCss(css);
    expect(out.contains('@'), false);
    expect(out.contains('.a{color:red}'), true);
    expect(out.contains('.b{color:blue}'), true);
  });

  test('mdxSanitizeCss keeps @ inside urls', () {
    const css = '.a{background:url(http://x/a@2x.png)}';
    expect(mdxSanitizeCss(css), contains('@2x.png'));
  });

  test('mdxSanitizeCss drops empty values with important', () {
    const css = '.a{font-size: !important;color:red}';
    final out = mdxSanitizeCss(css);
    expect(out.contains('font-size'), false);
    expect(out.contains('color:red'), true);
  });

  test('mdxSanitizeCss drops digit-leading selector rules', () {
    const css = 'body{font-size:14px}.10O{font-weight:bold}';
    final out = mdxSanitizeCss(css);
    expect(out.contains('.10O'), false);
    expect(out.contains('font-size:14px'), true);
  });

  test('mdxSanitizeCss drops stray closes and closes open blocks', () {
    const css = '.a{color:red}: #1166AA\n}.b{color:blue}.c{color:green';
    final out = mdxSanitizeCss(css);
    expect(out.contains('#1166AA'), false);
    expect(out.contains('.a{color:red}'), true);
    expect(out.contains('.b{color:blue}'), true);
    expect(out.contains('.c{color:green}'), true);
  });
}
