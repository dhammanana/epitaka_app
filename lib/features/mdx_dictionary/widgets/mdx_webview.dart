import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';

import '../../../core/utils/app_localizations.dart';
import '../providers/mdx_web_providers.dart';
import '../services/mdx_web.dart';

/// Serves dictionary bundle files (sidecar files next to the `.mdx` first,
/// then the `.mdd` archives) to the embedded WebView, mirroring Ciyue's
/// `LocalResourcesPathHandler`. Covers images, audio, CSS, JS and fonts.
class MdxAssetPathHandler extends CustomPathHandler {
  final Future<Uint8List?> Function(String key) readResource;

  MdxAssetPathHandler({required this.readResource}) : super(path: '/');

  @override
  Future<WebResourceResponse?> handle(String path) async {
    if (path == 'favicon.ico') return WebResourceResponse(data: null);
    var key = path;
    if (key.startsWith('/')) key = key.substring(1);
    try {
      key = Uri.decodeComponent(key);
    } catch (_) {}
    if (key.isEmpty || key.contains('..')) {
      return WebResourceResponse(data: null);
    }
    try {
      final bytes = await readResource(key);
      if (bytes == null) return WebResourceResponse(data: null);
      return WebResourceResponse(
        data: bytes,
        contentType: lookupMimeType(key),
      );
    } catch (_) {
      return WebResourceResponse(data: null);
    }
  }
}

/// Definition body rendered in a real WebView (Ciyue-style): full CSS/JS
/// support with MDD resources served natively (images, `<audio>` playback).
/// Unsupported platforms (Linux, web) must use the legacy flutter_html path.
class MdxWebViewBody extends ConsumerStatefulWidget {
  final String dictId;
  final String word;
  final String document;
  final Future<Uint8List?> Function(String key) readResource;
  final void Function(String word)? onEntryTap;

  static bool get isSupported =>
      !kIsWeb &&
      (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isWindows);

  const MdxWebViewBody({
    super.key,
    required this.dictId,
    required this.word,
    required this.document,
    required this.readResource,
    this.onEntryTap,
  });

  @override
  ConsumerState<MdxWebViewBody> createState() => _MdxWebViewBodyState();
}

class _MdxWebViewBodyState extends ConsumerState<MdxWebViewBody> {
  String get _heightKey => mdxWebHeightKey(widget.dictId, widget.word);

  void _reportHeight(num raw) {
    final h = raw.toDouble();
    if (h <= 0 || !mounted) return;
    final heights = ref.read(mdxWebHeightsProvider);
    if ((heights[_heightKey] ?? 0) == h) return;
    ref.read(mdxWebHeightsProvider.notifier).update(
          (m) => {...m, _heightKey: h},
        );
  }

  String _entryWord(Uri url) {
    var word = url.toString().replaceFirst(
          RegExp('^entry://', caseSensitive: false),
          '',
        );
    try {
      word = Uri.decodeComponent(word);
    } catch (_) {}
    return word.split('#').first.split('?').first.trim();
  }

  String _soundKey(Uri url) {
    var key = url
        .toString()
        .replaceFirst(RegExp(r'^sound://', caseSensitive: false), '');
    try {
      key = Uri.decodeComponent(key);
    } catch (_) {}
    return key.split('#').first.split('?').first.trim();
  }

  @override
  Widget build(BuildContext context) {
    final height =
        ref.watch(mdxWebHeightsProvider.select((m) => m[_heightKey])) ?? 140;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final loc = AppLocalizations.of(context);

    InAppWebViewController? webViewController;
    String selectedText = '';

    final contextMenu = ContextMenu(
      settings: ContextMenuSettings(hideDefaultSystemContextMenuItems: true),
      menuItems: [
        ContextMenuItem(
          id: 1,
          title: loc.copy,
          action: () async {
            await webViewController?.clearFocus();
            if (selectedText.isNotEmpty) {
              await Clipboard.setData(ClipboardData(text: selectedText));
            }
          },
        ),
        ContextMenuItem(
          id: 2,
          title: loc.lookUp,
          action: () async {
            if (selectedText.isNotEmpty) {
              widget.onEntryTap?.call(selectedText.trim());
            }
          },
        ),
        ContextMenuItem(
          id: 3,
          title: loc.speak,
          action: () async {
            await webViewController?.clearFocus();
            if (selectedText.isNotEmpty) {
              final key = selectedText.trim();
              try {
                final bytes = await widget.readResource(key);
                if (bytes != null && bytes.isNotEmpty) {
                  await playMdxAudioBytes(bytes, lookupMimeType(key) ?? '');
                }
              } catch (_) {}
            }
          },
        ),
      ],
      onCreateContextMenu: (hitTestResult) async {
        selectedText = await webViewController?.getSelectedText() ?? '';
      },
    );

    return SizedBox(
      height: height.clamp(80, 4000).toDouble(),
      child: InAppWebView(
        initialUserScripts: UnmodifiableListView([
          UserScript(
            source: mdxEntryLinkFixScript,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          ),
        ]),
        initialData: InAppWebViewInitialData(
          data: widget.document,
          baseUrl: WebUri(mdxWebAssetBaseUrl),
        ),
        initialSettings: InAppWebViewSettings(
          useWideViewPort: false,
          transparentBackground: true,
          javaScriptEnabled: true,
          algorithmicDarkeningAllowed: !isLight,
          resourceCustomSchemes: mdxWebCustomSchemes,
          webViewAssetLoader: WebViewAssetLoader(
            domain: Uri.parse(mdxWebAssetBaseUrl).host,
            httpAllowed: true,
            pathHandlers: [
              MdxAssetPathHandler(readResource: widget.readResource),
            ],
          ),
        ),
        onWebViewCreated: (controller) {
          webViewController = controller;
          controller.addJavaScriptHandler(
            handlerName: 'MdxWebHeight',
            callback: (args) {
              if (args.isNotEmpty && args[0] is num) {
                _reportHeight(args[0] as num);
              }
            },
          );
        },
        contextMenu: contextMenu,
        onLoadStop: (controller, _) async {
          try {
            final h = await controller.evaluateJavascript(
              source: 'document.body ? document.body.scrollHeight : 0',
            );
            if (h is num) _reportHeight(h);
            await controller.evaluateJavascript(source: mdxHeightPollScript);
          } catch (_) {}
        },
        onLoadResourceWithCustomScheme: (controller, request) async {
          final url = request.url;
          if (url.scheme != 'sound') return null;
          final key = _soundKey(url);
          if (key.isEmpty) return null;
          try {
            final bytes = await widget.readResource(key);
            if (bytes == null || bytes.isEmpty) return null;
            return CustomSchemeResponse(
              data: bytes,
              contentType: lookupMimeType(key) ?? 'application/octet-stream',
            );
          } catch (_) {
            return null;
          }
        },
        shouldOverrideUrlLoading: (controller, action) async {
          final url = action.request.url;
          if (url == null) return NavigationActionPolicy.CANCEL;
          if (url.scheme == 'entry') {
            final word = _entryWord(url);
            if (word.isNotEmpty) widget.onEntryTap?.call(word);
            return NavigationActionPolicy.CANCEL;
          }
          if (url.scheme == 'sound') {
            final key = _soundKey(url);
            try {
              final bytes = await widget.readResource(key);
              if (bytes != null && bytes.isNotEmpty) {
                await playMdxAudioBytes(bytes, lookupMimeType(key) ?? '');
              }
            } catch (_) {}
            return NavigationActionPolicy.CANCEL;
          }
          return NavigationActionPolicy.ALLOW;
        },
      ),
    );
  }
}
