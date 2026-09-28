import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Helpers for rendering MDX entries in a real WebView, mirroring Ciyue:
/// a `<basename>.css` / `<basename>.js` bundle is auto-injected per entry
/// and every other resource (images, audio, fonts, extra stylesheets)
/// resolves through the per-dictionary asset handler backed by sidecar
/// files and the `.mdd` archives.

/// Base URL the entry documents are loaded with. Resource requests against
/// this host are intercepted by the asset path handler — no network involved.
const String mdxWebAssetBaseUrl = 'http://mdx.internal/';

/// Custom schemes served inside the WebView, same names as Ciyue.
const List<String> mdxWebCustomSchemes = ['entry', 'sound'];

/// Full HTML document for one lookup. Stylesheets/scripts are linked (not
/// inlined) so relative `url(...)` references inside CSS keep resolving
/// through the asset handler.
String buildMdxWebDocument({
  required String? cssHref,
  required String? jsSrc,
  required List<String> bodies,
  bool collapseByDefault = true,
}) {
  final buf = StringBuffer(
    '<!DOCTYPE html><html><head>'
    '<meta charset="utf-8">'
    '<meta name="viewport" content="width=device-width, initial-scale=1">'
    '<meta name="color-scheme" content="light dark">',
  );
  if (cssHref != null) {
    buf.write('<link rel="stylesheet" href="$cssHref">');
  }
  if (jsSrc != null) {
    buf.write('<script defer src="$jsSrc"></script>');
  }
  // Inject CSS to ensure transparent background (no red/ugly default)
  // Pass collapseByDefault as CSS custom property for dictionary JS to read
  // Add horizontal scroll for wide tables, code blocks, and images
  buf.write('<style>');
  buf.write('html,body{background:transparent;margin:0;padding:0}');
  buf.write(':root{--mdx-collapse-by-default:' + (collapseByDefault ? '1' : '0') + '}');
  buf.write('table{display:block;max-width:100%;overflow-x:auto;white-space:nowrap}');
  buf.write('pre,code{overflow-x:auto}');
  buf.write('img{max-width:100%;height:auto}');
  buf.write('</style>');
  buf.write('</head><body style="background:transparent">');
  for (final body in bodies) {
    buf.write(body);
  }
  return (buf..write('</body></html>')).toString();
}

/// Adapted from Ciyue's `dictionaryEntryLinkScript` (MIT, mumu-lhl):
/// Chromium can truncate unescaped Unicode in custom-scheme navigation
/// before `shouldOverrideUrlLoading` sees it, so percent-encode non-ASCII
/// characters in `entry://` links at click time.
const String mdxEntryLinkFixScript = r"""
document.addEventListener('click', function (event) {
  const target = event.target;
  const anchor = target instanceof Element ? target.closest('a[href]') : null;
  if (!anchor) return;
  const href = anchor.getAttribute('href');
  if (!/^entry:\/\//i.test(href)) return;
  const encoded = href.replace(/[^\x00-\x7F]+/gu, function (text) {
    return encodeURI(text);
  });
  if (encoded !== href) anchor.setAttribute('href', encoded);
}, true);
""";

/// Reports `document.body.scrollHeight` to the `MdxWebHeight` JS handler a
/// few times after load so late JS-driven layout (tabs, collapsibles) is
/// picked up, then stops to avoid a permanent rAF drain.
const String mdxHeightPollScript = r"""
(function () {
  var tries = 0;
  var last = 0;
  var timer = setInterval(function () {
    tries++;
    var h = document.body ? document.body.scrollHeight : 0;
    if (h !== last) {
      last = h;
      window.flutter_inappwebview.callHandler('MdxWebHeight', h);
    }
    if (tries >= 10) clearInterval(timer);
  }, 300);
})();
""";

/// Plays a `sound://` resource tapped in an entry (pronunciations stored in
/// the `.mdd`), same one-shot pattern as Ciyue's `playSound`.
Future<void> playMdxAudioBytes(Uint8List bytes, String mimeType) async {
  final player = AudioPlayer();
  try {
    await player.setSourceBytes(bytes, mimeType: mimeType);
    await player.resume();
    player.onPlayerComplete.listen((_) => player.release());
  } catch (_) {
    await player.release();
  }
}
