import 'dart:async';
import 'dart:developer' as developer;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';

/// Handles incoming deep links (epitaka:// URLs) and navigates to the
/// appropriate app screen.
///
/// Supported link formats:
///   - `epitaka://reader/{bookId}?paraId={paraId}` — open a book at a
///     specific paragraph (optional).
///   - `epitaka://reader/{bookId}` — open a book.
///   - `epitaka://search?q={query}` — open global search with a query.
class DeepLinkService {
  DeepLinkService._();

  static DeepLinkService? _instance;
  static DeepLinkService get instance => _instance ??= DeepLinkService._();

  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSub;

  /// Whether the service has been initialised.
  bool _initialised = false;

  /// The navigator key attached to GoRouter. Set once during init.
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Initialise the deep link listener. Call from a post-frame callback
  /// in the app's top-level widget.
  ///
  /// [navigatorKey] must be the same [GlobalKey<NavigatorState>] that is
  /// passed to GoRouter so that [GoRouterState.of] resolves correctly.
  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    if (_initialised) return;
    _initialised = true;
    _navigatorKey = navigatorKey;

    // Skip on web — the web version uses standard URL navigation via
    // go_router's URL path strategy, not a custom scheme.
    if (kIsWeb) return;

    try {
      _appLinks = AppLinks();

      // ── Handle link that launched the app ──────────────────────────
      final initialUri = await _appLinks!.getInitialLink();
      if (initialUri != null) {
        developer.log(
          '[DEEPLINK] Initial link: $initialUri',
          name: 'epitaka.deeplink',
        );
        _handleUri(initialUri);
      }

      // ── Subscribe to subsequent links ──────────────────────────────
      _linkSub = _appLinks!.uriLinkStream.listen((Uri uri) {
        developer.log(
          '[DEEPLINK] Stream link: $uri',
          name: 'epitaka.deeplink',
        );
        _handleUri(uri);
      });
    } catch (e) {
      developer.log(
        '[DEEPLINK] Initialisation failed: $e',
        name: 'epitaka.deeplink',
      );
    }
  }

  /// Dispose the link subscription. Call from [dispose].
  void dispose() {
    _linkSub?.cancel();
    _linkSub = null;
    _appLinks = null;
    _navigatorKey = null;
    _instance = null;
    _initialised = false;
  }

  /// Resolve the current navigator context. Returns null if not mounted.
  BuildContext? get _context => _navigatorKey?.currentContext;

  /// Parse an incoming [uri] and navigate accordingly.
  void _handleUri(Uri uri) {
    final ctx = _context;
    if (ctx == null || !ctx.mounted) {
      developer.log(
        '[DEEPLINK] No valid context to navigate — dropping link: $uri',
        name: 'epitaka.deeplink',
      );
      return;
    }

    developer.log(
      '[DEEPLINK] Handling URI: scheme=${uri.scheme} host=${uri.host} '
      'path=${uri.path} query=${uri.query}',
      name: 'epitaka.deeplink',
    );

    // Support both custom scheme (epitaka://reader/...) and universal
    // links (https://epitaka.app/reader/...).
    final isEpitaka = uri.scheme == 'epitaka' || uri.host == 'epitaka.app';
    if (!isEpitaka) return;

    final segments = uri.pathSegments;
    if (segments.isEmpty) return;

    switch (segments.first) {
      case 'reader':
        _handleReaderLink(uri, segments, ctx);
        break;
      case 'search':
        _handleSearchLink(uri, ctx);
        break;
      default:
        developer.log(
          '[DEEPLINK] Unknown path: ${segments.first}',
          name: 'epitaka.deeplink',
        );
    }
  }

  /// Handle a reader deep link.
  ///
  /// Format: `epitaka://reader/{bookId}?paraId={paraId}&lineId={lineId}`
  void _handleReaderLink(
    Uri uri,
    List<String> segments,
    BuildContext context,
  ) {
    if (segments.length < 2) {
      // No book ID — just navigate to the reader screen.
      context.go(AppRoutes.reader);
      return;
    }

    final bookId = segments[1];
    // Validate bookId is non-empty to prevent navigation with blank param.
    if (bookId.isEmpty) {
      context.go(AppRoutes.reader);
      return;
    }
    final paraId = uri.queryParameters['paraId'] != null
        ? int.tryParse(uri.queryParameters['paraId']!)
        : null;
    final lineId = uri.queryParameters['lineId'] != null
        ? int.tryParse(uri.queryParameters['lineId']!)
        : null;

    // Navigate to reader with query parameters so the reader screen
    // can open the book tab on mount.
    final queryParams = <String, String>{
      'bookId': bookId,
      if (paraId != null) 'paraId': paraId.toString(),
      if (lineId != null) 'lineId': lineId.toString(),
    };

    context.go(
      Uri(path: AppRoutes.reader, queryParameters: queryParams).toString(),
    );
  }

  /// Handle a search deep link.
  ///
  /// Format: `epitaka://search?q={query}`
  void _handleSearchLink(Uri uri, BuildContext context) {
    final query = uri.queryParameters['q'] ?? '';
    final queryParams = <String, String>{
      if (query.isNotEmpty) 'q': query,
    };
    context.go(
      Uri(path: AppRoutes.search, queryParameters: queryParams).toString(),
    );
  }
}
