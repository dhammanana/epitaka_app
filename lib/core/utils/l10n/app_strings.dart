import 'en.dart';
import 'vi.dart';
import 'my.dart';
import 'si.dart';
import 'lo.dart';
import 'th.dart';
import 'zh.dart';
import 'hi.dart';

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
    'my': my,
    'si': si,
    'lo': lo,
    'th': th,
    'zh': zh,
    'hi': zh,
  };

  /// Locale codes shown in the language picker, in display order.
  static const List<String> supportedCodes = ['en', 'vi', 'my', 'si', 'lo', 'th', 'zh', 'hi'];

  /// Resolve the string table for a locale code, falling back to English
  /// when the code is unknown.
  static Map<String, String> tableFor(String code) => all[code] ?? en;
}