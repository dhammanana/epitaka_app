// lib/features/annotations/services/auth_service.dart
//
// Thin wrapper around Supabase auth (Google OAuth). All cloud features are
// optional: if Supabase failed to initialize at startup, every method here
// degrades to a safe no-op / false and the app keeps working offline.

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  /// True when Supabase initialized successfully at startup.
  bool get isAvailable {
    try {
      Supabase.instance.client.auth;
      return true;
    } catch (_) {
      return false;
    }
  }

  User? get currentUser {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Stream of auth state changes. Never throws — on init failure it emits
  /// [AuthState.unknown] once.
  Stream<AuthState> authStateChanges() {
    try {
      final client = Supabase.instance.client.auth;
      return client.onAuthStateChange.map((data) {
        return AuthState(
          status: data.session != null
              ? AuthStatus.signedIn
              : AuthStatus.signedOut,
          user: data.session?.user,
        );
      });
    } catch (_) {
      return Stream.value(const AuthState(status: AuthStatus.unknown));
    }
  }

  /// True when we use Google Play Services' native sign-in instead of the
  /// browser. Currently Android only — iOS still uses the browser flow.
  bool get _useNativeGoogleSignIn {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  /// Whether [GoogleSignIn.instance.initialize] has completed. The plugin
  /// requires it to run exactly once before any other call.
  bool _googleSignInInitialized = false;

  /// Initialize the native Google Sign-In manager (idempotent).
  ///
  /// On Android the ID-token audience is taken from [serverClientId] — the
  /// plugin's Android implementation requires it ("CredentialManager
  /// requires a serverClientId") and passes it to
  /// `GetSignInWithGoogleOption.Builder(...)`, which becomes the `aud`
  /// claim of the returned ID token. It must therefore be the Web OAuth
  /// client ID that the Supabase Google provider validates against — see
  /// [SupabaseConfig.googleWebClientId]. Passed explicitly so no
  /// `google-services.json` is required.
  Future<bool> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return true;
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: SupabaseConfig.googleWebClientId,
      );
      _googleSignInInitialized = true;
      return true;
    } catch (e) {
      developer.log(
        '[AUTH] GoogleSignIn.initialize failed: $e',
        name: 'epitaka.sync',
      );
      return false;
    }
  }

  /// Begin Google sign-in.
  ///
  /// **Android:** native Google Sign-In via Google Play Services
  /// ([_signInWithGoogleNative]) — a system account-picker dialog returns
  /// the ID token directly to the app. No browser, no custom-scheme
  /// redirect. This replaces the browser OAuth flow, which hangs at
  /// Google's account chooser on Android because Chrome no longer hands
  /// the `epitaka://` redirect back to the app.
  ///
  /// **Web / desktop / iOS:** browser-based OAuth PKCE flow
  /// ([_signInWithGoogleBrowser]). On web the plugin's
  /// `detectSessionInUri` (enabled in main.dart) recovers the session from
  /// the callback URL; on desktop/iOS the deep-link listener →
  /// [handleRedirectUri] completes the exchange.
  Future<bool> signInWithGoogle() async {
    if (_useNativeGoogleSignIn) return _signInWithGoogleNative();
    return _signInWithGoogleBrowser();
  }

  /// Android: native Google account picker → ID token → Supabase session.
  Future<bool> _signInWithGoogleNative() async {
    if (!await _ensureGoogleSignInInitialized()) return false;
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        developer.log(
          '[AUTH] Native Google sign-in returned no ID token',
          name: 'epitaka.sync',
        );
        return false;
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      developer.log(
        '[AUTH] Native Google sign-in succeeded',
        name: 'epitaka.sync',
      );
      return true;
    } on GoogleSignInException catch (e) {
      developer.log(
        '[AUTH] Native Google sign-in failed: ${e.code} ${e.description}',
        name: 'epitaka.sync',
      );
      return false;
    } catch (e) {
      developer.log(
        '[AUTH] Native Google sign-in failed: $e',
        name: 'epitaka.sync',
      );
      return false;
    }
  }

  /// Web / desktop / iOS: open the browser-based OAuth PKCE flow.
  Future<bool> _signInWithGoogleBrowser() async {
    try {
      final client = Supabase.instance.client.auth;
      await client.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? Uri.base.replace(query: null, fragment: null).toString()
            : SupabaseConfig.oauthRedirectUri,
      );
      return true;
    } catch (e) {
      developer.log('[AUTH] Google sign-in failed: $e', name: 'epitaka.sync');
      return false;
    }
  }

  /// Called when the app receives `epitaka://login-callback/…` — completes
  /// the PKCE exchange started by [signInWithGoogle] on native platforms.
  Future<bool> handleRedirectUri(Uri uri) async {
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
      developer.log(
        '[AUTH] Session exchange succeeded via deep link',
        name: 'epitaka.sync',
      );
      return true;
    } catch (e) {
      developer.log(
        '[AUTH] Redirect session exchange failed: $e',
        name: 'epitaka.sync',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    // Each step is wrapped separately so a failure in one can never block
    // the other: the Supabase session MUST be cleared even if the native
    // Google sign-out hiccups, or the UI would stay "signed in".
    try {
      if (_useNativeGoogleSignIn && _googleSignInInitialized) {
        // Native first so the next sign-in shows the account picker again
        // instead of silently reusing the session.
        await GoogleSignIn.instance.signOut();
      }
    } catch (e) {
      developer.log('[AUTH] Native Google sign-out failed: $e', name: 'epitaka.sync');
    }
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      developer.log('[AUTH] Supabase sign-out failed: $e', name: 'epitaka.sync');
    }
  }
}

/// Simplified auth status for the UI.
enum AuthStatus { signedOut, signedIn, unknown }

class AuthState {
  final AuthStatus status;
  final User? user;

  const AuthState({required this.status, this.user});

  bool get isSignedIn => status == AuthStatus.signedIn;

  String? get displayName {
    final u = user;
    if (u == null) return null;
    return u.userMetadata?['name'] as String? ??
        u.email ??
        u.userMetadata?['full_name'] as String?;
  }

  String? get email => user?.email;

  String? get avatarUrl => user?.userMetadata?['avatar_url'] as String?;
}
