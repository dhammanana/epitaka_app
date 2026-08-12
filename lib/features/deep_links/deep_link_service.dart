import 'dart:async';
import 'dart:developer' as developer;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/supabase_config.dart';
import '../annotations/services/auth_service.dart';
import '../../router/app_router.dart';

/// Handles incoming deep links and navigates to the appropriate app
/// screen.
///
/// Supports two link formats:
///
/// **1. Custom scheme** (`epitaka://`):
///   - `epitaka://reader/{bookId}?paraId={paraId}&lineId={lineId}` — open a
///     book at a specific paragraph/line (both optional).
///   - `epitaka://reader/{bookId}` — open a book.
///   - `epitaka://search?q={query}` — open global search with a query.
///
/// **2. Universal / App Links** (`https://epitaka.org/app/...`):
///   - `https://epitaka.org/app/{bookId}/{paraId}/{lineId}` — open a book at
///     a specific paragraph/line (both optional).
///   - `https://epitaka.org/app/{bookId}` — open a book.
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

  /// The full string of the last OAuth callback already exchanged. On
  /// Android a cold-start callback is delivered BOTH by
  /// [AppLinks.getInitialLink] AND again by [AppLinks.uriLinkStream] (the
  /// plugin pushes the initial link through the stream when it is first
  /// listened to). The PKCE code is single-use — the second
  /// [AuthService.handleRedirectUri] would throw "Code verifier could not
  /// be found in local storage" because gotrue deletes the verifier after
  /// the first successful exchange. Dedupe on the whole URI so the
  /// exchange runs exactly once regardless of where the params live.
  String? _lastOAuthCallbackUri;

  /// True while a PKCE exchange is in flight; repeat callbacks are ignored
  /// so rapid duplicate deliveries can't race each other.
  bool _oauthExchangeInFlight = false;

  /// Parse an incoming [uri] and navigate accordingly.
  void _handleUri(Uri uri) {
    developer.log(
      '[DEEPLINK] Handling URI: scheme=${uri.scheme} host=${uri.host} '
      'path=${uri.path} query=${uri.query}',
      name: 'epitaka.deeplink',
    );

    // OAuth PKCE callback — MUST be handled before any path-segment
    // routing AND before the navigator-context check below. The callback
    // URI is `epitaka://login-callback/?code=…` which has an EMPTY path
    // (the route lives in the host), so the `pathSegments.isEmpty` checks
    // below would return early and drop it. Dropping it means the PKCE
    // exchange never completes → the Google sign-in looks like an infinite
    // loop (every account tap starts a fresh OAuth that never finishes).
    //
    // It must also run even when the navigator context is not mounted yet
    // (cold start via the redirect): exchanging the code needs no
    // navigator, but returning early here would lose the only copy of the
    // callback and leave the user stuck in the browser.
    if (uri.scheme == SupabaseConfig.oauthScheme &&
        (uri.host == SupabaseConfig.oauthRedirectPath ||
            (uri.pathSegments.isNotEmpty &&
                uri.pathSegments.first ==
                    SupabaseConfig.oauthRedirectPath))) {
      final uriString = uri.toString();
      if (uriString == _lastOAuthCallbackUri || _oauthExchangeInFlight) {
        developer.log(
          '[DEEPLINK] OAuth callback already being handled — skipping',
          name: 'epitaka.deeplink',
        );
        return;
      }
      developer.log(
        '[DEEPLINK] OAuth callback received — completing session',
        name: 'epitaka.deeplink',
      );
      _lastOAuthCallbackUri = uriString;
      _oauthExchangeInFlight = true;
      AuthService.instance.handleRedirectUri(uri).whenComplete(() {
        _oauthExchangeInFlight = false;
      });
      return;
    }

    final ctx = _context;
    if (ctx == null || !ctx.mounted) {
      developer.log(
        '[DEEPLINK] No valid context to navigate — dropping link: $uri',
        name: 'epitaka.deeplink',
      );
      return;
    }

    // Support both custom scheme (epitaka://reader/...) and universal
    // links (https://epitaka.org/app/...).
    final isEpitaka = uri.scheme == 'epitaka' ||
        uri.host == 'epitaka.org' ||
        uri.host == 'epitaka.app';
    if (!isEpitaka) return;

    final segments = uri.pathSegments;
    if (segments.isEmpty) return;

    // For universal links (epitaka.org/app/...) the first segment is 'app'.
    // Strip it so the remaining segments match the same switch cases as
    // custom scheme links.
    final effectiveSegments =
        (uri.scheme == 'epitaka') ? segments : _stripAppPrefix(segments);
    if (effectiveSegments.isEmpty) return;

    switch (effectiveSegments.first) {
      case 'reader':
        _handleReaderLink(uri, effectiveSegments, ctx);
        break;
      case 'search':
        _handleSearchLink(uri, ctx);
        break;
      default:
        developer.log(
          '[DEEPLINK] Unknown path: ${effectiveSegments.first}',
          name: 'epitaka.deeplink',
        );
    }
  }

  /// Strip the `/app` prefix from universal link segments so that
  /// `/app/reader/{bookId}` → `[reader, {bookId}]`.
  /// Returns the segments unchanged if the first segment is not 'app'.
  List<String> _stripAppPrefix(List<String> segments) {
    if (segments.isNotEmpty && segments.first == 'app') {
      return segments.sublist(1);
    }
    return segments;
  }

  /// Handle a reader deep link.
  ///
  /// Custom scheme: `epitaka://reader/{bookId}?paraId={paraId}&lineId={lineId}`
  /// Universal link: `https://epitaka.org/app/{bookId}/{paraId}/{lineId}`
  ///
  /// For universal links the `/app` prefix has already been stripped by
  /// [_stripAppPrefix] so [segments] looks like `[reader, {bookId}, {paraId}, {lineId}]`.
  void _handleReaderLink(
    Uri uri,
    List<String> segments,
    BuildContext context,
  ) {
    // segments[0] is 'reader'. The bookId is at index 1 (if present).
    if (segments.length < 2) {
      // No book ID — just navigate to the reader screen.
      context.go(AppRoutes.reader);
      return;
    }

    final bookId = segments[1];
    if (bookId.isEmpty) {
      context.go(AppRoutes.reader);
      return;
    }

    // For universal links the paraId/lineId may come from path segments
    // (indices 2 and 3), or from query params for custom schemes.
    String? paraIdStr;
    String? lineIdStr;

    if (uri.scheme == 'epitaka') {
      // Custom scheme — para/line come from query params
      paraIdStr = uri.queryParameters['paraId'];
      lineIdStr = uri.queryParameters['lineId'];
    } else {
      // Universal link — para/line can be path segments or query params
      paraIdStr = segments.length > 2 ? segments[2] : null;
      lineIdStr = segments.length > 3 ? segments[3] : null;
      // Query params override path segments if both are provided
      paraIdStr = uri.queryParameters['paraId'] ?? paraIdStr;
      lineIdStr = uri.queryParameters['lineId'] ?? lineIdStr;
    }

    final paraId = paraIdStr != null ? int.tryParse(paraIdStr) : null;
    final lineId = lineIdStr != null ? int.tryParse(lineIdStr) : null;

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
