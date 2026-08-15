import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/navigator.dart';
import 'package:go_router/go_router.dart';

import '../features/ai_qa/screens/ai_qa_screen.dart';
import '../features/annotations/screens/annotations_screen.dart';
import '../features/dictionary/screens/dictionary_screen.dart';
import '../features/gavesana/screens/gavesana_screen.dart';
import '../features/script_converter/screens/script_converter_screen.dart';
import '../features/guide/screens/feature_guide_screen.dart';
import '../features/library/screens/library_screen.dart';
import '../features/reader/screens/reader_screen.dart';
import '../features/search/widgets/search_screen.dart';
import '../features/settings/screens/appearance_settings_screen.dart';
import '../features/settings/screens/context_menu_settings_screen.dart';
import '../features/settings/screens/dictionary_settings_screen.dart';
import '../features/settings/screens/help_screen.dart';
import '../features/settings/screens/reading_options_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/translation_settings_screen.dart';
import '../features/settings/screens/tts_settings_screen.dart';
import '../features/translator/screens/translator_run_screen.dart';
import '../features/translator/screens/translator_settings_screen.dart';
import '../features/settings/screens/tts_replacements_screen.dart';
import '../features/contents/screens/contents_screen.dart';
import '../core/utils/platform_info.dart';
import '../shared/widgets/responsive_scaffold.dart';

/// The route paths for the app.
class AppRoutes {
  AppRoutes._();

  static const library = '/';
  static const reader = '/reader';
  static const search = '/search';
  static const annotations = '/annotations';
  static const scriptConverter = '/script-converter';
  static const dictionary = '/dictionary';
  static const settings = '/settings';
  static const appearanceSettings = '/settings/appearance';
  static const readingOptions = '/settings/reading';
  static const translationSettings = '/settings/translation';
  static const ttsSettings = '/settings/tts';
  static const ttsReplacements = '/settings/tts/replacements';
  static const contextMenuSettings = '/settings/context-menu';
  static const dictionarySettings = '/settings/dictionary';
  static const help = '/settings/help';
  static const translatorSettings = '/translator';
  static const translatorRun = '/translator/run';
  static const contents = '/contents/:bookId';
  static const gavesana = '/gavesana';
  static const aiQa = '/ai-qa';
  static const featureGuide = '/guide';
}

/// The `_buildRouter()` function is called from `app.dart`.
/// The FTS index gate is applied via the top-level `builder` parameter,
/// so every route is gated without redundant re-mounts.
GoRouter buildRouter({GlobalKey<NavigatorState>? navigatorKey}) {
  return GoRouter(
    // Desktop is reader-focused: launch straight into the IDE-style shell
    // (the library lives docked on its left). Mobile keeps the library home.
    initialLocation: PlatformInfo.isDesktop
        ? AppRoutes.reader
        : AppRoutes.library,
    navigatorKey: navigatorKey,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      // Desktop: any navigation to the library root lands on the reader
      // shell instead (the library stays reachable via its docked panel
      // and the app-bar library button).
      if (PlatformInfo.isDesktop &&
          state.matchedLocation == AppRoutes.library) {
        return AppRoutes.reader;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.library,
        name: 'library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/reader',
        name: 'reader',
        builder: (context, state) =>
            const ResponsiveScaffold(child: ReaderScreen()),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.annotations,
        name: 'annotations',
        builder: (context, state) => const AnnotationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.scriptConverter,
        name: 'scriptConverter',
        builder: (context, state) => const ScriptConverterScreen(),
      ),
      GoRoute(
        path: AppRoutes.dictionary,
        name: 'dictionary',
        builder: (context, state) => const DictionaryScreen(),
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
            path: 'context-menu',
            name: 'contextMenuSettings',
            builder: (context, state) => const ContextMenuSettingsScreen(),
          ),
          GoRoute(
            path: 'dictionary',
            name: 'dictionarySettings',
            builder: (context, state) => const DictionarySettingsScreen(),
          ),
          GoRoute(
            path: 'help',
            name: 'help',
            builder: (context, state) => const HelpScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.translatorSettings,
        name: 'translatorSettings',
        builder: (context, state) => const TranslatorSettingsScreen(),
        routes: [
          GoRoute(
            path: 'run',
            name: 'translatorRun',
            builder: (context, state) => const TranslatorRunScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.gavesana,
        name: 'gavesana',
        builder: (context, state) => const GavesanaScreen(),
      ),
      GoRoute(
        path: AppRoutes.aiQa,
        name: 'aiQa',
        builder: (context, state) {
          final threadId = state.uri.queryParameters['thread'];
          return VimamsaScreen(initialThreadId: threadId);
        },
      ),
      GoRoute(
        path: AppRoutes.featureGuide,
        name: 'featureGuide',
        builder: (context, state) {
          final showIntro =
              state.uri.queryParameters['intro'] == 'true';
          return FeatureGuideScreen(showIntro: showIntro);
        },
      ),
      GoRoute(
        path: '/contents/:bookId',
        name: 'contents',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          final bookName = state.uri.queryParameters['bookName'] ?? bookId;
          final currentParaId = int.tryParse(
            state.uri.queryParameters['currentParaId'] ?? '',
          );
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
