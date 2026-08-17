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

  /// Google Sign-In registration (README for anyone debugging "works in
  /// debug, fails on Google Play"):
  ///
  /// Native Android sign-in ([google_sign_in] with [googleWebClientId] as
  /// `serverClientId`) validates the calling app by **package name + SHA-1
  /// signing-certificate fingerprint** against the Google Cloud project that
  /// owns [googleWebClientId]. There is no Firebase / google-services.json
  /// in this app, so every package+SHA-1 combo must be registered manually
  /// in Google Cloud Console (APIs & Services → Credentials → OAuth client
  /// → Android type).
  ///
  /// Known combos:
  ///   * dev flavor (`com.dn.epitaka.dev`) + debug keystore
  ///     SHA-1 `93:CB:80:04:75:5D:67:7B:49:E2:6F:27:2A:E3:8C:0B:52:5F:8B:1F`
  ///   * prod flavor (`com.dn.epitaka`) + **Google Play App Signing** keys.
  ///     Since quantum-ready hybrid signing was enabled, the app has three
  ///     Play signing keys. The one that signs the APK delivered to
  ///     Android ≤16 devices is the **previous app signing key** (Play
  ///     Console → App signing → "Previous app signing keys"):
  ///       - previous classical key (what Android ≤16 validates):
  ///         SHA-1 `5F:D8:12:FD:7E:13:CC:B1:DC:D5:DD:89:65:4F:8C:E7:53:D7:CA:B3`,
  ///         SHA-256 `52:E7:51:2D:48:54:90:4A:23:3A:89:6F:3D:F7:EF:10:C7:7B:3C:
  ///         D4:F0:19:E8:83:8F:ED:13:77:BF:33:C1:C1` — verified by pulling
  ///         the installed APK from a device (apksigner verify --print-certs).
  ///       - current "Classic" key (Android 17+ hybrid, APK Signature
  ///         Scheme v3.2): SHA-1 `4A:D1:16:D1:F9:8B:CC:57:EA:98:E9:ED:5F:6E:
  ///         F0:87:D7:05:94:49`
  ///       - current "Post quantum" PQC key (Android 17+ hybrid, v3.2):
  ///         SHA-1 `D1:EF:C3:2B:E7:93:D3:B8:6E:05:04:1C:5C:DB:76:33:04:1A:12:E4`
  ///     Register ALL THREE (SHA-1, and SHA-256 too for the backend's
  ///     signature check) on the same Android OAuth client for
  ///     `com.dn.epitaka` so sign-in works on every Android version and
  ///     survives the next key rotation. The upload key
  ///     (`75:2E:B8:1C:97:34:44:BD:E2:72:A4:0F:28:0F:72:87:39:4B:97:A6`)
  ///     is only what sideloaded APKs show — NOT needed for Play.
  ///
  /// If a build combination isn't registered, Google rejects the request
  /// and sign-in fails (often surfaced as a canceled picker).

  /// Name of the remote `annotations` table.
  static const String annotationsTable = 'annotations';
}
