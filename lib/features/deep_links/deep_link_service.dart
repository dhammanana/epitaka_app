import 'dart:async';
import 'dart:developer' as developer;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/supabase_config.dart';
import '../../core/providers/database_provider.dart';
import '../annotations/services/auth_service.dart';
import '../reader/providers/reader_tabs_provider.dart';
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
///   - `https://epitaka.org/app/{lang}/{bookId}/{heading-slug}#{paraId}-{lineId}`
///     — the canonical shape the app copies. Opens the book at a specific
///     paragraph/line (both optional). The heading slug (heading-para_id)
///     matches the website's canonical /{lang}/book URL, so the web can
///     rewrite `/app` → `/{lang}/book` keeping everything else identical.
///   - `https://epitaka.org/app/{lang}/{bookId}` — open a book.
///   - Legacy: `https://epitaka.org/app/{bookId}/{paraId}/{lineId}`.
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

    if (uri.scheme != 'epitaka') {
      // Universal links: every epitaka.org/app/... path is a reader link
      // except the explicit /app/search?q=… form. The canonical shape starts
      // with the language code (/app/{lang}/{bookId}/{slug}#{paraId}-{lineId});
      // legacy ones start with the bookId or the old 'reader' prefix.
      if (effectiveSegments.first == 'search') {
        _handleSearchLink(uri, ctx);
      } else {
        unawaited(_handleReaderLink(uri, effectiveSegments, ctx));
      }
      return;
    }

    switch (effectiveSegments.first) {
      case 'reader':
        unawaited(_handleReaderLink(uri, effectiveSegments, ctx));
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

  /// Handle a reader deep link and open the book in a reader tab.
  ///
  /// Custom scheme: `epitaka://reader/{bookId}?paraId={paraId}&lineId={lineId}`
  /// Canonical universal link:
  ///   `https://epitaka.org/app/{lang}/{bookId}/{heading-slug}#{paraId}-{lineId}`
  /// Legacy universal links: `/app/{bookId}[/{paraId}[/{lineId}]]` and
  /// `/app/reader/{bookId}[?paraId=…&lineId=…]`.
  ///
  /// For universal links the `/app` prefix has already been stripped by
  /// [_stripAppPrefix], so [segments] starts at the language code or bookId.
  /// The canonical shape carries the paragraph/line in the URL fragment
  /// (`#paraId-lineId`); legacy shapes use path segments or query params.
  Future<void> _handleReaderLink(
    Uri uri,
    List<String> segments,
    BuildContext context,
  ) async {
    String bookId;
    String? paraIdStr;
    String? lineIdStr;

    // Canonical shape: the position lives in the fragment `#paraId-lineId`.
    final fromFragment = _parseFragmentParaLine(uri.fragment);
    // New-format links start with the language code: /app/{lang}/{bookId}/…
    final hasLangPrefix = segments.length >= 2 && _isTranslationLang(segments[0]);

    if (uri.scheme == 'epitaka') {
      // Custom scheme — bookId is after 'reader', para/line come from query
      // params.
      bookId = segments.length > 1 ? segments[1] : '';
      paraIdStr = uri.queryParameters['paraId'] ?? fromFragment?.$1;
      lineIdStr = uri.queryParameters['lineId'] ?? fromFragment?.$2;
    } else if (hasLangPrefix) {
      // Canonical app link: /app/{lang}/{bookId}[/{slug}]#{paraId}-{lineId}
      // The slug is ignored here — the fragment holds the position.
      bookId = segments[1];
      paraIdStr = fromFragment?.$1;
      lineIdStr = fromFragment?.$2;
    } else if (segments.first == 'reader') {
      // Legacy: /app/reader/{bookId}[?paraId=…&lineId=…]
      bookId = segments.length > 1 ? segments[1] : '';
      paraIdStr = uri.queryParameters['paraId'] ?? fromFragment?.$1;
      lineIdStr = uri.queryParameters['lineId'] ?? fromFragment?.$2;
    } else if (fromFragment != null) {
      // bookId first with the position in the fragment: /app/{bookId}#{paraId}-{lineId}
      bookId = segments[0];
      paraIdStr = fromFragment.$1;
      lineIdStr = fromFragment.$2;
    } else {
      // Legacy path segments: /app/{bookId}[/{paraId}[/{lineId}]]
      bookId = segments[0];
      paraIdStr = segments.length > 1 ? segments[1] : null;
      lineIdStr = segments.length > 2 ? segments[2] : null;
    }

    if (bookId.isEmpty) {
      if (context.mounted) context.go(AppRoutes.reader);
      return;
    }
    if (!context.mounted) return;

    final paraId = paraIdStr != null ? int.tryParse(paraIdStr) : null;
    final lineId = lineIdStr != null ? int.tryParse(lineIdStr) : null;

    // Open the book as a reader tab. The reader screen is tab-driven; the
    // old approach of writing bookId/paraId/lineId into the route query
    // string was never read back, so the book never opened.
    final container = ProviderScope.containerOf(context);
    final bookName = await _bookNameFor(container, bookId);
    if (!context.mounted) return;

    container.read(readerTabsProvider.notifier).openTab(
          ReaderTabInfo(
            bookId: bookId,
            bookName: bookName,
            initialParaId: paraId,
            initialLineId: lineId,
          ),
        );
    context.go(AppRoutes.reader);
  }

  /// Parse the canonical fragment `#paraId[-lineId]` into (paraId, lineId)
  /// strings. Returns null when the fragment isn't numeric (e.g. old links
  /// that carried a named anchor instead of a position).
  (String, String?)? _parseFragmentParaLine(String fragment) {
    if (fragment.isEmpty) return null;
    final dashIndex = fragment.indexOf('-');
    final paraPart =
        dashIndex == -1 ? fragment : fragment.substring(0, dashIndex);
    if (int.tryParse(paraPart) == null) return null;
    final linePart = dashIndex == -1 ? null : fragment.substring(dashIndex + 1);
    if (linePart != null && int.tryParse(linePart) == null) return null;
    return (paraPart, linePart);
  }

  /// True when [code] is a known translation language that may prefix the
  /// bookId in a canonical app link (/app/{lang}/{bookId}/…). Kept in sync
  /// with the translation languages the app can copy links for (see
  /// assets/translations_manifest.json — the source of truth).
  bool _isTranslationLang(String code) => _translationLangCodes.contains(code);

  static const Set<String> _translationLangCodes = {
    'en',
    'vi',
    'my',
    'si',
    'th',
    'lo',
    'ta',
    'de',
    'pt',
    // 'pi' is kept for legacy links that referenced the Pali text directly.
    'pi',
  };

  /// Resolve the display name for [bookId] so the newly opened reader tab
  /// shows a proper title immediately. Falls back to the raw bookId.
  Future<String> _bookNameFor(ProviderContainer container, String bookId) async {
    try {
      final db = await container.read(epitakaDbProvider.future);
      final rows = await (db.select(db.books)
            ..where((b) => b.bookId.equals(bookId))
            ..limit(1))
          .get();
      final name = rows.isNotEmpty ? rows.first.bookName : null;
      if (name != null && name.isNotEmpty) return name;
    } catch (e) {
      developer.log(
        '[DEEPLINK] Book name lookup failed for $bookId: $e',
        name: 'epitaka.deeplink',
      );
    }
    return bookId;
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
