import 'package:go_router/go_router.dart';

import '../features/library/screens/library_screen.dart';
import '../features/reader/screens/reader_screen.dart';
import '../features/search/widgets/search_screen.dart';
import '../features/settings/screens/appearance_settings_screen.dart';
import '../features/settings/screens/dictionary_settings_screen.dart';
import '../features/settings/screens/reading_options_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/translation_settings_screen.dart';
import '../features/settings/screens/tts_settings_screen.dart';
import '../features/settings/screens/tts_replacements_screen.dart';
import '../features/contents/screens/contents_screen.dart';

/// The route paths for the app.
class AppRoutes {
  AppRoutes._();

  static const library = '/';
  static const reader = '/reader';
  static const search = '/search';
  static const settings = '/settings';
  static const appearanceSettings = '/settings/appearance';
  static const readingOptions = '/settings/reading';
  static const translationSettings = '/settings/translation';
  static const ttsSettings = '/settings/tts';
  static const ttsReplacements = '/settings/tts/replacements';
  static const dictionarySettings = '/settings/dictionary';
  static const contents = '/contents/:bookId';
}

/// The `_buildRouter()` function is called from `app.dart`.
/// The FTS index gate is applied via the top-level `builder` parameter,
/// so every route is gated without redundant re-mounts.
GoRouter buildRouter() {
  return GoRouter(
    initialLocation: AppRoutes.library,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: AppRoutes.library,
        name: 'library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/reader',
        name: 'reader',
        builder: (context, state) => const ReaderScreen(),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'appearance',
            name: 'appearanceSettings',
            builder: (context, state) => const AppearanceSettingsScreen(),
          ),
          GoRoute(
            path: 'reading',
            name: 'readingOptions',
            builder: (context, state) => const ReadingOptionsScreen(),
          ),
          GoRoute(
            path: 'translation',
            name: 'translationSettings',
            builder: (context, state) => const TranslationSettingsScreen(),
          ),
          GoRoute(
            path: 'tts',
            name: 'ttsSettings',
            builder: (context, state) => const TtsSettingsScreen(),
            routes: [
              GoRoute(
                path: 'replacements',
                name: 'ttsReplacements',
                builder: (context, state) => const TtsReplacementsScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'dictionary',
            name: 'dictionarySettings',
            builder: (context, state) => const DictionarySettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/contents/:bookId',
        name: 'contents',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          final bookName = state.uri.queryParameters['bookName'] ?? bookId;
          final currentParaId = int.tryParse(
              state.uri.queryParameters['currentParaId'] ?? '');
          return ContentsScreen(
            bookId: bookId,
            bookName: bookName,
            currentParaId: currentParaId,
          );
        },
      ),
    ],
  );
}
