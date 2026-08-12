/// Central place for Supabase connection settings.
///
/// The values below are the *publishable* (anon) credentials — safe to ship
/// in the app; row-level security on the server enforces per-user access.
///
/// To point the app at a different Supabase project, change [url] and
/// [anonKey]. The SQL schema for the `annotations` table lives in
/// `supabase/migrations/0001_annotations.sql`.
abstract final class SupabaseConfig {
  /// Project URL from the Supabase dashboard → Project Settings → API.
  static const String url = 'https://rqqcaxcjlyfsbkdiudpw.supabase.co';

  /// Anon / publishable key from the same dashboard page.
  static const String anonKey =
      'sb_publishable_K_isIlTFfme9lPWa-J3eyA_NsLL8D9H';

  /// Custom URL scheme used by native (mobile/desktop) Google OAuth
  /// redirects. Must match the `epitaka` scheme already registered for deep
  /// links (AndroidManifest / Info.plist), and be whitelisted in the
  /// Supabase dashboard under Auth → URL Configuration → Redirect URLs as
  /// `epitaka://login-callback/`.
  static const String oauthScheme = 'epitaka';
  static const String oauthRedirectPath = 'login-callback';

  /// Full native redirect URI handed to Supabase during OAuth.
  static String get oauthRedirectUri => '$oauthScheme://$oauthRedirectPath/';

  /// Google OAuth client ID ("Web application" type) from Google Cloud
  /// Console — the SAME client ID configured as the Google provider's
  /// "Client ID" in the Supabase dashboard (Auth → Providers → Google).
  ///
  /// Used as the ID-token audience for native Google sign-in on Android:
  /// `google_sign_in` returns an ID token whose `aud` claim equals this
  /// client ID, and Supabase accepts it because it matches its configured
  /// Google provider client ID.
  ///
  /// If you ever change the Google client in the Supabase dashboard,
  /// update this value to match.
  static const String googleWebClientId =
      '1054969882-ohg6akokja7i47n89btp7v154757thd9.apps.googleusercontent.com';

  /// Name of the remote `annotations` table.
  static const String annotationsTable = 'annotations';
}
