import 'package:flutter/material.dart';

import '../providers/settings_provider.dart';

/// Localized strings for the ePitaka app UI.
///
/// Supports English and Vietnamese.
class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  String _t(String en, String vi) {
    if (locale.languageCode == 'vi') return vi;
    return en;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  COMMON / SHARED
  // ═══════════════════════════════════════════════════════════════════════

  String get save => _t('Save', 'Lưu');
  String get saving => _t('Saving…', 'Đang lưu…');
  String get cancel => _t('Cancel', 'Hủy');
  String get delete => _t('Delete', 'Xóa');
  String get download => _t('Download', 'Tải về');
  String get retry => _t('Retry', 'Thử lại');
  String get ok => _t('OK', 'Đồng ý');
  String get yes => _t('Yes', 'Có');
  String get no => _t('No', 'Không');
  String get error => _t('Error', 'Lỗi');
  String get confirm => _t('Confirm', 'Xác nhận');
  String get open => _t('Open', 'Mở');
  String get close => _t('Close', 'Đóng');
  String get done => _t('Done', 'Xong');
  String get add => _t('Add', 'Thêm');
  String get update => _t('Update', 'Cập nhật');
  String get search => _t('Search', 'Tìm kiếm');
  String get clear => _t('Clear', 'Xóa');
  String get remove => _t('Remove', 'Xóa bỏ');
  String get none => _t('None', 'Không');
  String get back => _t('Back', 'Quay lại');
  String get unknown => _t('Unknown', 'Không xác định');
  String get untitled => _t('Untitled', 'Chưa có tiêu đề');

  // ═══════════════════════════════════════════════════════════════════════
  //  SETTINGS SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get settings => _t('Settings', 'Cài đặt');
  String get general => _t('General', 'Chung');
  String get language => _t('Language', 'Ngôn ngữ');
  String get appearance => _t('Appearance', 'Giao diện');
  String get appearanceSubtitle => _t('Theme & accent', 'Chủ đề & màu sắc');
  String get dataAndContent => _t('Data & Content', 'Dữ liệu & Nội dung');
  String get translationsDownloads =>
      _t('Translations & Downloads', 'Bản dịch & Tải về');
  String get translationDisplay =>
      _t('Translation Display', 'Hiển thị bản dịch');
  String get translationDisplaySubtitle =>
      _t('Layout, mode & typography', 'Bố cục, chế độ & kiểu chữ');
  String get readingPreferences => _t('Reading Preferences', 'Tùy chỉnh đọc');
  String get readingOptions => _t('Reading Options', 'Tùy chọn đọc');
  String get readingOptionsSubtitle =>
      _t('Layout, numbering & scroll', 'Bố cục, đánh số & cuộn');
  String get textToSpeech => _t('Text-to-Speech', 'Văn bản thành giọng nói');
  String get ttsSubtitle => _t('Voice & speed', 'Giọng & tốc độ');
  String get ttsReplacements => _t('TTS Replacements', 'Thay thế TTS');
  String get ttsReplacementsSubtitle =>
      _t('Regex text replacements', 'Thay thế văn bản bằng regex');
  String get script => _t('Script', 'Chữ viết');
  String get stripVariantAnnotations =>
      _t('Show variant readings', 'Hiển phiên bản văn bản khác');
  String get stripVariantAnnotationsSubtitle => _t(
    'Show variant readings from other textual versions',
    'Hiển thị các phiên bản văn bản từ các bản khác',
  );
  String get libraryBrowser => _t('Library Browser', 'Trình duyệt thư viện');
  String get defaultExpandLevel =>
      _t('Default expand level', 'Mức mở rộng mặc định');
  String get collapsed => _t('Collapsed', 'Thu gọn');
  String get category => _t('Category', 'Danh mục');
  String get expand => _t('Expand', 'Mở rộng');
  String get theme => _t('Theme', 'Chủ đề');
  String get systemTheme => _t('System', 'Hệ thống');
  String get lightTheme => _t('Paper (Light)', 'Sáng');
  String get darkTheme => _t('Dark', 'Tối');
  String get expandResultsDefault =>
      _t('Expand results by default', 'Mở rộng kết quả mặc định');
  String get rebuildSearchIndex =>
      _t('Rebuild search index', 'Xây dựng lại chỉ mục tìm kiếm');
  String get rebuildSearchIndexSubtitle => _t(
    'Re-indexes Pāli texts & translations',
    'Lập chỉ mục lại văn bản Pāli & bản dịch',
  );
  String get dictionaries => _t('Dictionaries', 'Từ điển');
  String get dictionarySettings => _t('Dictionary Settings', 'Cài đặt từ điển');
  String get dictionarySettingsSubtitle =>
      _t('Enable, disable & reorder', 'Bật, tắt & sắp xếp');
  String get account => _t('Account', 'Tài khoản');
  String get profile => _t('Profile', 'Hồ sơ');
  String get system => _t('System', 'Hệ thống');
  String get about => _t('About ePitaka', 'Giới thiệu ePitaka');
  String get help => _t('Help', 'Trợ giúp');
  String get keyboardShortcuts => _t('Keyboard Shortcuts', 'Phím tắt');
  String get searchInBook => _t('Search within the book', 'Tìm trong sách');
  String get globalSearch => _t('Open global search', 'Mở tìm kiếm toàn cục');
  String get closeFocusTab => _t('Close the focus tab', 'Đóng thẻ đang chọn');
  String get closeAllTabs => _t('Close all tabs', 'Đóng tất cả thẻ');
  String get openDictionary => _t('Open dictionary', 'Mở từ điển');
  String get openLibrary => _t('Open library', 'Mở thư viện');
  String get openSettings => _t('Open settings', 'Mở cài đặt');
  String get increaseFontSize => _t('Increase font size', 'Tăng cỡ chữ');
  String get decreaseFontSize => _t('Decrease font size', 'Giảm cỡ chữ');
  String get languageEnglish => _t('English', 'Tiếng Anh');
  String get languageVietnamese => _t('Vietnamese', 'Tiếng Việt');

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

  // ═══════════════════════════════════════════════════════════════════════
  //  APPEARANCE SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get accentColor => _t('Accent Color', 'Màu nhấn');
  String get accentPairPreview =>
      _t('Accent Pair Preview', 'Xem trước cặp màu nhấn');
  String get lightMode => _t('Light mode', 'Chế độ sáng');
  String get darkMode => _t('Dark mode', 'Chế độ tối');
  String get buttonLabel => _t('Button', 'Nút');

  // ═══════════════════════════════════════════════════════════════════════
  //  READING OPTIONS SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get pageNumbering => _t('Page Numbering', 'Đánh số trang');
  String get layout => _t('Layout', 'Bố cục');
  String get sideBySideView => _t('Side-by-Side View', 'Xem song song');
  String get sideBySideSubtitle => _t(
    'Show Pāli and translation side by side',
    'Hiển thị Pāli và bản dịch song song',
  );
  String get copyClipboard => _t('Copy / Clipboard', 'Sao chép');
  String get quoteFormat => _t('Quote Format', 'Định dạng trích dẫn');
  String get defaultCopyScope =>
      _t('Default Copy Scope', 'Phạm vi sao chép mặc định');
  String get autoScrollSpeed => _t('Auto-Scroll Speed', 'Tốc độ tự động cuộn');
  String get display => _t('Display', 'Hiển thị');
  String get keepScreenOn => _t('Keep Screen On', 'Giữ màn hình sáng');
  String get keepScreenOnSubtitle => _t(
    'Prevent screen from dimming while reading',
    'Không cho màn hình tối khi đọc',
  );
  String get bookIdLabel => _t('Book ID', 'Mã sách');
  String get bookNameLabel => _t('Book Name', 'Tên sách');
  String get fullCitation => _t('Full Citation', 'Trích dẫn đầy đủ');
  String get paliOnly => _t('Pāli Only', 'Chỉ Pāli');
  String get translationOnly => _t('Translation Only', 'Chỉ bản dịch');
  String get both => _t('Both', 'Cả hai');
  String get slow => _t('Slow', 'Chậm');
  String get fast => _t('Fast', 'Nhanh');
  String get systemLabel => _t('System', 'Hệ thống');

  // ═══════════════════════════════════════════════════════════════════════
  //  GAVESANA (AI SEARCH)
  // ═══════════════════════════════════════════════════════════════════════

  String get aiSearch => _t('Gavesana (AI Search)', 'Gavesana (Tìm kiếm AI)');
  String get aiSearchAssets => _t('AI Search Assets', 'Tài nguyên tìm kiếm AI');
  String get notDownloaded =>
      _t('Not downloaded — tap to download', 'Chưa tải về — chạm để tải');
  String get readyLabel => _t('Ready', 'Sẵn sàng');
  String get gavesanaAssetsTitle =>
      _t('Gavesana AI Assets', 'Tài nguyên AI Gavesana');
  String get gavesanaAssetsReadyDesc => _t(
    'The AI search model and vector database are ready to use.\n\n'
        'Open the sidebar in the Library screen and tap the Gavesana icon to start searching semantically.',
    'Mô hình AI và cơ sở dữ liệu vector đã sẵn sàng.\n\n'
        'Mở thanh bên trong màn hình Thư viện và chạm vào biểu tượng Gavesana để bắt đầu tìm kiếm ngữ nghĩa.',
  );
  String get downloadGavesanaTitle =>
      _t('Download Gavesana Assets?', 'Tải tài nguyên Gavesana?');
  String get downloadGavesanaDesc => _t(
    'This will download approximately 670 MB of data:\n- AI model (270 MB)\n- Vector database (364 MB)\n- Tokenizer config (33 MB)\n\nA Wi-Fi connection is recommended.',
    'Thao tác này sẽ tải khoảng 670 MB dữ liệu:\n- Mô hình AI (270 MB)\n- Cơ sở dữ liệu vector (364 MB)\n- Cấu hình Tokenizer (33 MB)\n\nNên sử dụng kết nối Wi-Fi.',
  );

  // ═══════════════════════════════════════════════════════════════════════
  //  TRANSLATION SETTINGS SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get displayMode => _t('Display Mode', 'Chế độ hiển thị');
  String get paliTextLabel => _t('Pāli Text', 'Văn bản Pāli');
  String get translationDatabases =>
      _t('Translation Databases', 'Cơ sở dữ liệu bản dịch');
  String get checkForUpdates => _t('Check for Updates', 'Kiểm tra cập nhật');
  String get noUpdates => _t(
    'All translations are up to date.',
    'Tất cả bản dịch đã được cập nhật.',
  );
  String get activeVersion => _t('Active Version', 'Phiên bản đang dùng');
  String get selectThisVersion =>
      _t('Select this version', 'Chọn phiên bản này');
  String get nissayaDesc => _t('Nissaya (word-by-word)', 'Nissaya (từng chữ)');
  String get standardTranslation =>
      _t('Standard translation', 'Bản dịch tiêu chuẩn');
  String get installFirst => _t('Install first', 'Cài đặt trước');
  String get fontFamily => _t('Font Family', 'Phông chữ');
  String get fontSize => _t('Font Size', 'Cỡ chữ');
  String get style => _t('Style', 'Kiểu');
  String get colorLabel => _t('Color', 'Màu sắc');
  String get useForReading => _t('Use for Reading', 'Sử dụng để đọc');
  String get active => _t('Active', 'Đang dùng');
  String get nissaya => _t('Nissaya', 'Nissaya');
  String get enabled => _t('Enabled', 'Đã bật');
  String get disabled => _t('Disabled', 'Đã tắt');
  String get deleteTranslationTitle =>
      _t('Delete Translation?', 'Xóa bản dịch?');

  // ═══════════════════════════════════════════════════════════════════════
  //  TTS SETTINGS SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get ttsEngine => _t('TTS Engine', 'Công cụ TTS');
  String get ttsVoiceLabel => _t('Voice', 'Giọng nói');
  String get ttsSpeed => _t('Speed', 'Tốc độ');
  String get ttPitch => _t('Pitch', 'Cao độ');
  String get ttsLanguageLabel => _t('Language', 'Ngôn ngữ');
  String get engine => _t('Engine', 'Công cụ');
  String get systemTts => _t('System TTS', 'TTS Hệ thống');
  String get systemTtsDesc => _t(
    'Platform-native text-to-speech (fast, no download)',
    'TTS nền tảng gốc (nhanh, không cần tải)',
  );
  String get supertonic => _t('SuperTonic', 'SuperTonic');
  String get supertonicDesc => _t(
    'Neural TTS with 31 languages (~400 MB model download)',
    'TTS thần kinh với 31 ngôn ngữ (tải xuống ~400 MB)',
  );
  String get modelDownload => _t('Model Download', 'Tải mô hình');
  String get modelsInstalled => _t('Models Installed', 'Mô hình đã cài');
  String get ttsModels => _t('TTS Models', 'Mô hình TTS');
  String get allModelsReady =>
      _t('All models are ready for use', 'Tất cả mô hình đã sẵn sàng');
  String get requiresDownload => _t(
    'Requires ~400 MB download for neural TTS',
    'Cần tải ~400 MB cho TTS thần kinh',
  );
  String get speakingRate => _t('Speaking Rate', 'Tốc độ nói');
  String get low => _t('Low', 'Thấp');
  String get high => _t('High', 'Cao');
  String get preview => _t('Preview', 'Xem trước');
  String get testSpeech => _t('Test Speech', 'Thử giọng nói');
  String get testHearSample => _t(
    'Hear a sample of the current voice & settings',
    'Nghe thử giọng nói & cài đặt hiện tại',
  );
  String get playing => _t('Playing…', 'Đang phát…');
  String get tapPauseOrStop => _t(
    'Tap pause or stop to control playback',
    'Chạm tạm dừng hoặc dừng để điều khiển',
  );
  String get paused => _t('Paused', 'Đã tạm dừng');
  String get tapResume =>
      _t('Tap resume to continue', 'Chạm tiếp tục để phát lại');
  String get loadingAudio => _t('Preparing audio…', 'Đang chuẩn bị âm thanh…');
  String get voiceStyle => _t('Voice Style', 'Kiểu giọng');
  String get systemDefault => _t('System Default', 'Mặc định hệ thống');
  String get config => _t('Config', 'Cấu hình');

  // ═══════════════════════════════════════════════════════════════════════
  //  TTS REPLACEMENTS SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get ttsReplacementsDesc => _t(
    'Replace text patterns before TTS reads them aloud.',
    'Thay thế mẫu văn bản trước khi TTS đọc to.',
  );
  String get addReplacement => _t('Add Replacement', 'Thêm thay thế');
  String get noReplacementRules => _t(
    'No replacement rules yet.\nTap "Add Replacement" to create one.',
    'Chưa có quy tắc thay thế nào.\nChạm "Thêm thay thế" để tạo.',
  );
  String get deleteReplacementRule =>
      _t('Delete Replacement Rule?', 'Xóa quy tắc thay thế?');
  String get useRegex => _t('Use Regex', 'Dùng Regex');
  String get find => _t('Find:', 'Tìm:');
  String get replaceWith => _t('Replace with:', 'Thay thế bằng:');
  String get regexUsesDart => _t(
    'Regex uses Dart RegExp syntax.',
    'Regex sử dụng cú pháp Dart RegExp.',
  );
  String get editReplacement => _t('Edit Replacement', 'Sửa thay thế');
  String get addReplacementTitle => _t('Add Replacement', 'Thêm thay thế');

  // ═══════════════════════════════════════════════════════════════════════
  //  READING COLORS SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get readingColors => _t('Reading Colors', 'Màu đọc');
  String get paliTextColor => _t('Pāli Text Color', 'Màu văn bản Pāli');
  String get translationTextColor =>
      _t('Translation Text Color', 'Màu văn bản dịch');
  String get lightModeLabel => _t('Light mode', 'Chế độ sáng');
  String get darkModeAuto => _t('Dark mode (auto)', 'Chế độ tối (tự động)');
  String get darkModePreview => _t('Dark Mode Preview', 'Xem trước chế độ tối');
  String get lightModePreview =>
      _t('Light Mode Preview', 'Xem trước chế độ sáng');

  // ═══════════════════════════════════════════════════════════════════════
  //  TYPOGRAPHY SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get typographyFontSize =>
      _t('Typography & Font Size', 'Kiểu chữ & Cỡ chữ');
  String get noTranslationDatabases => _t(
    'No translation databases found.',
    'Không tìm thấy cơ sở dữ liệu bản dịch.',
  );
  String get downloadInSettings => _t(
    'Download translations in Settings → Translations & Downloads.',
    'Tải bản dịch trong Cài đặt → Bản dịch & Tải về.',
  );
  String get couldNotLoadTranslations =>
      _t('Could not load translations:', 'Không thể tải bản dịch:');

  // ═══════════════════════════════════════════════════════════════════════
  //  DICTIONARY SETTINGS SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get dictionarySettingDesc => _t(
    'Enable, disable, and reorder dictionaries.\nDictionaries appear in this order in the dictionary panel.',
    'Bật, tắt và sắp xếp từ điển.\nTừ điển xuất hiện theo thứ tự này trong bảng từ điển.',
  );
  String get enabledDictionaries =>
      _t('Enabled Dictionaries', 'Từ điển đã bật');
  String get disabledDictionaries =>
      _t('Disabled Dictionaries', 'Từ điển đã tắt');
  String get noDictEnabled => _t(
    'No dictionaries enabled. Tap a dictionary below to enable it.',
    'Chưa bật từ điển nào. Chạm vào từ điển bên dưới để bật.',
  );
  String get errorLoadingDict =>
      _t('Error loading dictionaries:', 'Lỗi tải từ điển:');

  // ═══════════════════════════════════════════════════════════════════════
  //  DICTIONARY SHEET
  // ═══════════════════════════════════════════════════════════════════════

  String get dictionary => _t('Dictionary', 'Từ điển');
  String get searchPali => _t('Search Pāḷi…', 'Tìm Pāḷi…');
  String get dictIdlePrompt => _t(
    'Search for a Pāḷi word to see\ndefinitions across multiple dictionaries',
    'Tìm từ Pāḷi để xem định nghĩa từ nhiều từ điển',
  );
  String get showFullDetails => _t('Show full details', 'Xem chi tiết đầy đủ');
  String get searchResultsFor =>
      _t('Search results for', 'Kết quả tìm kiếm cho');
  String get noDirectMatch =>
      _t('No direct matches found for', 'Không tìm thấy kết quả trực tiếp cho');

  // ═══════════════════════════════════════════════════════════════════════
  //  LIBRARY SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get browse => _t('Browse', 'Duyệt');
  String get reading => _t('Reading', 'Đang đọc');
  String get bookmarks => _t('Bookmarks', 'Đánh dấu');
  String get openTabs => _t('Open Tabs', 'Các tab đang mở');
  String get books => _t('books', 'sách');
  String get noBooksOpen => _t(
    'No books open yet.\nBrowse and open a book to start reading.',
    'Chưa mở sách nào.\nDuyệt và mở sách để bắt đầu đọc.',
  );
  String get history => _t('History', 'Lịch sử');
  String get readingHistory => _t('Reading History', 'Lịch sử đọc');
  String get noBookmarks => _t(
    'No bookmarks yet.\nSave your reading position from the reader.',
    'Chưa có đánh dấu nào.\nLưu vị trí đọc từ trình đọc.',
  );
  String get noHistory => _t('No reading history yet.', 'Chưa có lịch sử đọc.');
  String get removeBookmark => _t('Remove Bookmark?', 'Xóa đánh dấu?');
  String get removeHistoryEntry =>
      _t('Remove History Entry?', 'Xóa mục lịch sử?');
  String get justNow => _t('Just now', 'Vừa xong');
  String get minutesAgo => _t('m ago', 'ph trước');
  String get hoursAgo => _t('h ago', 'g trước');
  String get daysAgo => _t('d ago', 'n trước');
  String get errorLoadingBookmarks =>
      _t('Error loading bookmarks:', 'Lỗi tải đánh dấu:');
  String get errorLoadingHistory =>
      _t('Error loading history:', 'Lỗi tải lịch sử:');
  String get noBooksInPitaka =>
      _t('No books in this Piṭaka yet.', 'Chưa có sách trong Piṭaka này.');
  String get couldNotLoadLibrary => _t(
    'Could not load the Tipitaka library.',
    'Không thể tải thư viện Tipitaka.',
  );
  String get removeBookmarkConfirm => _t('Delete bookmark', 'Xóa đánh dấu');
  String get removeHistoryConfirm =>
      _t('Delete history entry for', 'Xóa mục lịch sử cho');

  // ═══════════════════════════════════════════════════════════════════════
  //  SEARCH SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get searchPaliTexts => _t('Search Pāli texts…', 'Tìm văn bản Pāli…');
  String get fuzzy => _t('Fuzzy', 'Mờ');
  String get wordDistance => _t('Word distance', 'Khoảng cách từ');
  String get anyDistance => _t('Any distance', 'Mọi khoảng cách');
  String get withinNWords => _t('Within', 'Trong vòng');
  String get results => _t('results', 'kết quả');
  String get dist => _t('Dist', 'KC');
  String get searchTipitaka =>
      _t('Search the Pāli Tipiṭaka', 'Tìm Tipiṭaka Pāli');
  String get searchIdleHint => _t(
    'Search across both Pāli text and translations.\nEnable fuzzy mode to match diacritic variations (ā=a, ñ=n, ṭ=t …).',
    'Tìm kiếm trong cả văn bản Pāli và bản dịch.\nBật chế độ mờ để khớp các biến thể dấu phụ (ā=a, ñ=n, ṭ=t …).',
  );
  String get buildingSearchIndex =>
      _t('Building Search Index', 'Đang xây dựng chỉ mục tìm kiếm');
  String get percentComplete => _t('complete', 'hoàn thành');
  String get starting => _t('Starting…', 'Đang bắt đầu…');
  String get noResultsFor => _t('No results for', 'Không có kết quả cho');
  String get tryFuzzySearch => _t(
    'Try enabling fuzzy search or using different terms.',
    'Hãy thử bật tìm kiếm mờ hoặc dùng từ khác.',
  );
  String get showMore => _t('Show more', 'Hiển thị thêm');
  String get remaining => _t('remaining', 'còn lại');
  String get searchFailed => _t('Search failed:', 'Tìm kiếm thất bại:');
  String get typeToSearch => _t(
    'Type a word or phrase to search\nacross all Pāli texts',
    'Nhập từ hoặc cụm từ để tìm\ntrong tất cả văn bản Pāli',
  );
  String get openInReader => _t('Open in Reader', 'Mở trong trình đọc');
  String get noHeadingFound => _t(
    'No heading found for this result',
    'Không tìm thấy tiêu đề cho kết quả này',
  );
  String get failedToLoadPreview =>
      _t('Failed to load preview:', 'Không thể tải xem trước:');

  // ═══════════════════════════════════════════════════════════════════════
  //  READER SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get findInBook => _t('Find in book…', 'Tìm trong sách…');
  String get closeSearch => _t('Close search', 'Đóng tìm kiếm');
  String get previousMatch => _t('Previous match', 'Kết quả trước');
  String get nextMatch => _t('Next match', 'Kết quả sau');
  String get searchTipitakaFull =>
      _t('Search entire Tipiṭaka', 'Tìm toàn bộ Tipiṭaka');
  String get noContentFound =>
      _t('No content found.', 'Không tìm thấy nội dung.');
  String get errorLoadingText => _t('Error loading text:', 'Lỗi tải văn bản:');
  String get copyWithStyle => _t('Copy with Style', 'Sao chép có kiểu');
  String get selectAll => _t('Select All', 'Chọn tất cả');
  String get copyWithQuote => _t('Copy with Quote', 'Sao chép có trích dẫn');

  // ── TTS Reader widgets ───────────────────────────────────────────────
  String get follow => _t('Follow', 'Theo dõi');
  String get ttsControls => _t('TTS Controls', 'Điều khiển TTS');
  String get followTtsPosition =>
      _t('Follow TTS Position', 'Theo dõi vị trí TTS');

  // ── Bookmark Dialog ──────────────────────────────────────────────────
  String get addBookmark => _t('Add Bookmark', 'Thêm đánh dấu');
  String get bookmarkName => _t('Bookmark name', 'Tên đánh dấu');
  String get bookmarkSaved => _t('Bookmark saved:', 'Đã lưu đánh dấu:');
  String get failedToSaveBookmark =>
      _t('Failed to save bookmark:', 'Không thể lưu đánh dấu:');

  // ── Jump Sheet ───────────────────────────────────────────────────────
  String get connectedBooks => _t('Connected Books', 'Sách liên kết');
  String get jumpToPage => _t('Jump to Page', 'Đến trang');
  String get pageNumberingSystem =>
      _t('Page Numbering System', 'Hệ thống đánh số trang');
  String get pageNumberInput => _t('Page Number', 'Số trang');
  String get pageInputHint => _t('e.g. 10 or 1.10', 'vd. 10 hoặc 1.10');
  String get jumpTip => _t(
    'Tip: If pages are numbered like "1.3", you can type just "3" to jump to page 1.3.',
    'Mẹo: Nếu trang được đánh số như "1.3", bạn có thể gõ "3" để đến trang 1.3.',
  );
  String get pageNotFound =>
      _t('not found in this book.', 'không tìm thấy trong sách này.');
  String get noConnectedBooks => _t(
    'No connected books found for this section.',
    'Không tìm thấy sách liên kết cho phần này.',
  );
  String get errorLoadingConnections =>
      _t('Error loading connected books.', 'Lỗi tải sách liên kết.');
  String get section => _t('Section', 'Phần');

  // ── Book Link Section Sheet ─────────────────────────────────────────
  String get linkedFrom => _t('Linked from', 'Liên kết từ');
  String get noContentAvailable =>
      _t('No content available.', 'Không có nội dung.');
  String get couldNotLoadLinked =>
      _t('Could not load linked content.', 'Không thể tải nội dung liên kết.');
  String get linkedParaNotFound =>
      _t('Linked paragraph not found.', 'Không tìm thấy đoạn liên kết.');

  // ═══════════════════════════════════════════════════════════════════════
  //  CONTENTS SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get contents => _t('Contents', 'Mục lục');
  String get searchContents => _t('Search contents…', 'Tìm mục lục…');
  String get searchContentsHint => _t('Search contents…', 'Tìm mục lục…');
  String get noMatchingSections =>
      _t('No matching sections', 'Không có mục nào phù hợp');
  String get noContentsAvailable =>
      _t('No contents available', 'Không có mục lục');

  // ═══════════════════════════════════════════════════════════════════════
  //  AI ASSISTANT (Paññā)
  // ═══════════════════════════════════════════════════════════════════════

  String get aiName => _t('Paññā', 'Paññā');
  String get aiSubtitle => _t('AI Research Assistant', 'Trợ lý nghiên cứu AI');
  String get answerMode => _t('💬 Answer', '💬 Trả lời');
  String get answerModeSub => _t('Q&A', 'Hỏi & Đáp');
  String get literalReviewMode =>
      _t('📖 Literal Review', '📖 Nghiên cứu văn bản');
  String get literalReviewModeSub => _t('Deep research', 'Nghiên cứu sâu');
  String get askQuestion => _t('Ask a Question', 'Đặt câu hỏi');
  String get literalReviewTitle => _t('Literal Review', 'Nghiên cứu văn bản');
  String get askQuestionDesc => _t(
    'Ask any question about the Tipitaka. The Assistant will search the Pāli Canon and provide a grounded answer with sources.',
    'Hỏi bất kỳ câu hỏi nào về Tipitaka. Trợ lý sẽ tìm trong Kinh điển Pāli và cung cấp câu trả lời có nguồn.',
  );
  String get literalReviewDesc => _t(
    'Enter a research topic to search the Tipitaka and receive a structured literal review with Pāli quotes and citations.',
    'Nhập chủ đề nghiên cứu để tìm trong Tipitaka và nhận bài nghiên cứu có cấu trúc với trích dẫn Pāli.',
  );
  String get apiKeyRequired => _t('API key required', 'Cần khóa API');
  String get configureApiKey => _t('Configure API Key', 'Cấu hình khóa API');
  String get startConversation =>
      _t('Start a conversation', 'Bắt đầu trò chuyện');
  String get enterTopic =>
      _t('Enter a research topic…', 'Nhập chủ đề nghiên cứu…');
  String get askTipitaka =>
      _t('Ask a question about the Tipitaka…', 'Hỏi về Tipitaka…');
  String get aiSettings => _t('AI Settings', 'Cài đặt AI');
  String get sources => _t('Sources', 'Nguồn');
  String get cited => _t('cited', 'đã trích dẫn');
  String get failedToLoadSource =>
      _t('Failed to load text', 'Không thể tải văn bản');
  String get lineByLine => _t('Line-by-line', 'Từng dòng');

  // ═══════════════════════════════════════════════════════════════════════
  //  AI SETTINGS SHEET
  // ═══════════════════════════════════════════════════════════════════════

  String get aiSettingsTitle =>
      _t('AI Assistant Settings', 'Cài đặt Trợ lý AI');
  String get apiKeyConfigured =>
      _t('API key is configured', 'Khóa API đã được cấu hình');
  String get apiKeyRequiredMsg => _t(
    'API key required — enter your Gemini key below',
    'Cần khóa API — nhập khóa Gemini bên dưới',
  );
  String get geminiApiKey => _t('Gemini API Key', 'Khóa API Gemini');
  String get apiKeyHint => _t('AIza...', 'AIza...');
  String get getApiKeyHint => _t(
    'Get your free Gemini API key at makersuite.google.com',
    'Lấy khóa API Gemini miễn phí tại makersuite.google.com',
  );
  String get renderModel => _t(
    'Render Model (for generating answers)',
    'Mô hình kết xuất (để tạo câu trả lời)',
  );
  String get renderModelDesc => _t(
    'Used for the main answer generation. Needs strong reasoning.',
    'Được dùng để tạo câu trả lời chính. Cần khả năng suy luận mạnh.',
  );
  String get liteModel => _t(
    'Lite Model (for filtering & search)',
    'Mô hình nhẹ (để lọc & tìm kiếm)',
  );
  String get liteModelDesc => _t(
    'Fast model for re-ranking results and query expansion.',
    'Mô hình nhanh để sắp xếp lại kết quả và mở rộng truy vấn.',
  );
  String get saveSettings => _t('Save Settings', 'Lưu cài đặt');
  String get aiSettingsSaved => _t('AI settings saved', 'Đã lưu cài đặt AI');

  // ═══════════════════════════════════════════════════════════════════════
  //  GAVESANA SCREEN
  // ═══════════════════════════════════════════════════════════════════════

  String get askAboutTipitaka =>
      _t('Ask about the Tipitaka…', 'Hỏi về Tipitaka…');
  String get numberOfResults => _t('Number of results', 'Số lượng kết quả');
  String get loadingGavesana => _t('Loading Gavesana…', 'Đang tải Gavesana…');
  String get loadingModels => _t('Loading models…', 'Đang tải mô hình…');
  String get computingEmbedding =>
      _t('Computing query embedding…', 'Đang tính embedding truy vấn…');
  String get searchingVectorDb =>
      _t('Searching vector database…', 'Đang tìm trong cơ sở dữ liệu vector…');
  String get searchSemantically => _t(
    'Search semantically across the Tipitaka',
    'Tìm kiếm ngữ nghĩa trong Tipitaka',
  );
  String get gavesanaDesc => _t(
    "Gavesana uses AI to find passages related to your\nquery, even if they don't share exact words.",
    'Gavesana sử dụng AI để tìm các đoạn liên quan đến\ntruy vấn của bạn, ngay cả khi không có từ chính xác.',
  );
  String get gavesanaAssetsNotFound => _t(
    'Gavesana AI assets not found.',
    'Không tìm thấy tài nguyên AI Gavesana.',
  );
  String get downloadInSettingsHint =>
      _t('Download them in Settings.', 'Tải chúng trong Cài đặt.');
  String get anErrorOccurred => _t('An error occurred', 'Đã xảy ra lỗi');

  // ═══════════════════════════════════════════════════════════════════════
  //  APP SHELL (Toolbar)
  // ═══════════════════════════════════════════════════════════════════════

  String get toolbarContents => _t('Contents', 'Mục lục');
  String get toolbarSearch => _t('Search', 'Tìm kiếm');
  String get toolbarDictionary => _t('Dictionary', 'Từ điển');
  String get toolbarListen => _t('Listen', 'Nghe');
  String get toolbarSave => _t('Save', 'Lưu');

  // ═══════════════════════════════════════════════════════════════════════
  //  INDEXING
  // ═══════════════════════════════════════════════════════════════════════

  String get availableTranslations =>
      _t('Available Translations', 'Bản dịch khả dụng');
  String get noTranslationsAvailable => _t(
    'No translations available.\nPlease download a translation first.',
    'Không có bản dịch nào.\nVui lòng tải bản dịch trước.',
  );
  String get buildIndex => _t('Build Index', 'Xây dựng chỉ mục');
  String get selectATranslation => _t('Select a Translation', 'Chọn bản dịch');
  String get buildFailed => _t('Build Failed', 'Xây dựng thất bại');
  String get indexBuilt => _t('Index Built!', 'Đã xây chỉ mục!');
  String get preparing => _t('Preparing…', 'Đang chuẩn bị…');
  String get installing => _t('Installing…', 'Đang cài đặt…');
  String get readyToIndex => _t('Ready to index', 'Sẵn sàng lập chỉ mục');
  String get downloadCancelled => _t('Download cancelled', 'Đã hủy tải');
  String get downloadFailed => _t('Download failed', 'Tải thất bại');
  String get checkingIndex =>
      _t('Checking search index…', 'Đang kiểm tra chỉ mục tìm kiếm…');
  String get welcomeToEpitaka =>
      _t('Welcome to ePitaka', 'Chào mừng đến với ePitaka');
  String get indexingRequired => _t(
    'To enable full-text search, we need to build a search index for the Pāli texts and translations.',
    'Để bật tìm kiếm toàn văn, chúng tôi cần xây dựng chỉ mục tìm kiếm cho văn bản Pāli và bản dịch.',
  );
  String get indexingOnce => _t(
    'The indexing only needs to happen once.\nYou can rebuild later from Settings.',
    'Việc lập chỉ mục chỉ cần thực hiện một lần.\nBạn có thể xây dựng lại sau từ Cài đặt.',
  );
  String get noTranslationsForDownload => _t(
    'No translations available for download.',
    'Không có bản dịch nào để tải.',
  );
  String get downloadTranslationToStart =>
      _t('Download a translation to get started:', 'Tải bản dịch để bắt đầu:');
  String get chooseTranslationToIndex =>
      _t('Choose a translation to index:', 'Chọn bản dịch để lập chỉ mục:');
  String get buildIndexPali => _t('Build Index (Pāli)', 'Xây chỉ mục (Pāli)');

  // ═══════════════════════════════════════════════════════════════════════
  //  INDEX BUILD DIALOG
  // ═══════════════════════════════════════════════════════════════════════

  String get buildSearchIndex =>
      _t('Build Search Index', 'Xây dựng chỉ mục tìm kiếm');
  String get chooseTranslation => _t(
    'Choose a translation to include in the search index.',
    'Chọn bản dịch để đưa vào chỉ mục tìm kiếm.',
  );

  // ═══════════════════════════════════════════════════════════════════════
  //  FEEDBACK
  // ═══════════════════════════════════════════════════════════════════════

  String get sendFeedback => _t('Send Feedback', 'Gửi phản hồi');

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
        return _t('Thai', 'Thái Lan');
      case 'my':
        return _t('Myanmar', 'Myanmar');
      default:
        return 'VRI';
    }
  }
}

/// Delegate that creates [AppLocalizations] for supported locales.
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizationsDelegate.supportedLocales.contains(locale);

  static const supportedCodes = ['en', 'vi'];

  static List<Locale> get supportedLocales =>
      supportedCodes.map((c) => Locale(c)).toList();

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
