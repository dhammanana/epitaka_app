import 'en.dart';
import 'vi.dart';

/// Registry of all supported UI languages.
///
/// To add a new language:
///   1. Copy `en.dart` → `xx.dart` and translate every value (keys stay
///      identical — they are the English source strings).
///   2. Add the map to [all] and the code to [supportedCodes] below.
/// That's it — the app automatically picks up the new language in the
/// language picker and `AppLocalizationsDelegate.supportedLocales`.
abstract final class AppStrings {
  /// All supported UI languages, keyed by locale code.
  static const Map<String, Map<String, String>> all = {
    'en': en,
    'vi': vi,
  };

  /// Locale codes shown in the language picker, in display order.
  static const List<String> supportedCodes = ['en', 'vi'];

  /// Resolve the string table for a locale code, falling back to English
  /// when the code is unknown.
  static Map<String, String> tableFor(String code) =>
      all[code] ?? en;
}
