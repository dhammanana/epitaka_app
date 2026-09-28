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

/// Immediate one-shot height read used right after load. Takes the max of
/// body/documentElement scroll/offset/client heights: dictionary CSS often
/// moves the real extent onto `documentElement` (or collapses `body` via
/// JS), so `body.scrollHeight` alone over- or under-reports.
const String mdxMeasureHeightScript = r"""
(function () {
  var b = document.body, e = document.documentElement;
  if (!b || !e) return 0;
  return Math.max(
    b.scrollHeight, b.offsetHeight, e.scrollHeight, e.offsetHeight, e.clientHeight
  );
})()
""";

/// Reports the content height to the `MdxWebHeight` JS handler whenever
/// layout settles, and keeps watching: dictionary bundles (linked CSS/JS,
/// collapsibles, MDD images served through the asset handler) keep
/// reflowing well after `onLoadStop` — typically collapsing from an
/// initially tall unstyled state to a shorter final one. The previous
/// fixed 10 x 300ms poll of `body.scrollHeight` missed late shrinks, so
/// the transient tall value stuck in the height cache and the card
/// rendered too high until collapse/expand recreated the WebView.
/// Event observers (Resize/Mutation/window/img load) stay active while the
/// page lives; the interval is only a backstop and stops after ~15s.
const String mdxHeightPollScript = r"""
(function () {
  if (window.__mdxHeightObserved) return;
  window.__mdxHeightObserved = true;
  function measure() {
    var b = document.body, e = document.documentElement;
    if (!b || !e) return 0;
    return Math.max(
      b.scrollHeight, b.offsetHeight, e.scrollHeight, e.offsetHeight, e.clientHeight
    );
  }
  var last = 0;
  function report(force) {
    try {
      var h = measure();
      if (h > 0 && (force || h !== last)) {
        last = h;
        window.flutter_inappwebview.callHandler('MdxWebHeight', h);
      }
    } catch (_) {}
  }
  report(true);
  try {
    if (window.ResizeObserver) {
      var ro = new ResizeObserver(function () { report(false); });
      ro.observe(document.body);
      ro.observe(document.documentElement);
    }
  } catch (_) {}
  try {
    var mo = new MutationObserver(function () { report(false); });
    mo.observe(document.documentElement, {
      childList: true, subtree: true, attributes: true, characterData: true,
    });
  } catch (_) {}
  window.addEventListener('resize', function () { report(false); });
  window.addEventListener('orientationchange', function () { report(false); });
  window.addEventListener('load', function () { report(false); });
  document.addEventListener('DOMContentLoaded', function () { report(false); });
  document.addEventListener('load', function () { report(false); }, true);
  document.addEventListener('error', function () { report(false); }, true);
  var ticks = 0;
  var timer = setInterval(function () {
    ticks++;
    report(false);
    if (ticks >= 30) clearInterval(timer);
  }, 500);
})();
""";

/// Safety net for dictionaries whose entries inject their scripts
/// dynamically (e.g. DPD's `<link class="load_js">` bootstrap, which appends
/// `<script src="...">` at parse time). Those scripts often finish loading
/// AFTER `DOMContentLoaded` — especially when served from `.mdd` archives —
/// so the page's own loader (DPD's `loadData()`, wired to `DOMContentLoaded`
/// in `main.js`) never runs: buttons stay dead and sections sit at
/// "loading..." forever. Polls briefly after load and runs the loader once
/// its script has arrived; `loadData()` is idempotent (filled sections are
/// re-set to the same HTML), so a second run after the page's own listener
/// is harmless. Gives up after ~15s.
const String mdxContentLoaderScript = r"""
(function () {
  if (window.__mdxContentLoaderInstalled) return;
  window.__mdxContentLoaderInstalled = true;
  var tries = 0;
  var timer = setInterval(function () {
    tries++;
    try {
      if (document.getElementsByClassName('load_js').length === 0) {
        clearInterval(timer);
        return;
      }
      if (typeof loadData === 'function' && !window.__mdxLoadDataDone) {
        loadData();
        window.__mdxLoadDataDone = true;
        clearInterval(timer);
      } else if (tries >= 30) {
        clearInterval(timer);
      }
    } catch (_) {
      // Loader dependencies (template/data files) still arriving: retry.
      if (tries >= 30) clearInterval(timer);
    }
  }, 500);
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
