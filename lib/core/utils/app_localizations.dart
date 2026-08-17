import 'package:flutter/material.dart';

import '../providers/settings_provider.dart';
import 'l10n/app_strings.dart';

/// Localized strings for the ePitaka app UI.
///
/// Strings live in per-language files under `core/utils/l10n/`:
///   - `en.dart` — English (source of truth)
///   - `vi.dart` — Vietnamese
///   - `app_strings.dart` — registry of supported languages
///
/// To add a new language, copy `en.dart` to `xx.dart`, translate the
/// values, and register it in `app_strings.dart`. That's the whole process.
class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  /// Resolve [key] (an English source string) in the current language,
  /// falling back to English when the translation is missing.
  String _t(String key) {
    return AppStrings.tableFor(locale.languageCode)[key] ?? key;
  }

  /// Resolve any key in the current language (used by data-driven content
  /// such as the Feature Guide, whose text keys are English source strings).
  String t(String key) => _t(key);

  // ═══════════════════════════════════════════════════════════════════════
  //  COMMON / SHARED
  // ═══════════════════════════════════════════════════════════════════════

  String get save => _t('Save');
  String get saving => _t('Saving…');
  String get cancel => _t('Cancel');
  String get delete => _t('Delete');
  String get download => _t('Download');
  String get retry => _t('Retry');
  String get ok => _t('OK');
  String get yes => _t('Yes');
  String get no => _t('No');
  String get error => _t('Error');
  String get confirm => _t('Confirm');
  String get open => _t('Open');
  String get close => _t('Close');
  String get done => _t('Done');
  String get add => _t('Add');
  String get update => _t('Update');
  String get search => _t('Search');
  String get clear => _t('Clear');
  String get remove => _t('Remove');
  String get none => _t('None');
  String get back => _t('Back');
  String get unknown => _t('Unknown');
  String get untitled => _t('Untitled');
  String get apply => _t('Apply');
  String get check => _t('Check');
  String get rebuild => _t('Rebuild');

  /// Title of the "What's New" dialog shown after an app update.
  String get whatsNew => _t("What's New");

  /// Error prefix for `Error: $message` lines.
  String errorMessage(String message) => '${_t('Error')}: $message';

  // ═══════════════════════════════════════════════════════════════════════
  //  SETTINGS SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get settings => _t('Settings');
  String get general => _t('General');
  String get language => _t('Language');
  String get appearance => _t('Appearance');
  String get appearanceSubtitle => _t('Theme & accent');
  String get dataAndContent => _t('Data & Content');
  String get translationsDownloads => _t('Translations & Downloads');
  String get readingPreferences => _t('Reading Preferences');
  String get readingOptions => _t('Reading Options');
  String get readingOptionsSubtitle => _t('Layout, numbering & scroll');
  String get dictionaryLookup => _t('Dictionary');
  String get wordLookupGesture => _t('Word lookup');
  String get wordLookupGestureSubtitle =>
      _t('How a tap on a word opens the dictionary');
  String get doubleTap => _t('Double tap');
  String get singleTap => _t('Single tap');
  String get textToSpeech => _t('Text-to-Speech');
  String get ttsSubtitle => _t('Voice & speed');
  String get ttsReplacements => _t('TTS Replacements');
  String get ttsReplacementsSubtitle => _t('Regex text replacements');
  String get script => _t('Script');
  String get stripVariantAnnotations => _t('Show variant readings');
  String get stripVariantAnnotationsSubtitle =>
      _t('Show variant readings from other textual versions');
  String get showBookLinks => _t('Show Inline Commentaries');
  String get showBookLinksSubtitle =>
      _t('Show links to inlined commentaries & connected books');
  String get libraryBrowser => _t('Library Browser');
  String get defaultExpandLevel => _t('Default expand level');
  String get collapsed => _t('Collapsed');
  String get category => _t('Category');
  String get expand => _t('Expand');
  String get theme => _t('Theme');
  String get systemTheme => _t('Dhammatā');
  String get lightTheme => _t('Tālapatta');
  String get sepiaTheme => _t('Paññā-āloka');
  String get oceanTheme => _t('Vimutti-rasa');
  String get darkTheme => _t('Samādhi');
  String get midnightTheme => _t('Passaddhi');
  String get forestTheme => _t('Arañña');

  /// Display name for a theme preference (Pāli name).
  String themeName(ThemePreference pref) {
    switch (pref) {
      case ThemePreference.system:
        return systemTheme;
      case ThemePreference.light:
        return lightTheme;
      case ThemePreference.sepia:
        return sepiaTheme;
      case ThemePreference.ocean:
        return oceanTheme;
      case ThemePreference.dark:
        return darkTheme;
      case ThemePreference.midnight:
        return midnightTheme;
      case ThemePreference.forest:
        return forestTheme;
    }
  }

  /// Short gloss explaining the meaning behind each theme's Pāli name.
  String themeGloss(ThemePreference pref) {
    switch (pref) {
      case ThemePreference.system:
        return _t('Natural Law / Adaptability');
      case ThemePreference.light:
        return _t('Preserved Sacred Texts');
      case ThemePreference.sepia:
        return _t('Illuminating Wisdom');
      case ThemePreference.ocean:
        return _t('Oceanic Taste of Freedom');
      case ThemePreference.dark:
        return _t('Meditative Stillness');
      case ThemePreference.midnight:
        return _t('Profound Tranquility');
      case ThemePreference.forest:
        return _t('Forest Seclusion');
    }
  }

  String get expandResultsDefault => _t('Expand results by default');
  String get rebuildSearchIndex => _t('Rebuild search index');
  String get rebuildSearchIndexSubtitle =>
      _t('Re-indexes Pāli texts & translations');
  String get dictionaries => _t('Dictionaries');
  String get dictionarySettings => _t('Dictionary Settings');
  String get dictionarySettingsSubtitle => _t('Enable, disable & reorder');
  String get account => _t('Account');
  String get profile => _t('Profile');
  String get system => _t('System');
  String get about => _t('About ePitaka');
  String get help => _t('Help');
  String get keyboardShortcuts => _t('Keyboard Shortcuts');
  String get searchInBook => _t('Search within the book');
  String get searchBooks => _t('Search books…');
  String get globalSearch => _t('Open global search');
  String get closeFocusTab => _t('Close the focus tab');
  String get closeAllTabs => _t('Close all tabs');
  String get openDictionary => _t('Open dictionary');
  String get openLibrary => _t('Open library');
  String get openSettings => _t('Open settings');
  String get increaseFontSize => _t('Increase font size');
  String get decreaseFontSize => _t('Decrease font size');
  String get languageEnglish => _t('English');
  String get languageVietnamese => _t('Vietnamese');

  String appLanguageName(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.english:
        return languageEnglish;
      case AppLanguage.vietnamese:
        return languageVietnamese;
      default:
        return lang.nativeName;
    }
  }

  String get aiQa => _t('AI Q&A');
  String get aiQaSettings => _t('AI Q&A Settings');
  String get aiQaSettingsSubtitle => _t('API key, models, etc.');

  // ═══════════════════════════════════════════════════════════════════════
  //  APPEARANCE SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get accentColor => _t('Accent Color');
  String get accentPairPreview => _t('Accent Pair Preview');
  String get lightMode => _t('Light mode');
  String get darkMode => _t('Dark mode');
  String get buttonLabel => _t('Button');

  // ═══════════════════════════════════════════════════════════════════════
  //  READING OPTIONS SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get pageNumbering => _t('Page Numbering');
  String get layout => _t('Layout');
  String get sideBySideView => _t('Side-by-Side View');
  String get sideBySideSubtitle => _t('Show Pāli and translation side by side');
  String get copyClipboard => _t('Copy / Clipboard');
  String get quoteFormat => _t('Quote Format');
  String get defaultCopyScope => _t('Default Copy Scope');
  String get autoScrollSpeed => _t('Auto-Scroll Speed');
  String get display => _t('Display');
  String get keepScreenOn => _t('Keep Screen On');
  String get keepScreenOnSubtitle =>
      _t('Prevent screen from dimming while reading');
  String get bookIdLabel => _t('Book ID');
  String get bookNameLabel => _t('Book Name');
  String get fullCitation => _t('Full Citation');
  String get paliOnly => _t('Pāli Only');
  String get translationOnly => _t('Translation Only');
  String get both => _t('Both');
  String get slow => _t('Slow');
  String get fast => _t('Fast');
  String get systemLabel => _t('System');
  String get template => _t('Template');
  String get pageSystem => _t('Page System');

  // ── Display layout popup ──────────────────────────────────────────────
  String get displayNoTranslation => _t('No translation');
  String get displayNoTranslationSubtitle => _t('Hide all translations');
  String get displayLineByLine => _t('Line by line');
  String get displayLineByLineSubtitle => _t('Pāli above translation');
  String get displaySideBySide => _t('Side by side');
  String get displaySideBySideSubtitle => _t('Pāli beside translation');
  String get anyShort => _t('Any');

  // ═══════════════════════════════════════════════════════════════════════
  //  GAVESANA (AI SEARCH)
  // ═══════════════════════════════════════════════════════════════════════

  String get aiSearch => _t('Gavesana (AI Search)');
  String get readyLabel => _t('Ready');

  // ═══════════════════════════════════════════════════════════════════════
  //  TRANSLATION SETTINGS SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get displayMode => _t('Display Mode');
  String get paliTextLabel => _t('Pāli Text');
  String get translationDatabases => _t('Translation Databases');
  String get checkForUpdates => _t('Check for Updates');
  String get noUpdates => _t('All translations are up to date.');
  String get activeVersion => _t('Active Version');
  String get selectThisVersion => _t('Select this version');
  String get nissayaDesc => _t('Nissaya (word-by-word)');
  String get standardTranslation => _t('Standard translation');
  String get installFirst => _t('Install first');
  String get fontFamily => _t('Font Family');
  String get fontSize => _t('Font Size');
  String get style => _t('Style');
  String get colorLabel => _t('Color');
  String get useForReading => _t('Use for Reading');
  String get active => _t('Active');
  String get nissaya => _t('Nissaya');
  String get enabled => _t('Enabled');
  String get disabled => _t('Disabled');
  String get deleteTranslationTitle => _t('Delete Translation?');
  String get deleteTranslationShort => _t('Delete Translation');
  String get deleteTranslationConfirm => _t('Delete translation');
  String get translationOrder => _t('Translation Order');
  String get pickColor => _t('Pick Color');
  String get updateCheckComplete => _t('Update check complete.');

  // ── Annotations (highlights, notes, bookmarks, sync) ──────────────────
  String get annotations => _t('Annotations');
  String get noAnnotations => _t(
    'No annotations yet.\nSelect text and tap Highlight or Note in the toolbar.',
  );
  String get noBookOpenForAnnotations =>
      _t('Open a book to see your annotations.');
  String get errorLoadingAnnotations => _t('Error loading annotations:');
  String get highlight => _t('Highlight');
  String get highlightDesc => _t('Highlight the selected text');
  String get note => _t('Note');
  String get noteDesc => _t('Attach a markdown note to the selection');
  String get highlightAdded => _t('Highlight added');
  String get annotationNoAnchor =>
      _t('Could not anchor the selection — try again.');
  String get addNote => _t('Add Note');
  String get editNote => _t('Edit');
  String get previewNote => _t('Preview');
  String get noteHint => _t('Write a note… supports **markdown**');
  String get highlightColor => _t('Color');
  String get changeColor => _t('Change color');
  String get editNoteLabel => _t('Edit note');
  String get colorUpdated => _t('Color updated');
  String get moreActions => _t('More actions');
  String get markdownSupported => _t('Markdown supported');
  String get deleteAnnotation => _t('Delete annotation?');
  String get deleteAnnotationMsg => _t('This removes the highlight or note.');
  String get deleteAnnotationBookmarkMsg => _t('This removes the bookmark.');

  // ── Annotations screen (all books) ──────────────────────────────────
  String get allLabel => _t('All');
  String get highlights => _t('Highlights');
  String get notesLabel => _t('Notes');
  String get highlightsNotesBookmarks => _t('Highlights, notes & bookmarks');
  String get noHighlightsYet => _t('No highlights yet.');
  String get noNotesYet => _t('No notes yet.');
  String get searchAnnotations => _t('Search annotations…');
  String get tryDifferentSearchTerm => _t('Try a different search term.');
  String get clearSearch => _t('Clear search');
  String get filterByBook => _t('Filter by book');
  String get allBooks => _t('All books');
  String get noAnnotationsInBooks =>
      _t('No annotations in the selected books.');
  String get moreColors => _t('More colors');
  String get collapseLabel => _t('Collapse');

  // ── Script Converter screen ──────────────────────────────────────────
  String get scriptConverter => _t('Script Converter');
  String get scriptConverterTitle => _t('Pāli Script Converter');
  String get scriptConverterSubtitle => _t(
    'Convert Pāli text between any scripts — the same converter the reader uses.',
  );
  String get from => _t('From');
  String get to => _t('To');
  String get useResultAsInput => _t('Use result as input');
  String get typePaliText => _t('Type or paste Pāli text…');
  String get characters => _t('characters');
  String get converterOutputHint => _t('Your converted text will appear here.');

  // ── Account / Cloud Sync ──────────────────────────────────────────────
  String get signIn => _t('Sign in');
  String get signOut => _t('Sign out');
  String get signInTitle => _t('Sign in to sync');
  String get signInFailed => _t('Sign in failed. Please try again.');
  String get syncActive =>
      _t('Sync active — highlights, notes & bookmarks are backed up');
  String get syncDisabled =>
      _t('Sync off — annotations are stored on this device only');

  // ── Context Menu (reader selection toolbar) ───────────────────────────
  String get contextMenu => _t('Context Menu');
  String get contextMenuSubtitle => _t('Customize the selection toolbar');
  String get contextMenuDesc => _t(
    'Customize the actions shown when you select text in the reader. '
    'Drag to reorder, toggle to hide, and add apps or AI prompts.',
  );
  String get addPrompt => _t('Add Prompt');
  String get addApp => _t('Add App');
  String get promptName => _t('Prompt Name');
  String get prompt => _t('Prompt');
  String get promptPlaceholderHint =>
      _t('Use {selectedText} as a placeholder for the selected text.');
  String get editPrompt => _t('Edit Prompt');
  String get installedApps => _t('Installed Apps');
  String get noContextMenuActions =>
      _t('No context menu actions yet. Add apps or prompts below.');
  String get externalApp => _t('External app');
  String get copy => _t('Copy');
  String get copyDesc => _t('Copy the selected text');
  String get excerpt => _t('Excerpt');
  String get excerptDesc => _t('Copy with citation');
  String get copyLink => _t('Copy Link');
  String get copyLinkDesc => _t('Copy a link to this passage');
  String get dictionaryDesc => _t('Look up the selected word');
  String get lookUp => _t('Look Up');
  String get lookUpDesc => _t('Look up in device dictionary (iOS/macOS)');
  String get resetToDefault => _t('Reset to default');
  String get resetToDefaultConfirm =>
      _t('Reset context menu actions and order to default?');

  // ── Toolbar (reader bottom toolbar) ──────────────────────────────────
  String get toolbar => _t('Toolbar');
  String get toolbarSubtitle => _t('Customize the reader toolbar');
  String get toolbarDesc => _t(
    'Choose which actions appear in the reader toolbar and their order. '
    'Drag to reorder, toggle to hide.',
  );
  String get toolbarHint => _t(
    'Contents, Outline, Search, Dictionary and Annotations appear on the '
    'mobile toolbar only.',
  );
  String get displayLayout => _t('Display layout');
  String get bookmark => _t('Bookmark');
  String get resetToolbarConfirm => _t('Reset toolbar items and order to default?');
  String get explain => _t('Explain');
  String get explainDesc => _t('Explain the selected text with AI');
  String get summarizeChapter => _t('Summarize Ch.');
  String get summarizeChapterDesc =>
      _t('Summarize the current chapter with AI');
  String get share => _t('Share');
  String get shareDesc => _t('Share the selected text');

  // ── Feature Guide (new-user instructions) ─────────────────────────────
  String get featureGuide => _t('Feature Guide');
  String get featureGuideSubtitle => _t('Learn what ePitaka can do');
  String get featureGuideIntro => _t(
    'Step-by-step instructions for the reader toolbar, text selection, '
    'settings and the AI assistant.',
  );
  String get featureGuideWelcomeDesc => _t(
    'Take a quick tour of the main features — you can reopen this guide '
    'anytime from the menu.',
  );
  String get exploreFeatures => _t('Explore features');
  String get gotIt => _t('Got it');
  String get exploreWhileWaiting => _t('While you wait…');
  String get exploreWhileWaitingDesc => _t(
    'While you wait, here is a quick tour of what you can do with ePitaka.',
  );

  // ── Display modes (Translation settings) ──────────────────────────────
  String get hideTranslationMode => _t('Hide Translation');
  String get hideTranslationModeSubtitle =>
      _t('Show only Pāli text, joined as paragraphs');
  String get lineByLineMode => _t('Line by Line');
  String get lineByLineModeSubtitle =>
      _t('Show Pāli followed by its translation');
  String get sideBySideMode => _t('Side by Side');
  String get sideBySideModeSubtitle =>
      _t('Show Pāli and translation in two columns');

  // ═══════════════════════════════════════════════════════════════════════
  //  TTS SETTINGS SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get ttsEngine => _t('TTS Engine');
  String get ttsVoiceLabel => _t('Voice');
  String get ttsSpeed => _t('Speed');

  /// Short label for the translation speed slider (full "Translation
  /// speed" doesn't fit next to the slider).
  String get ttsTranslationSpeed => _t('Trans. speed');
  String get ttsPaliSpeed => _t('Pāli speed');
  String get ttPitch => _t('Pitch');
  String get ttsLanguageLabel => _t('Language');
  String get engine => _t('Engine');
  String get systemTts => _t('System TTS');
  String get systemTtsDesc =>
      _t('Platform-native text-to-speech (fast, no download)');
  String get supertonic => _t('SuperTonic');
  String get supertonicDesc =>
      _t('Neural TTS with 31 languages (~400 MB model download)');
  String get modelDownload => _t('Model Download');
  String get modelsInstalled => _t('Models Installed');
  String get ttsModels => _t('TTS Models');
  String get allModelsReady => _t('All models are ready for use');
  String get requiresDownload => _t('Requires ~400 MB download for neural TTS');
  String get speakingRate => _t('Speaking Rate');
  String get low => _t('Low');
  String get high => _t('High');
  String get preview => _t('Preview');
  String get testSpeech => _t('Test Speech');
  String get testHearSample =>
      _t('Hear a sample of the current voice & settings');
  String get playing => _t('Playing…');
  String get tapPauseOrStop => _t('Tap pause or stop to control playback');
  String get paused => _t('Paused');
  String get tapResume => _t('Tap resume to continue');
  String get loadingAudio => _t('Preparing audio…');
  String get voiceStyle => _t('Voice Style');
  String get systemDefault => _t('System Default');
  String get config => _t('Config');
  String get ttsLanguageLabel2 => _t('TTS Language');
  String get quality => _t('Quality');
  String get qualitySubtitle =>
      _t('Synthesis quality — higher sounds better but is slower');
  String get medium => _t('Medium');
  String get ttsLanguageAutoNote =>
      _t('Follows the reading language (first enabled translation)');
  String get ttsSpeakMode => _t('Speak');
  String get ttsSpeakTranslation => _t('Translation');
  String get ttsSpeakTranslationDesc => _t('Reads the translation aloud');
  String get ttsSpeakPali => _t('Pāli');
  String get ttsSpeakPaliDesc => _t(
    'Reads the Pāli aloud, written in Devanagari (Hindi) for the best pronunciation',
  );
  String get ttsSpeakBoth => _t('Translation + Pāli');
  String get ttsSpeakBothShort => _t('Both');
  String get ttsSpeakBothDesc =>
      _t('Reads the Pāli first, then its translation');
  String get ttsInstallVoice => _t('Install voice');
  String get ttsInstallVoiceHint => _t(
    'Open your device Text-to-speech settings to install voices (Sinhala/Hindi for Pāli)',
  );
  String get ttsVoiceMissingHint => _t(
    'This voice is not installed on your device. Tap "Install voice" to add it.',
  );
  String get ttsPreview => _t('Preview');
  String get translationNote => _t('Translation note');
  String get translationRemark => _t('Translation remark');
  String get editLineInfo => _t('Edit translation info');
  String get paragraph => _t('Paragraph');
  String get line => _t('Line');
  String get conflict => _t('Conflict');
  String get addRemark => _t('Add remark');

  // ═══════════════════════════════════════════════════════════════════════
  //  TTS REPLACEMENTS SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get ttsReplacementsDesc =>
      _t('Replace text patterns before TTS reads them aloud.');
  String get addReplacement => _t('Add Replacement');
  String get noReplacementRules =>
      _t('No replacement rules yet.\nTap "Add Replacement" to create one.');
  String get deleteReplacementRule => _t('Delete Replacement Rule?');
  String get useRegex => _t('Use Regex');
  String get find => _t('Find:');
  String get replaceWith => _t('Replace with:');
  String get regexUsesDart => _t('Regex uses Dart RegExp syntax.');
  String get editReplacement => _t('Edit Replacement');
  String get addReplacementTitle => _t('Add Replacement');
  String get deleteReplacementConfirm =>
      _t('Are you sure you want to delete this rule?');

  // ═══════════════════════════════════════════════════════════════════════
  //  READING COLORS SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get readingColors => _t('Reading Colors');
  String get paliTextColor => _t('Pāli Text Color');
  String get translationTextColor => _t('Translation Text Color');
  String get lightModeLabel => _t('Light mode');
  String get darkModeAuto => _t('Dark mode (auto)');
  String get darkModePreview => _t('Dark Mode Preview');
  String get lightModePreview => _t('Light Mode Preview');
  String get pickAColor => _t('Pick a color');

  // ═══════════════════════════════════════════════════════════════════════
  //  TYPOGRAPHY SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get typographyFontSize => _t('Typography & Font Size');
  String get noTranslationDatabases => _t('No translation databases found.');
  String get downloadInSettings =>
      _t('Download translations in Settings → Translations & Downloads.');
  String get couldNotLoadTranslations => _t('Could not load translations:');

  // ═══════════════════════════════════════════════════════════════════════
  //  DICTIONARY SETTINGS SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get dictionarySettingDesc => _t(
    'Enable, disable, and reorder dictionaries.\nDictionaries appear in this order in the dictionary panel.',
  );
  String get enabledDictionaries => _t('Enabled Dictionaries');
  String get disabledDictionaries => _t('Disabled Dictionaries');
  String get noDictEnabled =>
      _t('No dictionaries enabled. Tap a dictionary below to enable it.');
  String get errorLoadingDict => _t('Error loading dictionaries:');

  // ═══════════════════════════════════════════════════════════════════════
  //  DICTIONARY SHEET
  // ═══════════════════════════════════════════════════════════════════════

  String get dictionary => _t('Dictionary');
  String get searchPali => _t('Search Pāḷi…');
  String get dictIdlePrompt => _t(
    'Search for a Pāḷi word to see\ndefinitions across multiple dictionaries',
  );
  String get showFullDetails => _t('Show full details');
  String get searchResultsFor => _t('Search results for');
  String get noDirectMatch => _t('No direct matches found for');

  // ═══════════════════════════════════════════════════════════════════════
  //  LIBRARY SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get browse => _t('Browse');
  String get reading => _t('Reading');
  String get bookmarks => _t('Bookmarks');
  String get openTabs => _t('Open Tabs');
  String get books => _t('books');
  String get noBooksOpen =>
      _t('No books open yet.\nBrowse and open a book to start reading.');
  String get noBooksOpenShort => _t('No books open yet.');
  String get history => _t('History');
  String get readingHistory => _t('Reading History');
  String get noBookmarks =>
      _t('No bookmarks yet.\nSave your reading position from the reader.');
  String get noBookmarksShort => _t('No bookmarks yet.');
  String get noHistory => _t('No reading history yet.');
  String get listening => _t('Listening');
  String get noListeningHistory => _t('No listening history yet.');
  String get removeBookmark => _t('Remove Bookmark?');
  String get removeHistoryEntry => _t('Remove History Entry?');
  String get justNow => _t('Just now');
  String get minutesAgo => _t('m ago');
  String get hoursAgo => _t('h ago');
  String get daysAgo => _t('d ago');
  String get errorLoadingBookmarks => _t('Error loading bookmarks:');
  String get errorLoadingHistory => _t('Error loading history:');
  String get noBooksInPitaka => _t('No books in this Piṭaka yet.');
  String get couldNotLoadLibrary => _t('Could not load the Tipitaka library.');
  String get removeBookmarkConfirm => _t('Delete bookmark');
  String get removeHistoryConfirm => _t('Delete history entry for');
  String get removedLabel => _t('Removed: ');
  String get searchIndexTitle => _t('Search Index');

  /// `Delete bookmark "NAME"?`
  String deleteBookmarkConfirm(String name) =>
      '${_t('Delete bookmark')} "$name"?';

  /// `Delete history entry for "LABEL"?`
  String deleteHistoryEntryConfirm(String label) =>
      '${_t('Delete history entry for')} "$label"?';

  /// `Removed: NAME`
  String removedItem(String name) => '${_t('Removed: ')}$name';

  // ═══════════════════════════════════════════════════════════════════════
  //  SEARCH SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get searchPaliTexts => _t('Search Pāli texts…');
  String get fuzzy => _t('Fuzzy');
  String get wordDistance => _t('Word distance');
  String get anyDistance => _t('Any distance');
  String get results => _t('results');
  String get dist => _t('Dist');
  String get searchTipitaka => _t('Search the Pāli Tipiṭaka');
  String get searchIdleHint => _t(
    'Search across both Pāli text and translations.\nEnable fuzzy mode to match diacritic variations (ā=a, ñ=n, ṭ=t …).',
  );
  String get buildingSearchIndex => _t('Building Search Index');
  String get percentComplete => _t('complete');
  String get starting => _t('Starting…');
  String get noResultsFor => _t('No results for');
  String get tryFuzzySearch =>
      _t('Try enabling fuzzy search or using different terms.');
  String get showMore => _t('Show more');
  String get remaining => _t('remaining');
  String get searchFailed => _t('Search failed:');
  String get searchPaliShort => _t('Search Pāli…');
  String get toggleFilters => _t('Toggle filters');
  String get layer => _t('Layer');
  String get nikaya => _t('Nikāya');
  String get noMatchesFor => _t('No matches for');
  String get noMatchesFoundFor => _t('No matches found for');
  String get didYouMean => _t('Did you mean…');
  String get noResults => _t('No results');
  String get fontSizeLabel => _t('Font size');
  String get wordsLabel => _t('words');
  String get showLabel => _t('Show');
  String get moreLabel => _t('more');
  String get resultSingular => _t('result');

  /// `Within N words`
  String withinNWords(int n) => '${_t('Within')} $n ${_t('words')}';

  /// `Within N` (short form)
  String withinNShort(int n) => '${_t('Within')} $n';

  /// `Show N more`
  String showNMore(int n) => '${_t('Show')} $n ${_t('more')}';

  /// `N results` (with singular/plural)
  String resultsCount(int n) =>
      n == 1 ? '1 ${_t('result')}' : '$n ${_t('results')}';

  /// `No matches for "QUERY"`
  String noMatchesForQuery(String query) => '${_t('No matches for')} "$query"';

  /// `No matches found for "QUERY"`
  String noMatchesFoundForQuery(String query) =>
      '${_t('No matches found for')} "$query"';
  String get typeToSearch =>
      _t('Type a word or phrase to search\nacross all Pāli texts');
  String get openInReader => _t('Open in Reader');
  String get noHeadingFound => _t('No heading found for this result');
  String get failedToLoadPreview => _t('Failed to load preview:');
  String get sectionHeadings => _t('Section headings');

  /// `N found` (heading results card badge)
  String headingsFound(int n) => '$n ${_t('found')}';

  // ═══════════════════════════════════════════════════════════════════════
  //  READER SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get findInBook => _t('Find in book…');
  String get closeSearch => _t('Close search');
  String get previousMatch => _t('Previous match');
  String get nextMatch => _t('Next match');
  String get searchTipitakaFull => _t('Search entire Tipiṭaka');
  String get noContentFound => _t('No content found.');
  String get errorLoadingText => _t('Error loading text:');
  String get copyWithStyle => _t('Copy with Style');
  String get selectAll => _t('Select All');
  String get copyWithQuote => _t('Copy with Quote');

  // ── TTS Reader widgets ───────────────────────────────────────────────
  String get follow => _t('Follow');
  String get ttsControls => _t('TTS Controls');
  String get followTtsPosition => _t('Follow TTS Position');

  // ── Bookmark Dialog ──────────────────────────────────────────────────
  String get addBookmark => _t('Add Bookmark');
  String get bookmarkName => _t('Bookmark name');
  String get bookmarkSaved => _t('Bookmark saved:');
  String get failedToSaveBookmark => _t('Failed to save bookmark:');

  // ── Jump Sheet ───────────────────────────────────────────────────────
  String get connectedBooks => _t('Connected Books');
  String get jumpToPage => _t('Jump to Page');
  String get pageNumberingSystem => _t('Page Numbering System');
  String get pageNumberInput => _t('Page Number');
  String get pageInputHint => _t('e.g. 10 or 1.10');
  String get jumpTip => _t(
    'Tip: If pages are numbered like "1.3", you can type just "3" to jump to page 1.3.',
  );
  String get pageNotFound => _t('not found in this book.');
  String get noConnectedBooks =>
      _t('No connected books found for this section.');
  String get errorLoadingConnections => _t('Error loading connected books.');
  String get section => _t('Section');

  // ── Book Link Section Sheet ─────────────────────────────────────────
  String get linkedFrom => _t('Linked from');
  String get noContentAvailable => _t('No content available.');
  String get couldNotLoadLinked => _t('Could not load linked content.');
  String get linkedParaNotFound => _t('Linked paragraph not found.');
  String get openLibraryShort => _t('Open Library');
  String get closePanel => _t('Close panel');

  // ═══════════════════════════════════════════════════════════════════════
  //  CONTENTS SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get contents => _t('Contents');
  String get searchContents => _t('Search contents…');
  String get searchContentsHint => _t('Search contents…');
  String get noMatchingSections => _t('No matching sections');
  String get noContentsAvailable => _t('No contents available');

  // ═══════════════════════════════════════════════════════════════════════
  //  OUTLINE
  // ═══════════════════════════════════════════════════════════════════════

  String get outline => _t('Outline');
  String get outlineSubtitle => _t('Every section with its study guide');
  String get openBookFirst => _t('Open a book to see its outline');
  String get noSectionsFound => _t('No sections found for this book');
  String get outlineHint =>
      _t('Tap a section to preview it, or read its study guide');

  /// `N sections` (with singular/plural)
  String sectionsCount(int n) =>
      n == 1 ? '1 ${_t('section')}' : '$n ${_t('sections')}';

  String get textTab => _t('Text');
  String get studyGuide => _t('Study guide');
  String get loadingStudyGuide => _t('Loading study guide…');
  String get studyGuideUnavailable =>
      _t('No study guide available for this section');

  // ═══════════════════════════════════════════════════════════════════════
  //  AI ASSISTANT (Paññā)
  // ═══════════════════════════════════════════════════════════════════════

  String get aiName => _t('Paññā');
  String get aiSubtitle => _t('AI Research Assistant');
  String get answerMode => _t('💬 Answer');
  String get answerModeSub => _t('Q&A');
  String get literalReviewMode => _t('📖 Literal Review');
  String get literalReviewModeSub => _t('Deep research');
  String get askQuestion => _t('Ask a Question');
  String get literalReviewTitle => _t('Literal Review');
  String get askQuestionDesc => _t(
    'Ask any question about the Tipitaka. The Assistant will search the Pāli Canon and provide a grounded answer with sources.',
  );
  String get literalReviewDesc => _t(
    'Enter a research topic to search the Tipitaka and receive a structured literal review with Pāli quotes and citations.',
  );
  String get apiKeyRequired => _t('API key required');
  String get configureApiKey => _t('Configure API Key');
  String get startConversation => _t('Start a conversation');
  String get enterTopic => _t('Enter a research topic…');
  String get askTipitaka => _t('Ask a question about the Tipitaka…');
  String get aiSettings => _t('AI Settings');
  String get sources => _t('Sources');
  String get cited => _t('cited');
  String get failedToLoadSource => _t('Failed to load text');
  String get lineByLine => _t('Line-by-line');
  String get startAsking => _t('Start asking');
  String get buildShort => _t('Build');
  String get deleteConversation => _t('Delete conversation?');
  String get copied => _t('Copied!');
  String get copyMessage => _t('Copy message');
  String get thinkingLabel => _t('Thinking...');
  String get researchingLabel => _t('Researching...');
  String get generatingAnswer => _t('Generating answer...');
  String get passageNotFound => _t('Passage not found in the database');

  /// `Citations (N)`
  String citationsCount(int count) => 'Citations ($count)';

  // ═══════════════════════════════════════════════════════════════════════
  //  AI SETTINGS SHEET
  // ═══════════════════════════════════════════════════════════════════════

  String get aiSettingsTitle => _t('AI Assistant Settings');
  String get apiKeyConfigured => _t('API key is configured');
  String get apiKeyRequiredMsg =>
      _t('API key required — enter your Gemini key below');
  String get geminiApiKey => _t('Gemini API Key');
  String get apiKeyHint => _t('AIza...');
  String get getApiKeyHint =>
      _t('Get your free Gemini API key at makersuite.google.com');
  String get renderModel => _t('Render Model (for generating answers)');
  String get renderModelDesc =>
      _t('Used for the main answer generation. Needs strong reasoning.');
  String get liteModel => _t('Lite Model (for filtering & search)');
  String get liteModelDesc =>
      _t('Fast model for re-ranking results and query expansion.');
  String get saveSettings => _t('Save Settings');
  String get aiSettingsSaved => _t('AI settings saved');
  String get aiQaSettingsSaved => _t('AI Q&A settings saved');
  String get couldNotOpenLink => _t('Could not open the link');
  String get aiProvider => _t('AI Provider');
  String get apiKey => _t('API Key');
  String get baseUrl => _t('Base URL');
  String get checkKeyLoadModels => _t('Check key & load models');
  String get checkingKeyLoadingModels => _t('Checking key & loading models...');
  String get toolModelLabel => _t('Tool Model (for search & function calling)');
  String get answerModelLabel =>
      _t('Answer Model (for final answer generation)');
  String get maxCharsPerToolResult => _t('Max chars per tool result');
  String get zeroNoTruncation => _t('0 = no truncation');
  String get answerMaxOutputTokens => _t('Answer max output tokens');
  String get maxQueriesPerChat => _t('Max queries per chat');
  String get customSystemPrompt => _t('Custom System Prompt (optional)');
  String get suggestionIndex => _t('Suggestion Index');
  String get rebuildSuggestionIndex => _t('Rebuild Suggestion Index');
  String get getFreeGeminiKey => _t('Get a free Gemini API key');
  String get geminiFree4Steps =>
      _t('Gemini is free for everyone — just 4 easy steps:');
  String get guideStep1 => _t('Tap "Get free Gemini API key" below.');
  String get guideStep2 =>
      _t('Sign in with your Google account (free, no credit card).');
  String get guideStep3 =>
      _t('Tap "Create API key" and copy it (it starts with AIza).');
  String get guideStep4 =>
      _t('Paste it in the API Key field above — it is checked automatically.');
  String get noCreditCard => _t(
    'No credit card needed. The free tier includes generous daily limits for Gemini Flash models.',
  );
  String get getFreeOpenRouterKey => _t('Get a free OpenRouter API key');
  String get openRouterFree4Steps =>
      _t('OpenRouter is free to join — just 4 easy steps:');
  String get openRouterStep1 => _t('Tap "Get free OpenRouter API key" below.');
  String get openRouterStep2 =>
      _t('Sign in with Google or GitHub (free, no credit card).');
  String get openRouterStep3 =>
      _t('Tap "Create API key" and copy it (it starts with sk-or-).');
  String get openRouterStep4 =>
      _t('Paste it in the API Key field above — it is checked automatically.');
  String get openRouterFreeNote => _t(
    'No credit card needed. Free models (marked :free) are selected automatically.',
  );
  String get apiKeyRequiredOpenRouter =>
      _t('API key required — get your free OpenRouter key below');
  String get apiKeyRejected => _t('API key rejected — see the error below');
  String get keyEnteredVerify =>
      _t('Key entered — press Enter or "Check key" to verify');
  String get checkingApiKey => _t('Checking API key...');
  String get apiKeyValid => _t('API key valid');
  String get apiKeyRequiredGemini =>
      _t('API key required — get your free Gemini key below');

  /// `API key valid — $count models available`
  String apiKeyValidModels(int count) =>
      '${_t('API key valid')} — $count ${_t('models available')}';

  String get baseUrlExamples =>
      _t('Examples: https://openrouter.ai/api/v1, https://api.deepseek.com/v1');
  String get toolModelHint => _t(
    'Fast/cheap model for tool orchestration (e.g. gemini-flash-lite-latest)',
  );
  String get answerModelHint => _t(
    'Capable model for final answers (e.g. gemini-2.0-flash, '
    'gemini-2.5-flash)',
  );
  String get maxCharsPerToolResultDesc => _t(
    'Max characters per tool result sent to the model. Set to 0 for no '
    'truncation (full content). Large values may increase API usage.',
  );
  String get answerMaxOutputTokensDesc => _t(
    'Max output tokens for the answer model. Higher values allow longer '
    'answers. (Default: 64000)',
  );
  String get maxQueriesPerChatDesc => _t(
    'Max user queries (messages) allowed per chat thread before starting a '
    'new one. (Default: 8, min: 1)',
  );
  String get customSystemPromptHint => _t(
    'Leave empty to use the default system prompt.\n\n'
    'Customize how the AI behaves, what tools to use,\n'
    'and how to format answers.',
  );
  String get suggestionIndexDesc => _t(
    'Reset the @ mention suggestion index to pick up any new or updated '
    'books/headings.',
  );
  String get attachedHeadings => _t('Attached headings');
  String get clearAll => _t('Clear all');

  /// `${count} models found`
  String modelsFound(int count) => '$count models found';

  /// `Failed to save: $error`
  String failedToSave(String error) => '${_t('Failed to save: ')}$error';

  /// `Could not open: $url`
  String couldNotOpen(String url) => '${_t('Could not open: ')}$url';

  // ═══════════════════════════════════════════════════════════════════════
  //  GAVESANA SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get askAboutTipitaka => _t('Ask about the Tipitaka…');
  String get searchSemantically =>
      _t('Search semantically across the Tipitaka');

  /// `N results`
  String nResults(int n) => '$n results';

  String get semanticSearch => _t('Semantic search');
  String get investigationExploration => _t('Investigation & exploration');
  String get tipitaka => _t('Tipitaka');
  String get feedback => _t('Feedback');
  String get navigationMenu => _t('Navigation menu');
  String get chatHistory => _t('Chat history');
  String get newChat => _t('New chat');
  String get clearChat => _t('Clear chat');
  String get vimamsaSettings => _t('Vimaṃsa Settings');
  String get buildingHeadingIndex => _t('Building heading index…');
  String get headingIndexNeeded =>
      _t('Heading index needed for @ — build now?');
  String get askAboutTipitakaShort => _t('Ask about the Tipitaka');
  String get vimamsaIntro => _t(
    'Vimaṃsa — investigation through questioning.\n'
    'The AI searches the Tipitaka using tools, gathers relevant passages,\n'
    'and provides detailed answers with clickable citations.\n'
    'Each chat thread is saved — you can continue later.',
  );
  String get viewPastConversations => _t('View past conversations');
  String get orthodox => _t('Orthodox');
  String get orthodoxDesc =>
      _t('Answers use only the passages found in the Tipitaka.');
  String get unorthodoxDesc =>
      _t('The AI may also use its own knowledge alongside the found passages.');
  String get typeAtToAttach => _t('Type @ to attach a heading');
  String get threadIsFull => _t('Thread is full — start a new chat');
  String get askTipitakaOrAttach =>
      _t('Ask about the Tipitaka, or type @ to attach a heading…');
  String get chatHistoryTitle => _t('Chat History');
  String get newChatTitle => _t('New Chat');
  String get noConversationsYet => _t('No conversations yet');
  String get startNewChatToBegin => _t('Start a new chat to begin');
  String get activeLabel => _t('Active');
  String get andAllItsMessages => _t('and all its messages?');
  String get queryWord => _t('query');
  String get queriesWord => _t('queries');
  String get remainingInThread => _t('remaining in this thread');
  String get translationWord => _t('Translation');

  /// `$n query/queries remaining in this thread`
  String queriesRemainingInThread(int n) =>
      '$n ${n == 1 ? _t('query') : _t('queries')} ${_t('remaining in this thread')}';

  /// `Delete "TITLE" and all its messages?`
  String deleteThreadConfirm(String title) =>
      '${_t('Delete')} "$title" ${_t('and all its messages?')}';

  /// `$langName Translation` (typography section title)
  String translationTitle(String langName) => '$langName ${_t('Translation')}';

  String get dpdDictionary => _t('DPD Dictionary');
  String get compoundBreakdown => _t('Compound breakdown');
  String get pinToSidePanel => _t('Pin to side panel');
  String get unpinFromSidePanel => _t('Unpin from side panel');
  String get jumpLabel => _t('Jump');
  String get hideLabel => _t('Hide');
  String get lineByLineShort => _t('Line/L');
  String get sideBySideShort => _t('Side/S');
  String get stopLabel => _t('Stop');
  String get lessLabel => _t('Less');
  String get libraryLabel => _t('Library');
  String get resetLayout => _t('Reset layout');
  String get paliTipitakaReader => _t('Pāli Tipiṭaka Reader');
  String get vimamsa => _t('Vimaṃsa');
  String get openGavesana => _t('Open Gavesana');
  String get gavesana => _t('Gavesana');
  String get gavesanaAiSearch => _t('Gavesana AI Search');
  String get gavesanaPanelDesc => _t(
    'AI-powered search across the Tipiṭaka.\n\n'
    'Open the full Gavesana panel for detailed results.',
  );

  // ── Gavesana AI search (LLM-based, replaces on-device embeddings) ────
  String get gavesanaAiSearchHint => _t(
    'Describe what you\u2019re looking for — the AI will search the Tipitaka '
    'for relevant passages.',
  );
  String get gavesanaSearchButton => _t('Search with AI');
  String get gavesanaSearching => _t('AI is searching the Tipitaka…');
  String get gavesanaAiTools => _t('AI search steps');
  String get gavesanaAiTerms => _t('AI searched for');
  String get gavesanaAiResults => _t('AI-found passages');
  String get gavesanaNoResults => _t(
    'The AI could not find any relevant passages. Try a different description.',
  );
  String get gavesanaConfigureSettings => _t('Configure AI in Settings');
  String get gavesanaNeedsApiKey => _t(
    'Gavesana AI search needs an API key. Configure it in Settings → AI Q&A.',
  );

  // ═══════════════════════════════════════════════════════════════════════
  //  APP SHELL (Toolbar)
  // ═══════════════════════════════════════════════════════════════════════

  String get toolbarContents => _t('Contents');
  String get toolbarSearch => _t('Search');
  String get toolbarDictionary => _t('Dictionary');
  String get toolbarListen => _t('Listen');
  String get toolbarSave => _t('Save');

  // ═══════════════════════════════════════════════════════════════════════
  //  INDEXING
  // ═══════════════════════════════════════════════════════════════════════

  String get availableTranslations => _t('Available Translations');
  String get noTranslationsAvailable =>
      _t('No translations available.\nPlease download a translation first.');
  String get noTranslationsAvailableShort => _t('No translations available.');
  String get buildIndex => _t('Build Index');
  String get selectATranslation => _t('Select a Translation');
  String get buildFailed => _t('Build Failed');
  String get indexBuilt => _t('Index Built!');
  String get indexBuiltShort => _t('Index Built');
  String get preparing => _t('Preparing…');
  String get installing => _t('Installing…');
  String get readyToIndex => _t('Ready to index');
  String get downloadCancelled => _t('Download cancelled');
  String get downloadFailed => _t('Download failed');
  String get checkingIndex => _t('Checking search index…');
  String get welcomeToEpitaka => _t('Welcome to ePitaka');
  String get indexingRequired => _t(
    'To enable full-text search, we need to build a search index for the Pāli texts and translations.',
  );
  String get indexingOnce => _t(
    'The indexing only needs to happen once.\nYou can rebuild later from Settings.',
  );
  String get noTranslationsForDownload =>
      _t('No translations available for download.');
  String get downloadTranslationToStart =>
      _t('Download a translation to get started:');
  String get chooseTranslationToIndex => _t('Choose a translation to index:');
  String get buildIndexPali => _t('Build Index (Pāli)');
  String get somethingWentWrong => _t('Something went wrong');
  String get unknownError => _t('Unknown error');
  String get downloadRequiredDatabases =>
      _t('Download the required databases to get started.');
  String get addMoreTranslationsLater =>
      _t('You can add more translations later.');
  String get requiredDatabases => _t('Required Databases');
  String get requiredDatabasesDesc =>
      _t('These are needed for the app to function.');
  String get requiredTranslations => _t('Required Translations');
  String get requiredTranslationsDesc =>
      _t('An English translation is needed for AI search features.');
  String get optionalTranslations => _t('Optional Translations');
  String get textColors => _t('Text Colors');
  String get pickPaliTextColor => _t('Pick Pāli Text Color');
  String get pickTranslationTextColor => _t('Pick Translation Text Color');
  String get downloadRequiredItemsFirst => _t('Download required items first');
  String get loadingAvailableTranslations =>
      _t('Loading available translations…');
  String get required => _t('Required');
  String get installed => _t('Installed');
  String get notInstalled => _t('Not installed');
  String get comingSoon => _t('Coming soon');
  String get buildingDots => _t('Building…');
  String get notBuilt => _t('Not built');

  /// `Pāli + XX translation indexed\nNN sentences`
  String indexedSentenceSummary(String lang, int count) =>
      'Pāli + ${lang.toUpperCase()} translation indexed\n$count ${_t('sentences')}';

  /// `X / Y sentences`
  String sentenceProgress(int current, int total) =>
      '${_fmt(current)} / ${_fmt(total)} ${_t('sentences')}';

  /// `Batch X / Y`
  String batchProgress(int current, int total) => 'Batch $current / $total';

  String get resettingAndRebuilding => _t('Resetting & Rebuilding');
  String get loadingDots => _t('Loading…');
  String get sentences => _t('sentences');
  String get filesLabel => _t('files');
  String get manageTranslationsSubtitle =>
      _t('Manage translation databases: download, update, and delete.');
  String get pali => _t('Pāli');
  String get paliRomanScript => _t('Pali (Roman script)');
  String get reorderTranslationsHint => _t(
    'Drag to reorder enabled translations. The first one is shown when multiple are enabled.',
  );
  String get noTranslationsDownloadedYet => _t(
    'No translations downloaded yet. Download a translation above to reorder it.',
  );
  String get noTranslationsFound =>
      _t('No translations found or available for download.');
  String get checkingForUpdates => _t('Checking for updates…');
  String get checkForTranslationUpdates =>
      _t('Check for translation updates from GitHub.');
  String get deleteTranslationRemoveDb =>
      _t('This will remove the database file from your device.');
  String get deletedLabel => _t('Deleted ');
  String get versionInfo => _t('Version Info');
  String get filename => _t('Filename');
  String get type => _t('Type');
  String get suffix => _t('Suffix');
  String get defaultLabel => _t('Default');
  String get size => _t('Size');
  String get updated => _t('Updated');
  String get installedOn => _t('Installed on');
  String get status => _t('Status');
  String get nissayaInfo => _t(
    'Nissaya translations show word-by-word Pāli breakdown with meanings, displayed as pali: meaning | pali: meaning.',
  );
  String get quoteFormatHelper =>
      _t('Customize the citation format. Use the variables shown below.');
  String get availableVariables => _t(
    'Available variables: {book_id}, {book_name}, {heading}, {para_id}, {vri_page}, {pts_page}, {thai_page}, {myanmar_page}',
  );
  String get errorPrefix => _t('Error: ');
  String get couldNotLoadPreviewMsg => _t('Could not load preview: ');
  String get bookmarkSavedMsg => _t('Bookmark saved: ');
  String get failedToSaveBookmarkMsg => _t('Failed to save bookmark: ');

  String get rebuildingIndex => _t('Rebuilding Index');
  String get resetAndRebuild => _t('Reset & Rebuild');
  String get resetAndRebuildTitle => _t('Reset & Rebuild?');
  String get resetAndRebuildSubtitle =>
      _t('Clear bookmarks, history & rebuild search index');
  String get resetConfirmDesc => _t(
    'This will permanently delete all bookmarks and reading history, then rebuild the search index from scratch.',
  );
  String get databaseLocation => _t('Database location:');
  String get resetBackupTip => _t(
    'Tip: Export your bookmarks and reading history as a JSON file before resetting. Online backup will be supported in a future update.',
  );
  String get exportBackups => _t('Export Backups');
  String get resetNow => _t('Reset Now');
  String get backupSavedTo => _t('Backup saved to: ');
  String get failedToExportData => _t('Failed to export data: ');

  String get rebuildSearchIndexTitle => _t('Rebuild Search Index?');
  String get rebuildIndexConfirmDesc => _t(
    'This will delete and rebuild the full-text search index from scratch. It may take a few seconds on slower devices. You can continue using the app while indexing runs in the background.',
  );
  String get clearIndexConfirmDesc => _t(
    'This will clear the current search index and rebuild it from scratch. Previously indexed data will be lost until the rebuild completes.',
  );

  // ═══════════════════════════════════════════════════════════════════════
  //  INDEX BUILD DIALOG
  // ═══════════════════════════════════════════════════════════════════════

  String get buildSearchIndex => _t('Build Search Index');
  String get chooseTranslation =>
      _t('Choose a translation to include in the search index.');

  // ═══════════════════════════════════════════════════════════════════════
  //  FEEDBACK
  // ═══════════════════════════════════════════════════════════════════════

  String get sendFeedback => _t('Send Feedback');

  // ═══════════════════════════════════════════════════════════════════════
  //  PAGE NUMBER HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  String pageSystemLabel(String code) {
    switch (code) {
      case 'vri':
        return 'VRI';
      case 'pts':
        return 'PTS';
      case 'thai':
        return _t('Thai');
      case 'my':
        return _t('Myanmar');
      default:
        return 'VRI';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  MENTION OVERLAY
  // ═══════════════════════════════════════════════════════════════════════

  String get mentionAttachPrefix => _t('Attach: ');
  String get typeSuttaOrHeading => _t('Type a sutta or heading name');
  String get startTypingSutta => _t('Start typing a sutta or heading name');
  String get mentionTip => _t('Tip: Try @cankisutta, @dn1, or a heading title');
  String get selectShort => _t('Select');
  String get navigateShort => _t('Navigate');
  String get escShort => _t('Esc');

  /// `Attach: "QUERY"`
  String attachQuery(String query) => '${_t('Attach: ')}"$query"';

  /// `No results for "QUERY"`
  String noResultsForQuery(String query) => '${_t('No results for')} "$query"';

  String _fmt(int n) {
    if (n < 1000) return n.toString();
    final s = n.toString();
    final b = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) b.write(',');
      b.write(s[i]);
      count++;
    }
    return b.toString().split('').reversed.join();
  }
}

/// Delegate that creates [AppLocalizations] for supported locales.
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppStrings.supportedCodes.contains(locale.languageCode);

  static List<Locale> get supportedLocales =>
      AppStrings.supportedCodes.map((c) => Locale(c)).toList();

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
