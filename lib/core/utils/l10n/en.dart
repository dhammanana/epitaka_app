/// English UI strings — the **source of truth** for the app's language keys.
///
/// Every key is the English text itself. To add a new language:
///   1. Copy this file to `xx.dart` (e.g. `fr.dart`).
///   2. Translate every *value* (keep the keys identical).
///   3. Register it in `app_strings.dart` (`all` + `supportedCodes`).
/// Done — the new language automatically appears in Settings.
const Map<String, String> en = {
  // ── Common ──────────────────────────────────────────────────────────
  'Save': 'Save',
  'Saving…': 'Saving…',
  'Cancel': 'Cancel',
  'Delete': 'Delete',
  'Download': 'Download',
  'Retry': 'Retry',
  'OK': 'OK',
  'Yes': 'Yes',
  'No': 'No',
  'Error': 'Error',
  'Confirm': 'Confirm',
  'Open': 'Open',
  'Close': 'Close',
  'Done': 'Done',
  'Add': 'Add',
  'Update': 'Update',
  'Search': 'Search',
  'Clear': 'Clear',
  'Remove': 'Remove',
  'None': 'None',
  'Back': 'Back',
  'Unknown': 'Unknown',
  'Untitled': 'Untitled',
  'Apply': 'Apply',
  'Check': 'Check',
  'Rebuild': 'Rebuild',
  'Required': 'Required',
  'Installed': 'Installed',
  'Not installed': 'Not installed',
  'Coming soon': 'Coming soon',
  'Building…': 'Building…',
  'Not built': 'Not built',
  'Ready': 'Ready',
  'sentences': 'sentences',
  'results': 'results',
  'Loading…': 'Loading…',
  'files': 'files',
  'Manage translation databases: download, update, and delete.':
      'Manage translation databases: download, update, and delete.',
  'Pāli': 'Pāli',
  'Pali (Roman script)': 'Pali (Roman script)',
  'Drag to reorder enabled translations. The first one is shown when multiple are enabled.':
      'Drag to reorder enabled translations. The first one is shown when multiple are enabled.',
  'No translations downloaded yet. Download a translation above to reorder it.':
      'No translations downloaded yet. Download a translation above to reorder it.',
  'No translations found or available for download.':
      'No translations found or available for download.',
  'Checking for updates…': 'Checking for updates…',
  'Check for translation updates from GitHub.':
      'Check for translation updates from GitHub.',
  'This will remove the database file from your device.':
      'This will remove the database file from your device.',
  'Deleted ': 'Deleted ',
  'Version Info': 'Version Info',
  'Filename': 'Filename',
  'Type': 'Type',
  'Suffix': 'Suffix',
  'Default': 'Default',
  'Size': 'Size',
  'Updated': 'Updated',
  'Status': 'Status',
  'Nissaya translations show word-by-word Pāli breakdown with meanings, displayed as pali: meaning | pali: meaning.':
      'Nissaya translations show word-by-word Pāli breakdown with meanings, displayed as pali: meaning | pali: meaning.',
  'Customize the citation format. Use the variables shown below.':
      'Customize the citation format. Use the variables shown below.',
  'Available variables: {book_id}, {book_name}, {heading}, {para_id}, {vri_page}, {pts_page}, {thai_page}, {myanmar_page}':
      'Available variables: {book_id}, {book_name}, {heading}, {para_id}, {vri_page}, {pts_page}, {thai_page}, {myanmar_page}',
  'Error: ': 'Error: ',
  'Could not load preview: ': 'Could not load preview: ',
  'Bookmark saved: ': 'Bookmark saved: ',
  'Failed to save bookmark: ': 'Failed to save bookmark: ',

  // ── Settings ────────────────────────────────────────────────────────
  'Settings': 'Settings',
  'General': 'General',
  'Language': 'Language',
  'Appearance': 'Appearance',
  'Theme & accent': 'Theme & accent',
  'Data & Content': 'Data & Content',
  'Translations & Downloads': 'Translations & Downloads',
  'Reading Preferences': 'Reading Preferences',
  'Reading Options': 'Reading Options',
  'Layout, numbering & scroll': 'Layout, numbering & scroll',
  'Text-to-Speech': 'Text-to-Speech',
  'Voice & speed': 'Voice & speed',
  'TTS Replacements': 'TTS Replacements',
  'Regex text replacements': 'Regex text replacements',
  'Script': 'Script',
  'Show variant readings': 'Show variant readings',
  'Show variant readings from other textual versions':
      'Show variant readings from other textual versions',
  'Library Browser': 'Library Browser',
  'Default expand level': 'Default expand level',
  'Collapsed': 'Collapsed',
  'Category': 'Category',
  'Expand': 'Expand',
  'Theme': 'Theme',
  'Dhammatā': 'Dhammatā',
  'Tālapatta': 'Tālapatta',
  'Paññā-āloka': 'Paññā-āloka',
  'Vimutti-rasa': 'Vimutti-rasa',
  'Samādhi': 'Samādhi',
  'Passaddhi': 'Passaddhi',
  'Arañña': 'Arañña',
  'Natural Law / Adaptability': 'Natural Law / Adaptability',
  'Preserved Sacred Texts': 'Preserved Sacred Texts',
  'Illuminating Wisdom': 'Illuminating Wisdom',
  'Oceanic Taste of Freedom': 'Oceanic Taste of Freedom',
  'Meditative Stillness': 'Meditative Stillness',
  'Profound Tranquility': 'Profound Tranquility',
  'Forest Seclusion': 'Forest Seclusion',
  'Expand results by default': 'Expand results by default',
  'Rebuild search index': 'Rebuild search index',
  'Re-indexes Pāli texts & translations':
      'Re-indexes Pāli texts & translations',
  'Dictionaries': 'Dictionaries',
  'Dictionary Settings': 'Dictionary Settings',
  'Enable, disable & reorder': 'Enable, disable & reorder',
  'Account': 'Account',
  'Profile': 'Profile',
  'System': 'System',
  'About ePitaka': 'About ePitaka',
  'Help': 'Help',
  'Keyboard Shortcuts': 'Keyboard Shortcuts',
  'Search within the book': 'Search within the book',
  'Open global search': 'Open global search',
  'Close the focus tab': 'Close the focus tab',
  'Close all tabs': 'Close all tabs',
  'Open dictionary': 'Open dictionary',
  'Open library': 'Open library',
  'Open settings': 'Open settings',
  'Increase font size': 'Increase font size',
  'Decrease font size': 'Decrease font size',
  'English': 'English',
  'Vietnamese': 'Vietnamese',
  'AI Q&A': 'AI Q&A',
  'AI Q&A Settings': 'AI Q&A Settings',
  'API key, models, etc.': 'API key, models, etc.',
  'No download URL available for AI search assets':
      'No download URL available for AI search assets',

  // ── Appearance ──────────────────────────────────────────────────────
  'Accent Color': 'Accent Color',
  'Accent Pair Preview': 'Accent Pair Preview',
  'Light mode': 'Light mode',
  'Dark mode': 'Dark mode',
  'Button': 'Button',

  // ── Reading Options ─────────────────────────────────────────────────
  'Page Numbering': 'Page Numbering',
  'Layout': 'Layout',
  'Side-by-Side View': 'Side-by-Side View',
  'Show Pāli and translation side by side':
      'Show Pāli and translation side by side',
  'Copy / Clipboard': 'Copy / Clipboard',
  'Quote Format': 'Quote Format',
  'Default Copy Scope': 'Default Copy Scope',
  'Auto-Scroll Speed': 'Auto-Scroll Speed',
  'Display': 'Display',
  'Keep Screen On': 'Keep Screen On',
  'Prevent screen from dimming while reading':
      'Prevent screen from dimming while reading',
  'Show Inline Commentaries': 'Show Inline Commentaries',
  'Show links to inlined commentaries & connected books':
      'Show links to inlined commentaries & connected books',
  'Book ID': 'Book ID',
  'Book Name': 'Book Name',
  'Full Citation': 'Full Citation',
  'Pāli Only': 'Pāli Only',
  'Translation Only': 'Translation Only',
  'Both': 'Both',
  'Slow': 'Slow',
  'Fast': 'Fast',
  'Template': 'Template',
  'Page System': 'Page System',
  'No translation': 'No translation',
  'Hide all translations': 'Hide all translations',
  'Line by line': 'Line by line',
  'Pāli above translation': 'Pāli above translation',
  'Side by side': 'Side by side',
  'Pāli beside translation': 'Pāli beside translation',
  'Any': 'Any',

  // ── Gavesana (AI search) ────────────────────────────────────────────
  'Gavesana (AI Search)': 'Gavesana (AI Search)',

  'Open Gavesana': 'Open Gavesana',
  'found': 'found',
  'Section headings': 'Section headings',
  'Describe what you\u2019re looking for — the AI will search the Tipitaka for relevant passages.':
      'Describe what you\u2019re looking for — the AI will search the Tipitaka for relevant passages.',
  'Search with AI': 'Search with AI',
  'AI is searching the Tipitaka…': 'AI is searching the Tipitaka…',
  'AI search steps': 'AI search steps',
  'AI-found passages': 'AI-found passages',
  'The AI could not find any relevant passages. Try a different description.':
      'The AI could not find any relevant passages. Try a different description.',
  'Configure AI in Settings': 'Configure AI in Settings',
  'Gavesana AI search needs an API key. Configure it in Settings → AI Q&A.':
      'Gavesana AI search needs an API key. Configure it in Settings → AI Q&A.',

  // ── Translation Settings ────────────────────────────────────────────
  'Display Mode': 'Display Mode',
  'Pāli Text': 'Pāli Text',
  'Translation Databases': 'Translation Databases',
  'Check for Updates': 'Check for Updates',
  'All translations are up to date.': 'All translations are up to date.',
  'Active Version': 'Active Version',
  'Select this version': 'Select this version',
  'Nissaya (word-by-word)': 'Nissaya (word-by-word)',
  'Standard translation': 'Standard translation',
  'Install first': 'Install first',
  'Font Family': 'Font Family',
  'Font Size': 'Font Size',
  'Style': 'Style',
  'Color': 'Color',
  'Use for Reading': 'Use for Reading',
  'Active': 'Active',
  'Nissaya': 'Nissaya',
  'Enabled': 'Enabled',
  'Disabled': 'Disabled',
  'Delete Translation?': 'Delete Translation?',
  'Delete Translation': 'Delete Translation',
  'Delete translation': 'Delete translation',
  'Translation Order': 'Translation Order',
  'Pick Color': 'Pick Color',
  'Hide Translation': 'Hide Translation',
  'Show only Pāli text, joined as paragraphs':
      'Show only Pāli text, joined as paragraphs',
  'Line by Line': 'Line by Line',
  'Show Pāli followed by its translation':
      'Show Pāli followed by its translation',
  'Side by Side': 'Side by Side',
  'Show Pāli and translation in two columns':
      'Show Pāli and translation in two columns',
  'Update check complete.': 'Update check complete.',

  // ── TTS Settings ────────────────────────────────────────────────────
  'TTS Engine': 'TTS Engine',
  'Voice': 'Voice',
  'Speed': 'Speed',
  'Pitch': 'Pitch',
  'Engine': 'Engine',
  'System TTS': 'System TTS',
  'Platform-native text-to-speech (fast, no download)':
      'Platform-native text-to-speech (fast, no download)',
  'SuperTonic': 'SuperTonic',
  'Neural TTS with 31 languages (~400 MB model download)':
      'Neural TTS with 31 languages (~400 MB model download)',
  'Model Download': 'Model Download',
  'Models Installed': 'Models Installed',
  'TTS Models': 'TTS Models',
  'All models are ready for use': 'All models are ready for use',
  'Requires ~400 MB download for neural TTS':
      'Requires ~400 MB download for neural TTS',
  'Speaking Rate': 'Speaking Rate',
  'Low': 'Low',
  'High': 'High',
  'Preview': 'Preview',
  'Test Speech': 'Test Speech',
  'Hear a sample of the current voice & settings':
      'Hear a sample of the current voice & settings',
  'Playing…': 'Playing…',
  'Tap pause or stop to control playback':
      'Tap pause or stop to control playback',
  'Paused': 'Paused',
  'Tap resume to continue': 'Tap resume to continue',
  'Preparing audio…': 'Preparing audio…',
  'Voice Style': 'Voice Style',
  'System Default': 'System Default',
  'Config': 'Config',
  'TTS Language': 'TTS Language',
  'Quality': 'Quality',
  'Synthesis quality — higher sounds better but is slower':
      'Synthesis quality — higher sounds better but is slower',
  'Medium': 'Medium',
  'Follows the reading language (first enabled translation)':
      'Follows the reading language (first enabled translation)',

  // ── TTS Replacements ────────────────────────────────────────────────
  'Replace text patterns before TTS reads them aloud.':
      'Replace text patterns before TTS reads them aloud.',
  'Add Replacement': 'Add Replacement',
  'No replacement rules yet.\nTap "Add Replacement" to create one.':
      'No replacement rules yet.\nTap "Add Replacement" to create one.',
  'Delete Replacement Rule?': 'Delete Replacement Rule?',
  'Use Regex': 'Use Regex',
  'Find:': 'Find:',
  'Replace with:': 'Replace with:',
  'Regex uses Dart RegExp syntax.': 'Regex uses Dart RegExp syntax.',
  'Edit Replacement': 'Edit Replacement',
  'Are you sure you want to delete this rule?':
      'Are you sure you want to delete this rule?',

  // ── Reading Colors ──────────────────────────────────────────────────
  'Reading Colors': 'Reading Colors',
  'Pāli Text Color': 'Pāli Text Color',
  'Translation Text Color': 'Translation Text Color',
  'Dark mode (auto)': 'Dark mode (auto)',
  'Dark Mode Preview': 'Dark Mode Preview',
  'Light Mode Preview': 'Light Mode Preview',
  'Pick a color': 'Pick a color',

  // ── Typography ──────────────────────────────────────────────────────
  'Typography & Font Size': 'Typography & Font Size',
  'No translation databases found.': 'No translation databases found.',
  'Download translations in Settings → Translations & Downloads.':
      'Download translations in Settings → Translations & Downloads.',
  'Could not load translations:': 'Could not load translations:',

  // ── Dictionary Settings ─────────────────────────────────────────────
  'Enable, disable, and reorder dictionaries.\n'
          'Dictionaries appear in this order in the dictionary panel.':
      'Enable, disable, and reorder dictionaries.\n'
      'Dictionaries appear in this order in the dictionary panel.',
  'Enabled Dictionaries': 'Enabled Dictionaries',
  'Disabled Dictionaries': 'Disabled Dictionaries',
  'No dictionaries enabled. Tap a dictionary below to enable it.':
      'No dictionaries enabled. Tap a dictionary below to enable it.',
  'Error loading dictionaries:': 'Error loading dictionaries:',

  // ── Dictionary Sheet ────────────────────────────────────────────────
  'Dictionary': 'Dictionary',
  'Search Pāḷi…': 'Search Pāḷi…',
  'Search for a Pāḷi word to see\ndefinitions across multiple dictionaries':
      'Search for a Pāḷi word to see\ndefinitions across multiple dictionaries',
  'Show full details': 'Show full details',
  'Search results for': 'Search results for',
  'No direct matches found for': 'No direct matches found for',

  // ── Library ─────────────────────────────────────────────────────────
  'Browse': 'Browse',
  'Reading': 'Reading',
  'Bookmarks': 'Bookmarks',
  'Open Tabs': 'Open Tabs',
  'books': 'books',
  'No books open yet.\nBrowse and open a book to start reading.':
      'No books open yet.\nBrowse and open a book to start reading.',
  'No books open yet.': 'No books open yet.',
  'History': 'History',
  'Reading History': 'Reading History',
  'No bookmarks yet.\nSave your reading position from the reader.':
      'No bookmarks yet.\nSave your reading position from the reader.',
  'No bookmarks yet.': 'No bookmarks yet.',
  'No reading history yet.': 'No reading history yet.',
  'Listening': 'Listening',
  'No listening history yet.': 'No listening history yet.',
  'Remove Bookmark?': 'Remove Bookmark?',
  'Remove History Entry?': 'Remove History Entry?',
  'Just now': 'Just now',
  'm ago': 'm ago',
  'h ago': 'h ago',
  'd ago': 'd ago',
  'Error loading bookmarks:': 'Error loading bookmarks:',
  'Error loading history:': 'Error loading history:',
  'No books in this Piṭaka yet.': 'No books in this Piṭaka yet.',
  'Could not load the Tipitaka library.':
      'Could not load the Tipitaka library.',
  'Delete bookmark': 'Delete bookmark',
  'Delete history entry for': 'Delete history entry for',
  'Removed: ': 'Removed: ',
  'Search Index': 'Search Index',

  // ── Search ──────────────────────────────────────────────────────────
  'Search Pāli texts…': 'Search Pāli texts…',
  'Fuzzy': 'Fuzzy',
  'Word distance': 'Word distance',
  'Any distance': 'Any distance',
  'Within': 'Within',
  'Dist': 'Dist',
  'Search the Pāli Tipiṭaka': 'Search the Pāli Tipiṭaka',
  'Search across both Pāli text and translations.\n'
          'Diacritics are ignored (ā=a, ñ=n, ṭ=t …).':
      'Search across both Pāli text and translations.\n'
      'Diacritics are ignored (ā=a, ñ=n, ṭ=t …).',
  'Building Search Index': 'Building Search Index',
  'complete': 'complete',
  'Starting…': 'Starting…',
  'No results for': 'No results for',
  'Try enabling fuzzy search or using different terms.':
      'Try enabling fuzzy search or using different terms.',
  'Show more': 'Show more',
  'remaining': 'remaining',
  'Search failed:': 'Search failed:',
  'Type a word or phrase to search\nacross all Pāli texts':
      'Type a word or phrase to search\nacross all Pāli texts',
  'Open in Reader': 'Open in Reader',
  'No heading found for this result': 'No heading found for this result',
  'Failed to load preview:': 'Failed to load preview:',

  // ── Reader ──────────────────────────────────────────────────────────
  'Find in book…': 'Find in book…',
  'Close search': 'Close search',
  'Previous match': 'Previous match',
  'Next match': 'Next match',
  'Search entire Tipiṭaka': 'Search entire Tipiṭaka',
  'No content found.': 'No content found.',
  'Error loading text:': 'Error loading text:',
  'Copy with Style': 'Copy with Style',
  'Select All': 'Select All',
  'Copy with Quote': 'Copy with Quote',
  'Follow': 'Follow',
  'TTS Controls': 'TTS Controls',
  'Follow TTS Position': 'Follow TTS Position',
  'Add Bookmark': 'Add Bookmark',
  'Bookmark name': 'Bookmark name',
  'Bookmark saved:': 'Bookmark saved:',
  'Failed to save bookmark:': 'Failed to save bookmark:',
  'Connected Books': 'Connected Books',
  'Jump to Page': 'Jump to Page',
  'Page Numbering System': 'Page Numbering System',
  'Page Number': 'Page Number',
  'e.g. 10 or 1.10': 'e.g. 10 or 1.10',
  'Tip: If pages are numbered like "1.3", you can type just "3" to jump to page 1.3.':
      'Tip: If pages are numbered like "1.3", you can type just "3" to jump to page 1.3.',
  'not found in this book.': 'not found in this book.',
  'No connected books found for this section.':
      'No connected books found for this section.',
  'Error loading connected books.': 'Error loading connected books.',
  'Section': 'Section',
  'Linked from': 'Linked from',
  'No content available.': 'No content available.',
  'Could not load linked content.': 'Could not load linked content.',
  'Linked paragraph not found.': 'Linked paragraph not found.',
  'Open Library': 'Open Library',
  'Close panel': 'Close panel',

  // ── Contents ────────────────────────────────────────────────────────
  'Contents': 'Contents',
  'Search contents…': 'Search contents…',
  'No matching sections': 'No matching sections',
  'No contents available': 'No contents available',

  // ── AI Assistant ────────────────────────────────────────────────────
  'Paññā': 'Paññā',
  'AI Research Assistant': 'AI Research Assistant',
  '💬 Answer': '💬 Answer',
  'Q&A': 'Q&A',
  '📖 Literal Review': '📖 Literal Review',
  'Deep research': 'Deep research',
  'Ask a Question': 'Ask a Question',
  'Literal Review': 'Literal Review',
  'Ask any question about the Tipitaka. The Assistant will search the Pāli Canon and provide a grounded answer with sources.':
      'Ask any question about the Tipitaka. The Assistant will search the Pāli Canon and provide a grounded answer with sources.',
  'Enter a research topic to search the Tipitaka and receive a structured literal review with Pāli quotes and citations.':
      'Enter a research topic to search the Tipitaka and receive a structured literal review with Pāli quotes and citations.',
  'API key required': 'API key required',
  'Configure API Key': 'Configure API Key',
  'Start a conversation': 'Start a conversation',
  'Enter a research topic…': 'Enter a research topic…',
  'Ask a question about the Tipitaka…': 'Ask a question about the Tipitaka…',
  'AI Settings': 'AI Settings',
  'Sources': 'Sources',
  'cited': 'cited',
  'Failed to load text': 'Failed to load text',
  'Line-by-line': 'Line-by-line',
  'Start asking': 'Start asking',
  'Build': 'Build',
  'Delete conversation?': 'Delete conversation?',
  'Copied!': 'Copied!',
  'Copy message': 'Copy message',
  'Thinking...': 'Thinking...',
  'Researching...': 'Researching...',
  'Generating answer...': 'Generating answer...',
  'Passage not found in the database': 'Passage not found in the database',

  // ── AI Settings Sheet ───────────────────────────────────────────────
  'AI Assistant Settings': 'AI Assistant Settings',
  'API key is configured': 'API key is configured',
  'API key required — enter your Gemini key below':
      'API key required — enter your Gemini key below',
  'Gemini API Key': 'Gemini API Key',
  'AIza...': 'AIza...',
  'Get your free Gemini API key at makersuite.google.com':
      'Get your free Gemini API key at makersuite.google.com',
  'Render Model (for generating answers)':
      'Render Model (for generating answers)',
  'Used for the main answer generation. Needs strong reasoning.':
      'Used for the main answer generation. Needs strong reasoning.',
  'Lite Model (for filtering & search)': 'Lite Model (for filtering & search)',
  'Fast model for re-ranking results and query expansion.':
      'Fast model for re-ranking results and query expansion.',
  'Save Settings': 'Save Settings',
  'AI settings saved': 'AI settings saved',
  'AI Q&A settings saved': 'AI Q&A settings saved',
  'Failed to save: ': 'Failed to save: ',
  'Could not open the link': 'Could not open the link',
  'Could not open: ': 'Could not open: ',
  'AI Provider': 'AI Provider',
  'API Key': 'API Key',
  'Base URL': 'Base URL',
  'Check key & load models': 'Check key & load models',
  'Checking key & loading models...': 'Checking key & loading models...',
  'Tool Model (for search & function calling)':
      'Tool Model (for search & function calling)',
  'Answer Model (for final answer generation)':
      'Answer Model (for final answer generation)',
  'Max chars per tool result': 'Max chars per tool result',
  '0 = no truncation': '0 = no truncation',
  'Answer max output tokens': 'Answer max output tokens',
  'Max queries per chat': 'Max queries per chat',
  'Custom System Prompt (optional)': 'Custom System Prompt (optional)',
  'Suggestion Index': 'Suggestion Index',
  'Rebuild Suggestion Index': 'Rebuild Suggestion Index',
  'Get a free Gemini API key': 'Get a free Gemini API key',
  'Gemini is free for everyone — just 4 easy steps:':
      'Gemini is free for everyone — just 4 easy steps:',
  'Tap "Get free Gemini API key" below.':
      'Tap "Get free Gemini API key" below.',
  'Sign in with your Google account (free, no credit card).':
      'Sign in with your Google account (free, no credit card).',
  'Tap "Create API key" and copy it (it starts with AIza).':
      'Tap "Create API key" and copy it (it starts with AIza).',
  'Paste it in the API Key field above — it is checked automatically.':
      'Paste it in the API Key field above — it is checked automatically.',
  'No credit card needed. The free tier includes generous daily limits for Gemini Flash models.':
      'No credit card needed. The free tier includes generous daily limits for Gemini Flash models.',
  'API key rejected — see the error below':
      'API key rejected — see the error below',
  'Key entered — press Enter or "Check key" to verify':
      'Key entered — press Enter or "Check key" to verify',
  'Checking API key...': 'Checking API key...',
  'API key valid': 'API key valid',

  // ── Gavesana Screen ─────────────────────────────────────────────────
  'Ask about the Tipitaka…': 'Ask about the Tipitaka…',

  'Search semantically across the Tipitaka':
      'Search semantically across the Tipitaka',
  "Gavesana uses AI to find passages related to your\nquery, even if they don't share exact words.":
      "Gavesana uses AI to find passages related to your\nquery, even if they don't share exact words.",

  'Semantic search': 'Semantic search',
  'Investigation & exploration': 'Investigation & exploration',
  'Tipitaka': 'Tipitaka',
  'Feedback': 'Feedback',
  'Pāli Tipiṭaka Reader': 'Pāli Tipiṭaka Reader',
  'Vimaṃsa': 'Vimaṃsa',

  // ── Gavesana FTS Build Dialog ───────────────────────────────────────

  // ── Indexing ────────────────────────────────────────────────────────
  'Available Translations': 'Available Translations',
  'No translations available.\nPlease download a translation first.':
      'No translations available.\nPlease download a translation first.',
  'Build Index': 'Build Index',
  'Select a Translation': 'Select a Translation',
  'Build Failed': 'Build Failed',
  'Index Built!': 'Index Built!',
  'Index Built': 'Index Built',
  'Preparing…': 'Preparing…',
  'Installing…': 'Installing…',
  'Ready to index': 'Ready to index',
  'Download cancelled': 'Download cancelled',
  'Download failed': 'Download failed',
  'Checking search index…': 'Checking search index…',
  'Welcome to ePitaka': 'Welcome to ePitaka',
  'To enable full-text search, we need to build a search index for the Pāli texts and translations.':
      'To enable full-text search, we need to build a search index for the Pāli texts and translations.',
  'The indexing only needs to happen once.\nYou can rebuild later from Settings.':
      'The indexing only needs to happen once.\nYou can rebuild later from Settings.',
  'No translations available for download.':
      'No translations available for download.',
  'Download a translation to get started:':
      'Download a translation to get started:',
  'Choose a translation to index:': 'Choose a translation to index:',
  'Build Index (Pāli)': 'Build Index (Pāli)',
  'Something went wrong': 'Something went wrong',
  'Unknown error': 'Unknown error',
  'Download the required databases to get started.':
      'Download the required databases to get started.',
  'You can add more translations later.':
      'You can add more translations later.',
  'Required Databases': 'Required Databases',
  'These are needed for the app to function.':
      'These are needed for the app to function.',
  'Required Translations': 'Required Translations',
  'An English translation is needed for AI search features.':
      'An English translation is needed for AI search features.',
  'Optional Translations': 'Optional Translations',
  'Text Colors': 'Text Colors',
  'Pick Pāli Text Color': 'Pick Pāli Text Color',
  'Pick Translation Text Color': 'Pick Translation Text Color',
  'Download required items first': 'Download required items first',
  'Loading available translations…': 'Loading available translations…',
  'Building Heading Index…': 'Building Heading Index…',
  'This will delete and rebuild the full-text search index from scratch. '
          'It may take a few seconds on slower devices. '
          'You can continue using the app while indexing runs in the background.':
      'This will delete and rebuild the full-text search index from scratch. '
      'It may take a few seconds on slower devices. '
      'You can continue using the app while indexing runs in the background.',
  'This will clear the current search index and rebuild it from '
          'scratch. Previously indexed data will be lost until the rebuild '
          'completes.':
      'This will clear the current search index and rebuild it from '
      'scratch. Previously indexed data will be lost until the rebuild '
      'completes.',

  // ── Index Build Dialog ──────────────────────────────────────────────
  'Build Search Index': 'Build Search Index',
  'Choose a translation to include in the search index.':
      'Choose a translation to include in the search index.',
  'Rebuild Search Index?': 'Rebuild Search Index?',
  'Resetting & Rebuilding': 'Resetting & Rebuilding',
  'Rebuilding Index': 'Rebuilding Index',
  'Reset & Rebuild': 'Reset & Rebuild',
  'Reset & Rebuild?': 'Reset & Rebuild?',
  'Clear bookmarks, history & rebuild search index':
      'Clear bookmarks, history & rebuild search index',
  'This will permanently delete all bookmarks and reading history, then rebuild the search index from scratch.':
      'This will permanently delete all bookmarks and reading history, then rebuild the search index from scratch.',
  'Database location:': 'Database location:',
  'Tip: Export your bookmarks and reading history as a JSON file before resetting. Online backup will be supported in a future update.':
      'Tip: Export your bookmarks and reading history as a JSON file before resetting. Online backup will be supported in a future update.',
  'Export Backups': 'Export Backups',
  'Reset Now': 'Reset Now',
  'Backup saved to: ': 'Backup saved to: ',
  'Failed to export data: ': 'Failed to export data: ',

  // ── Feedback ────────────────────────────────────────────────────────
  'Send Feedback': 'Send Feedback',

  // ── Page systems ────────────────────────────────────────────────────
  'Thai': 'Thai',
  'Myanmar': 'Myanmar',

  // ── Mention overlay ─────────────────────────────────────────────────
  'Attach: ': 'Attach: ',
  'Type a sutta or heading name': 'Type a sutta or heading name',
  'Start typing a sutta or heading name':
      'Start typing a sutta or heading name',
  'Tip: Try @cankisutta, @dn1, or a heading title':
      'Tip: Try @cankisutta, @dn1, or a heading title',
  'Select': 'Select',
  'Navigate': 'Navigate',
  'Esc': 'Esc',
  'Rebuild suggestion index': 'Rebuild suggestion index',

  // ── Search panel / search screen ───────────────────────────────────
  'Search Pāli…': 'Search Pāli…',
  'Toggle filters': 'Toggle filters',
  'Layer': 'Layer',
  'Nikāya': 'Nikāya',
  'No matches for': 'No matches for',
  'No matches found for': 'No matches found for',
  'Did you mean…': 'Did you mean…',
  'No results': 'No results',
  'Font size': 'Font size',
  'words': 'words',
  'Show': 'Show',
  'more': 'more',
  'result': 'result',

  // ── Dictionary panel / sheet ────────────────────────────────────────
  'DPD Dictionary': 'DPD Dictionary',
  'Compound breakdown': 'Compound breakdown',
  'Pin to side panel': 'Pin to side panel',
  'Unpin from side panel': 'Unpin from side panel',

  // ── Reader toolbar / paragraphs ─────────────────────────────────────
  'Jump': 'Jump',
  'Hide': 'Hide',
  'Line/L': 'Line/L',
  'Side/S': 'Side/S',
  'Stop': 'Stop',
  'Less': 'Less',
  'Library': 'Library',
  'Reset layout': 'Reset layout',

  // ── Gavesana ────────────────────────────────────────────────────────
  'Gavesana': 'Gavesana',
  'Gavesana AI Search': 'Gavesana AI Search',
  'AI-powered semantic search across the Tipiṭaka.\n\nOpen the full Gavesana panel for detailed results.':
      'AI-powered semantic search across the Tipiṭaka.\n\nOpen the full Gavesana panel for detailed results.',

  // ── AI Q&A (Vimaṃsa) ────────────────────────────────────────────────
  'Navigation menu': 'Navigation menu',
  'Chat history': 'Chat history',
  'New chat': 'New chat',
  'Clear chat': 'Clear chat',
  'Vimaṃsa Settings': 'Vimaṃsa Settings',
  'Building heading index…': 'Building heading index…',
  'Heading index needed for @ — build now?':
      'Heading index needed for @ — build now?',
  'Ask about the Tipitaka': 'Ask about the Tipitaka',
  'Vimaṃsa — investigation through questioning.\n'
          'The AI searches the Tipitaka using tools, gathers relevant passages,\n'
          'and provides detailed answers with clickable citations.\n'
          'Each chat thread is saved — you can continue later.':
      'Vimaṃsa — investigation through questioning.\n'
      'The AI searches the Tipitaka using tools, gathers relevant passages,\n'
      'and provides detailed answers with clickable citations.\n'
      'Each chat thread is saved — you can continue later.',
  'View past conversations': 'View past conversations',
  'Orthodox': 'Orthodox',
  'Answers use only the passages found in the Tipitaka.':
      'Answers use only the passages found in the Tipitaka.',
  'The AI may also use its own knowledge alongside the found passages.':
      'The AI may also use its own knowledge alongside the found passages.',
  'Type @ to attach a heading': 'Type @ to attach a heading',
  'Thread is full — start a new chat': 'Thread is full — start a new chat',
  'Ask about the Tipitaka, or type @ to attach a heading…':
      'Ask about the Tipitaka, or type @ to attach a heading…',
  'Chat History': 'Chat History',
  'New Chat': 'New Chat',
  'No conversations yet': 'No conversations yet',
  'Start a new chat to begin': 'Start a new chat to begin',
  'and all its messages?': 'and all its messages?',
  'query': 'query',
  'queries': 'queries',
  'remaining in this thread': 'remaining in this thread',
  'Translation': 'Translation',

  // ── Context Menu ────────────────────────────────────────────────────
  'Context Menu': 'Context Menu',
  'Customize the selection toolbar': 'Customize the selection toolbar',
  'Customize the actions shown when you select text in the reader. Drag to reorder, toggle to hide, and add apps or AI prompts.':
      'Customize the actions shown when you select text in the reader. Drag to reorder, toggle to hide, and add apps or AI prompts.',
  'Add Prompt': 'Add Prompt',
  'Add App': 'Add App',
  'Prompt Name': 'Prompt Name',
  'Prompt': 'Prompt',
  'Use {selectedText} as a placeholder for the selected text.':
      'Use {selectedText} as a placeholder for the selected text.',
  'Edit Prompt': 'Edit Prompt',
  'Installed Apps': 'Installed Apps',
  'No context menu actions yet. Add apps or prompts below.':
      'No context menu actions yet. Add apps or prompts below.',
  'External app': 'External app',
  'Copy': 'Copy',
  'Copy the selected text': 'Copy the selected text',
  'Excerpt': 'Excerpt',
  'Copy with citation': 'Copy with citation',
  'Copy Link': 'Copy Link',
  'Copy a link to this passage': 'Copy a link to this passage',
  'Explain': 'Explain',
  'Explain the selected text with AI': 'Explain the selected text with AI',
  'Summarize Ch.': 'Summarize Ch.',
  'Summarize the current chapter with AI':
      'Summarize the current chapter with AI',
  'Share': 'Share',
  'Share the selected text': 'Share the selected text',
  'Look up the selected word': 'Look up the selected word',

  // ── Feature Guide ──────────────────────────────────────────────────
  'Feature Guide': 'Feature Guide',
  'Learn what ePitaka can do': 'Learn what ePitaka can do',
  'Step-by-step instructions for the reader toolbar, text selection, settings and the AI assistant.':
      'Step-by-step instructions for the reader toolbar, text selection, settings and the AI assistant.',
  'Take a quick tour of the main features — you can reopen this guide anytime from the menu.':
      'Take a quick tour of the main features — you can reopen this guide anytime from the menu.',
  'Explore features': 'Explore features',
  'Got it': 'Got it',
  'While you wait…': 'While you wait…',
  'While you wait, here is a quick tour of what you can do with ePitaka.':
      'While you wait, here is a quick tour of what you can do with ePitaka.',

  // ── Feature Guide: Reader Toolbar ─────────────────────────────────
  'Reader Toolbar': 'Reader Toolbar',
  'The floating toolbar at the bottom of the reader puts every action one tap away.':
      'The floating toolbar at the bottom of the reader puts every action one tap away.',
  'Contents — jump between sections from the table of contents.':
      'Contents — jump between sections from the table of contents.',
  'Search — find a word or phrase inside the current book.':
      'Search — find a word or phrase inside the current book.',
  'Dictionary — look up any Pāli word instantly.':
      'Dictionary — look up any Pāli word instantly.',
  'Jump — go to a page number or a connected book.':
      'Jump — go to a page number or a connected book.',
  'Display layout — switch between hide-translation, line-by-line and side-by-side views.':
      'Display layout — switch between hide-translation, line-by-line and side-by-side views.',
  'Listen — read the passage aloud with text-to-speech; tap again to stop.':
      'Listen — read the passage aloud with text-to-speech; tap again to stop.',
  'Bookmark — save your place and return to it later from the Library.':
      'Bookmark — save your place and return to it later from the Library.',

  // ── Feature Guide: Context Menu ───────────────────────────────────
  'Select any text in the reader and a toolbar of smart actions appears above it.':
      'Select any text in the reader and a toolbar of smart actions appears above it.',
  'Select text — tap and drag, or double-tap a word.':
      'Select text — tap and drag, or double-tap a word.',
  'Copy — copy the selection as plain text.':
      'Copy — copy the selection as plain text.',
  'Excerpt — copy with a formatted citation.':
      'Excerpt — copy with a formatted citation.',
  'Copy Link — copy a shareable link to this exact passage.':
      'Copy Link — copy a shareable link to this exact passage.',
  'Dictionary — look up the selected word.':
      'Dictionary — look up the selected word.',
  'Explain — ask Vimaṃsa AI to explain the selection.':
      'Explain — ask Vimaṃsa AI to explain the selection.',
  'Summarize Ch. — summarize the current chapter with AI.':
      'Summarize Ch. — summarize the current chapter with AI.',
  'Share — share the selection via the system share sheet.':
      'Share — share the selection via the system share sheet.',
  'Customize — Settings → Context Menu lets you reorder, hide, or add apps and AI prompts.':
      'Customize — Settings → Context Menu lets you reorder, hide, or add apps and AI prompts.',

  // ── Feature Guide: Settings ───────────────────────────────────────
  'Everything you need to personalize ePitaka.':
      'Everything you need to personalize ePitaka.',
  'Language & script — choose the UI language and the Pāli script (Roman, Devanagari, Sinhala, Myanmar, Thai…).':
      'Language & script — choose the UI language and the Pāli script (Roman, Devanagari, Sinhala, Myanmar, Thai…).',
  'Appearance — themes, accent color and reading colors.':
      'Appearance — themes, accent color and reading colors.',
  'Translations & Downloads — download, update and reorder translation databases.':
      'Translations & Downloads — download, update and reorder translation databases.',
  'Reading Options — layout, page numbering, quote format and auto-scroll.':
      'Reading Options — layout, page numbering, quote format and auto-scroll.',
  'Text-to-Speech — voice, speed, pitch and word replacements.':
      'Text-to-Speech — voice, speed, pitch and word replacements.',
  'Dictionaries — enable, disable and reorder dictionaries.':
      'Dictionaries — enable, disable and reorder dictionaries.',
  'AI Q&A — enter your API key and pick models for Vimaṃsa.':
      'AI Q&A — enter your API key and pick models for Vimaṃsa.',

  // ── Feature Guide: AI (Vimaṃsa) ───────────────────────────────────
  'AI — Vimaṃsa': 'AI — Vimaṃsa',
  'Ask the AI about the Tipiṭaka. It searches the Canon and answers with citations.':
      'Ask the AI about the Tipiṭaka. It searches the Canon and answers with citations.',
  'Ask a question — open Vimaṃsa from the menu and ask anything.':
      'Ask a question — open Vimaṃsa from the menu and ask anything.',
  'Explain — select text in the reader and tap Explain for a commentary-grounded explanation.':
      'Explain — select text in the reader and tap Explain for a commentary-grounded explanation.',
  'Summarize — tap Summarize Ch. to get an overview of the current chapter.':
      'Summarize — tap Summarize Ch. to get an overview of the current chapter.',
  'Attach a passage — type @ to attach a sutta or heading to your question.':
      'Attach a passage — type @ to attach a sutta or heading to your question.',
  'Chat history — your conversations are saved; continue them anytime.':
      'Chat history — your conversations are saved; continue them anytime.',
  'Custom prompts — add your own AI prompts in Settings → Context Menu; use {selectedText} as a placeholder.':
      'Custom prompts — add your own AI prompts in Settings → Context Menu; use {selectedText} as a placeholder.',

  // ── App shell ───────────────────────────────────────────────────────
  'Listen': 'Listen',
};
