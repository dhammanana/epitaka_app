/// Chinese (Simplified) UI strings.
///
/// Keys are the English source strings (see `en.dart`). Add a new language
/// by copying `en.dart`, translating the values, and registering the file
/// in `app_strings.dart`.
///
/// Translation notes:
///   • Pāli names and technical terms (Tipiṭaka, Nikāya, Nissaya, Gavesanā,
///     Vīmaṃsā, sutta, …) are kept in their original Pāli form, with a
///     Chinese rendering added only where it helps readers.
///   • Short fragment keys that the app joins with dynamic values (e.g.
///     'Search results for', 'm ago') are written so the joined result
///     reads naturally in Chinese.
const Map<String, String> zh = {
  // ── Common ──────────────────────────────────────────────────────────
  'Save': '保存',
  'Saving…': '正在保存…',
  'Cancel': '取消',
  'Delete': '删除',
  'Download': '下载',
  'Retry': '重试',
  'OK': '确定',
  'Yes': '是',
  'No': '否',
  'Error': '错误',
  'Confirm': '确认',
  'Open': '打开',
  'Close': '关闭',
  'Done': '完成',
  'Add': '添加',
  'Update': '更新',
  'Search': '搜索',
  'Clear': '清除',
  'Remove': '移除',
  'None': '无',
  'Back': '返回',
  'Unknown': '未知',
  'Untitled': '无标题',
  'Apply': '应用',
  'Check': '检查',
  'Rebuild': '重建',
  "What's New": '新功能',
  'Required': '必需',
  'Installed': '已安装',
  'Not installed': '未安装',
  'Coming soon': '即将推出',
  'Building…': '正在构建…',
  'Not built': '未构建',
  'Ready': '就绪',
  'sentences': '句',
  'results': '条结果',
  'Loading…': '正在加载…',
  'Manage translation databases: download, update, and delete.':
      '管理译文数据库：下载、更新和删除。',
  'Pāli': 'Pāli（巴利语）',
  'Pāli script': 'Pāli 文字',
  'Script used to write Pāli for the TTS voice. Each script needs its language voice installed. Hindi is the default — it reads Pāli best.':
      '为语音朗读书写 Pāli 所用的文字。每种文字都需要安装对应语言的语音。默认为印地语（天城文）——朗读 Pāli 的效果最好。',
  'Auto': '自动',
  'Sinhala': '僧伽罗文',
  'Devanagari (Hindi)': '天城文（印地语）',
  'Roman (English)': '罗马字（英语）',
  'Best available voice — Devanagari, Sinhala or Roman':
      '自动选择最佳可用语音——天城文、僧伽罗文或罗马字',
  'Needs a Sinhala voice installed (si-LK)': '需要安装僧伽罗语语音 (si-LK)',
  'Needs a Hindi voice installed (hi-IN)': '需要安装印地语语音 (hi-IN)',
  'Needs a Thai voice installed (th-TH)': '需要安装泰语语音 (th-TH)',
  'Needs a Myanmar voice installed (my-MM)': '需要安装缅甸语语音 (my-MM)',
  'Reads with an English voice — works on every device':
      '使用英语语音朗读——所有设备均可使用',
  'Install voice': '安装语音',
  'Open your device Text-to-speech settings to install voices (Sinhala/Hindi for Pāli)':
      '打开设备的文字转语音设置以安装语音（朗读 Pāli 请安装僧伽罗语/印地语）',
  'This voice is not installed on your device. Tap "Install voice" to add it.':
      '此语音尚未安装在您的设备上。请点按“安装语音”进行添加。',
  'Drag to reorder enabled translations. The first one is shown when multiple are enabled.':
      '拖动以调整已启用译文的顺序。启用多个译文时，将显示排在第一位的译文。',
  'Drag to reorder': '拖动以调整顺序',
  'No translations downloaded yet. Download a translation above to reorder it.':
      '尚未下载任何译文。请先在上方下载译文，然后才能调整顺序。',
  'No translations found or available for download.': '未找到可下载的译文。',
  'Checking for updates…': '正在检查更新…',
  'Check for translation updates from GitHub.': '从 GitHub 检查译文更新。',
  'This will remove the database file from your device.':
      '这将从您的设备中移除该数据库文件。',
  'Deleted ': '已删除 ',
  'Version Info': '版本信息',
  'Filename': '文件名',
  'Type': '类型',
  'Suffix': '后缀',
  'Default': '默认',
  'Size': '大小',
  'Updated': '更新时间',
  'Installed on': '安装时间',
  'Status': '状态',
  'Nissaya translations show word-by-word Pāli breakdown with meanings, displayed as pali: meaning | pali: meaning.':
      'Nissaya 译本逐词拆分 Pāli 并附上词义，显示格式为 pali: 词义 | pali: 词义。',
  'Customize the citation format. Use the variables shown below.':
      '自定义引文格式。请使用下方所示的变量。',
  'Quick formats': '快捷格式',
  'Long': '完整',
  'VRI Short': 'VRI 简式',
  'PTS Short': 'PTS 简式',
  'Myanmar Short': '缅甸版简式',
  'Thai Short': '泰国版简式',
  'Available variables: {book_id}, {book_name}, {heading}, {para_id}, {vri_page}, {pts_page}, {thai_page}, {myanmar_page}':
      '可用变量：{book_id}, {book_name}, {heading}, {para_id}, {vri_page}, {pts_page}, {thai_page}, {myanmar_page}',
  'Error: ': '错误：',
  'Could not load preview: ': '无法加载预览：',
  'Bookmark saved: ': '书签已保存：',
  'Failed to save bookmark: ': '保存书签失败：',

  // ── Annotations (highlights, notes, bookmarks, sync) ──────────────────
  'Annotations': '批注',
  'No annotations yet.\nSelect text and tap Highlight or Note in the toolbar.':
      '暂无批注。\n请选择文字，然后点按工具栏中的“高亮”或“笔记”。',
  'Open a book to see your annotations.': '打开一本书即可查看您的批注。',
  'Error loading annotations:': '加载批注出错：',
  'Highlight': '高亮',
  'Highlight the selected text': '高亮所选文字',
  'Note': '笔记',
  'Attach a markdown note to the selection': '为所选内容添加 Markdown 笔记',
  'Highlight added': '已添加高亮',
  'Could not anchor the selection — try again.': '无法定位所选内容——请重试。',
  'Add Note': '添加笔记',
  'Edit': '编辑',
  'Write a note… supports **markdown**': '写下笔记…支持 **Markdown**',
  'Change color': '更改颜色',
  'Markdown supported': '支持 Markdown',
  'Delete annotation?': '删除批注？',
  'This removes the highlight or note.': '这将移除该高亮或笔记。',
  'This removes the bookmark.': '这将移除该书签。',
  'Edit note': '编辑笔记',
  'Color updated': '颜色已更新',
  'More actions': '更多操作',

  // ── Annotations screen (all books) ──────────────────────────────────
  'All': '全部',
  'Highlights': '高亮',
  'Notes': '笔记',
  'Highlights, notes & bookmarks': '高亮、笔记和书签',
  'No highlights yet.': '暂无高亮。',
  'No notes yet.': '暂无笔记。',
  'Search annotations…': '搜索批注…',
  'Try a different search term.': '请尝试其他搜索词。',
  'Clear search': '清除搜索',
  'Filter by book': '按书籍筛选',
  'All books': '全部书籍',
  'No annotations in the selected books.': '所选书籍中暂无批注。',
  'More colors': '更多颜色',
  'Collapse': '收起',

  // ── Script Converter screen ──────────────────────────────────────────
  'Script Converter': '文字转换器',
  'Pāli Script Converter': 'Pāli 文字转换器',
  'Convert Pāli text between any scripts — the same converter the reader uses.':
      '在任意文字之间转换 Pāli 文本——与阅读器使用的转换器相同。',
  'From': '从',
  'To': '到',
  'Use result as input': '将结果用作输入',
  'Type or paste Pāli text…': '输入或粘贴 Pāli 文本…',
  'characters': '个字符',
  'Your converted text will appear here.': '转换后的文本将显示在这里。',

  // ── Account / Cloud Sync ──────────────────────────────────────────────
  'Sign in': '登录',
  'Sign out': '退出登录',
  'Sign in to sync': '登录以同步',
  'Sign in failed. Please try again.': '登录失败，请重试。',
  'Sync active — highlights, notes & bookmarks are backed up':
      '同步已开启——高亮、笔记和书签已备份',
  'Sync off — annotations are stored on this device only':
      '同步已关闭——批注仅保存在本设备上',

  // ── Settings ────────────────────────────────────────────────────────
  'Settings': '设置',
  'General': '通用',
  'Language': '语言',
  'Appearance': '外观',
  'Theme & accent': '主题与强调色',
  'Data & Content': '数据与内容',
  'Translations & Downloads': '译文与下载',
  'Reading Preferences': '阅读偏好',
  'Reading Options': '阅读选项',
  'Layout, numbering & scroll': '版式、页码与滚动',
  'Text-to-Speech': '文字转语音',
  'Voice & speed': '语音与语速',
  'TTS Replacements': '朗读替换规则',
  'Regex text replacements': '正则表达式文本替换',
  'Script': '文字',
  'Show variant readings': '显示异读',
  'Show variant readings from other textual versions': '显示其他版本的异读',
  'Library Browser': '藏经库浏览',
  'Default expand level': '默认展开层级',
  'Collapsed': '已收起',
  'Category': '分类',
  'Expand': '展开',
  'Theme': '主题',
  'Dhammatā': 'Dhammatā（法性）',
  'Tālapatta': 'Tālapatta（贝叶）',
  'Paññā-āloka': 'Paññā-āloka（慧光）',
  'Vimutti-rasa': 'Vimutti-rasa（解脱味）',
  'Samādhi': 'Samādhi（定）',
  'Passaddhi': 'Passaddhi（轻安）',
  'Arañña': 'Arañña（阿兰若）',
  'Natural Law / Adaptability': '自然法则 / 适应性',
  'Preserved Sacred Texts': '传承的圣典',
  'Illuminating Wisdom': '照亮的智慧',
  'Oceanic Taste of Freedom': '如海的解脱之味',
  'Meditative Stillness': '禅修的静定',
  'Profound Tranquility': '深沉的宁静',
  'Forest Seclusion': '森林的独处',
  'Expand results by default': '默认展开搜索结果',
  'Rebuild search index': '重建搜索索引',
  'Re-indexes Pāli texts & translations': '重新为 Pāli 原文和译文建立索引',
  'Dictionaries': '词典',
  'Dictionary Settings': '词典设置',
  'Enable, disable & reorder': '启用、停用和排序',
  'Account': '账号',
  'Profile': '个人资料',
  'System': '系统',
  'Usage statistics': '使用统计',
  'Anonymous, helps improve the app': '匿名收集，有助于改进应用',
  'Crash reports': '崩溃报告',
  'Sends error reports to fix bugs faster': '发送错误报告，以便更快修复问题',
  'About ePitaka': '关于 ePitaka',
  'Help': '帮助',
  'Keyboard Shortcuts': '键盘快捷键',
  'Search within the book': '在本书中搜索',
  'Search books…': '搜索书籍…',
  'Open global search': '打开全局搜索',
  'Close the focus tab': '关闭当前标签页',
  'Close all tabs': '关闭所有标签页',
  'Open dictionary': '打开词典',
  'Open library': '打开藏经库',
  'Open settings': '打开设置',
  'Increase font size': '增大字号',
  'Decrease font size': '减小字号',
  'English': '英语',
  'Vietnamese': '越南语',
  'AI Q&A': 'AI 问答',
  'AI Q&A Settings': 'AI 问答设置',
  'API key, models, etc.': 'API 密钥、模型等',
  'No download URL available for AI search assets':
      '没有可用于下载 AI 搜索资源的网址',

  // ── Appearance ──────────────────────────────────────────────────────
  'Accent Color': '强调色',
  'Accent Pair Preview': '强调色配对预览',
  'Light mode': '浅色模式',
  'Dark mode': '深色模式',
  'Button': '按钮',
  'Text Alignment': '文字对齐',
  'Text alignment for reading content': '阅读内容的文字对齐方式',
  'Left': '左对齐',
  'Center': '居中',
  'Right': '右对齐',
  'Justify': '两端对齐',
  'Line Spacing': '行间距',
  'Paragraph Spacing': '段间距',
  'Additional spacing in pixels': '额外间距（像素）',

  // ── Reading Options ─────────────────────────────────────────────────
  'Page Numbering': '页码系统',
  'Layout': '版式',
  'Side-by-Side View': '并排视图',
  'Show Pāli and translation side by side': '并排显示 Pāli 原文与译文',
  'Copy / Clipboard': '复制 / 剪贴板',
  'Quote Format': '引文格式',
  'Default Copy Scope': '默认复制范围',
  'Auto-Scroll Speed': '自动滚动速度',
  'Display': '显示',
  'Keep Screen On': '保持屏幕常亮',
  'Prevent screen from dimming while reading': '阅读时防止屏幕变暗',
  'Show Inline Commentaries': '显示内嵌注释',
  'Show links to inlined commentaries & connected books':
      '显示指向内嵌注释和关联书籍的链接',
  'Auto hide toolbar': '自动隐藏工具栏',
  'Book ID': '书籍编号',
  'Book Name': '书名',
  'Full Citation': '完整引文',
  'Pāli Only': '仅 Pāli 原文',
  'Translation Only': '仅译文',
  'Both': '两者',
  'Slow': '慢',
  'Fast': '快',
  'Template': '模板',
  'Page System': '页码体系',
  'No translation': '不显示译文',
  'Hide all translations': '隐藏所有译文',
  'Line by line': '逐行对照',
  'Pāli above translation': 'Pāli 原文在上，译文在下',
  'Side by side': '左右对照',
  'Pāli beside translation': 'Pāli 原文与译文并排',
  'Only translation': '仅译文',
  'Show only the translation': '仅显示译文',
  'Translations': '译文',
  'Tap to translate': '点按翻译',
  'Any': '任意',

  // ── Gavesana (AI search) ────────────────────────────────────────────
  'Gavesanā (AI Search)': 'Gavesanā（AI 搜索）',

  'Open Gavesanā': '打开 Gavesanā',
  'found': '条结果',
  'Section headings': '章节标题',
  'Describe what you\u2019re looking for — the AI will search the Tipitaka for relevant passages.':
      '请描述您要寻找的内容——AI 将在三藏中搜索相关段落。',
  'Search with AI': '使用 AI 搜索',
  'AI is searching the Tipitaka…': 'AI 正在搜索三藏…',
  'AI search steps': 'AI 搜索步骤',
  'AI searched for': 'AI 搜索了',
  'AI-found passages': 'AI 找到的段落',
  'The AI could not find any relevant passages. Try a different description.':
      'AI 未能找到相关段落。请尝试换一种描述。',
  'Configure AI in Settings': '在设置中配置 AI',
  'Gavesanā AI search needs an API key. Configure it in Settings → AI Q&A.':
      'Gavesanā AI 搜索需要 API 密钥。请在“设置 → AI 问答”中配置。',

  // ── Translation Builder ────────────────────────────────────────────
  'Translation Builder': '译文生成器',
  'Translate books on-device with AI': '在设备上使用 AI 翻译书籍',
  'Start Translation': '开始翻译',
  'Share DB': '分享数据库',
  'AI Configuration': 'AI 配置',
  'Target Language': '目标语言',
  'Books to Translate': '待翻译的书籍',
  'System Prompt': '系统提示词',
  'API Keys': 'API 密钥',
  'Manage API Keys': '管理 API 密钥',
  'Model': '模型',
  'Books': '书籍',
  'Custom prompt': '自定义提示词',
  'Primary': '主要',

  // ── Translation Settings ────────────────────────────────────────────
  'Display Mode': '显示模式',
  'Pāli Text': 'Pāli 原文',
  'Translation Text': '译文',
  'Translation Databases': '译文数据库',
  'Check for Updates': '检查更新',
  'All translations are up to date.': '所有译文均为最新版本。',
  'Active Version': '当前版本',
  'Select this version': '选用此版本',
  'Nissaya (word-by-word)': 'Nissaya（逐词对译）',
  'Standard translation': '标准译文',
  'Install first': '请先安装',
  'Font Family': '字体',
  'Font Size': '字号',
  'Style': '样式',
  'Color': '颜色',
  'Use for Reading': '用于阅读',
  'Active': '使用中',
  'Nissaya': 'Nissaya',
  'Enabled': '已启用',
  'Disabled': '已停用',
  'Delete Translation?': '删除译文？',
  'Delete Translation': '删除译文',
  'Delete translation': '删除译文',
  'Translation Order': '译文顺序',
  'Pick Color': '选择颜色',
  'Hide Translation': '隐藏译文',
  'Show only Pāli text, joined as paragraphs': '仅显示 Pāli 原文，合并为段落',
  'Line by Line': '逐行对照',
  'Show Pāli followed by its translation': '先显示 Pāli 原文，随后显示对应译文',
  'Side by Side': '左右对照',
  'Show Pāli and translation in two columns': '分两栏显示 Pāli 原文与译文',
  'Update check complete.': '更新检查完成。',

  // ── TTS Settings ────────────────────────────────────────────────────
  'Speed': '语速',
  'Trans. speed': '译文语速',
  'Pitch': '音调',
  'Speaking Rate': '朗读速度',
  'Low': '低',
  'High': '高',
  'Preview': '预览',
  'Test Speech': '试听',
  'Hear a sample of the current voice & settings': '试听当前语音和设置的效果',
  'Playing…': '正在播放…',
  'Tap pause or stop to control playback': '点按暂停或停止以控制播放',
  'Paused': '已暂停',
  'Tap resume to continue': '点按继续以恢复播放',
  'Preparing audio…': '正在准备音频…',
  'System Default': '系统默认',
  'Config': '配置',
  'Speak': '朗读',
  'Only first translation': '仅第一个译文',
  'Reads the translation aloud': '朗读译文',
  'Reads the Pāli aloud, written in Devanagari (Hindi) for the best pronunciation':
      '朗读 Pāli 原文，以天城文（印地语）书写以获得最佳发音',
  'Translation + Pāli': '译文 + Pāli',
  'Reads the Pāli first, then its translation': '先朗读 Pāli 原文，再朗读其译文',
  'Translation note': '译文注释',
  'Translation remark': '译文备注',
  'Edit translation info': '编辑译文信息',
  'Paragraph': '段落',
  'Line': '行',
  'Conflict': '冲突',
  'Add remark': '添加备注',
  'ttsNextParagraph': '下一段',
  'ttsCollapse': '收起',
  'Pāli speed': 'Pāli 语速',
  'Pāli voice': 'Pāli 语音',
  'Translation voice': '译文语音',
  'Hindi voice not installed': '未安装印地语语音',
  'voice not installed': '语音未安装',
  'Enter any speed up to': '可输入任意速度，最高为',
  'Hindi voice missing desc':
      '朗读 Pāli 需要印地语（天城文）语音。'
      '请在设备的文字转语音设置中安装。',
  'Install Hindi voice': '安装印地语语音',

  // ── TTS Replacements ────────────────────────────────────────────────
  'Replace text patterns before TTS reads them aloud.':
      '在朗读之前替换指定的文本模式。',
  'Add Replacement': '添加替换规则',
  'No replacement rules yet.\nTap "Add Replacement" to create one.':
      '暂无替换规则。\n点按“添加替换规则”即可创建。',
  'Delete Replacement Rule?': '删除替换规则？',
  'Use Regex': '使用正则表达式',
  'Find:': '查找：',
  'Replace with:': '替换为：',
  'Regex uses Dart RegExp syntax.': '正则表达式使用 Dart RegExp 语法。',
  'Edit Replacement': '编辑替换规则',
  'Are you sure you want to delete this rule?': '确定要删除此规则吗？',

  // ── Reading Colors ──────────────────────────────────────────────────
  'Reading Colors': '阅读颜色',
  'Pāli Text Color': 'Pāli 原文颜色',
  'Translation Text Color': '译文颜色',
  'Dark mode (auto)': '深色模式（自动）',
  'Dark Mode Preview': '深色模式预览',
  'Light Mode Preview': '浅色模式预览',
  'Pick a color': '选择颜色',

  // ── Typography ──────────────────────────────────────────────────────
  'Typography & Font Size': '排版与字号',
  'No translation databases found.': '未找到译文数据库。',
  'Download translations in Settings → Translations & Downloads.':
      '请在“设置 → 译文与下载”中下载译文。',
  'Could not load translations:': '无法加载译文：',

  // ── Dictionary Settings ─────────────────────────────────────────────
  'Enable, disable, and reorder dictionaries.\n'
          'Dictionaries appear in this order in the dictionary panel.':
      '启用、停用并调整词典顺序。\n'
      '词典将按此顺序显示在词典面板中。',
  'Enabled Dictionaries': '已启用的词典',
  'Disabled Dictionaries': '已停用的词典',
  'No dictionaries enabled. Tap a dictionary below to enable it.':
      '尚未启用任何词典。点按下方的词典即可启用。',
  'Error loading dictionaries:': '加载词典出错：',

  // ── Dictionary Sheet ────────────────────────────────────────────────
  'Dictionary': '词典',
  'Search Pāḷi…': '搜索 Pāḷi…',
  'Search for a Pāḷi word to see\ndefinitions across multiple dictionaries':
      '搜索一个 Pāḷi 词汇，\n即可查看多部词典中的释义',
  'Show full details': '显示完整详情',
  'Search results for': '搜索结果：',
  'No direct matches found for': '没有直接匹配：',

  // ── Library ─────────────────────────────────────────────────────────
  'Browse': '浏览',
  'Reading': '阅读',
  'Bookmarks': '书签',
  'Open Tabs': '已打开的标签页',
  'books': '本书',
  'No books open yet.\nBrowse and open a book to start reading.':
      '尚未打开任何书籍。\n请浏览并打开一本书开始阅读。',
  'No books open yet.': '尚未打开任何书籍。',
  'History': '历史记录',
  'Reading History': '阅读历史',
  'No bookmarks yet.\nSave your reading position from the reader.':
      '暂无书签。\n请在阅读器中保存您的阅读位置。',
  'No bookmarks yet.': '暂无书签。',
  'No reading history yet.': '暂无阅读历史。',
  'Listening': '收听',
  'No listening history yet.': '暂无收听历史。',
  'Remove Bookmark?': '移除书签？',
  'Remove History Entry?': '移除历史记录？',
  'Just now': '刚刚',
  'm ago': '分钟前',
  'h ago': '小时前',
  'd ago': '天前',
  'Error loading bookmarks:': '加载书签出错：',
  'Error loading history:': '加载历史记录出错：',
  'No books in this Piṭaka yet.': '此藏中暂无书籍。',
  'Could not load the Tipitaka library.': '无法加载三藏藏经库。',
  'Delete bookmark': '删除书签',
  'Delete history entry for': '删除历史记录：',
  'Removed: ': '已移除：',
  'Search Index': '搜索索引',

  // ── Search ──────────────────────────────────────────────────────────
  'Search Pāli texts…': '搜索 Pāli 文本…',
  'Fuzzy': '模糊',
  'Exact': '精确',
  'Word distance': '词间距',
  'Any distance': '不限间距',
  'Within': '范围',
  'Dist': '间距',
  'Search the Pāli Tipiṭaka': '搜索 Pāli 三藏',
  'Search across both Pāli text and translations.\n'
          'Diacritics are ignored (ā=a, ñ=n, ṭ=t …).':
      '同时搜索 Pāli 原文和译文。\n'
      '搜索时忽略变音符号（ā=a、ñ=n、ṭ=t …）。',
  'Building Search Index': '正在构建搜索索引',
  'complete': '已完成',
  'Starting…': '正在启动…',
  'No results for': '没有结果：',
  'Try enabling fuzzy search or using different terms.':
      '请尝试启用模糊搜索，或更换搜索词。',
  'Show more': '显示更多',
  'remaining': '剩余',
  'Search failed:': '搜索失败：',
  'Type a word or phrase to search\nacross all Pāli texts':
      '输入词语或短语，\n在所有 Pāli 文本中搜索',
  'Open in Reader': '在阅读器中打开',
  'No heading found for this result': '此结果没有对应的标题',
  'Failed to load preview:': '加载预览失败：',
  'Velthuis typing': 'Velthuis 输入法',
  'Sanskrit': '梵语',
  'Regular expression': '正则表达式',
  'More options': '更多选项',
  'Show icons': '显示图标',
  'Invalid pattern:': '无效的表达式：',
  'Pattern too slow': '表达式运行过慢',
  'matches, first': '个匹配，前',
  'shown': '个已显示',

  // ── Reader ──────────────────────────────────────────────────────────
  'Find in book…': '在书中查找…',
  'Close search': '关闭搜索',
  'Previous match': '上一个匹配',
  'Next match': '下一个匹配',
  'Search entire Tipiṭaka': '搜索整部三藏',
  'No content found.': '未找到内容。',
  'Error loading text:': '加载文本出错：',
  'Copy with Style': '带样式复制',
  'Select All': '全选',
  'Copy with Quote': '带引文复制',
  'Follow': '跟随',
  'TTS Controls': '朗读控制',
  'Follow TTS Position': '跟随朗读位置',
  'Add Bookmark': '添加书签',
  'Bookmark name': '书签名称',
  'Bookmark saved:': '书签已保存：',
  'Failed to save bookmark:': '保存书签失败：',
  'Connected Books': '关联书籍',
  'Jump to Page': '跳转到页码',
  'Page Numbering System': '页码系统',
  'Page Number': '页码',
  'e.g. 10 or 1.10': '例如 10 或 1.10',
  'Tip: If pages are numbered like "1.3", you can type just "3" to jump to page 1.3.':
      '提示：如果页码形如“1.3”，只需输入“3”即可跳转到第 1.3 页。',
  'not found in this book.': '在本书中未找到。',
  'No connected books found for this section.': '此部分没有关联书籍。',
  'Error loading connected books.': '加载关联书籍出错。',
  'Section': '章节',
  'Linked from': '链接来源：',
  'No content available.': '暂无内容。',
  'Could not load linked content.': '无法加载链接内容。',
  'Linked paragraph not found.': '未找到链接的段落。',
  'Open Library': '打开藏经库',
  'Close panel': '关闭面板',

  // ── Contents ────────────────────────────────────────────────────────
  'Contents': '目录',
  'Search contents…': '搜索目录…',
  'No matching sections': '没有匹配的章节',
  'No contents available': '暂无目录',

  // ── Outline ─────────────────────────────────────────────────────────
  'Outline': '大纲',
  'Every section with its study guide': '每个章节及其学习指南',
  'Open a book to see its outline': '打开一本书即可查看其大纲',
  'No sections found for this book': '本书未找到章节',
  'Tap a section to preview it, or read its study guide':
      '点按章节可预览，或阅读其学习指南',
  'section': '个章节',
  'sections': '个章节',
  'Text': '原文',
  'Study guide': '学习指南',
  'Loading study guide…': '正在加载学习指南…',
  'No study guide available for this section': '此章节暂无学习指南',

  // ── AI Assistant ────────────────────────────────────────────────────
  'Paññā': 'Paññā',
  'AI Research Assistant': 'AI 研究助手',
  '💬 Answer': '💬 解答',
  'Q&A': '问答',
  '📖 Literal Review': '📖 文献综述',
  'Deep research': '深度研究',
  'Ask a Question': '提问',
  'Literal Review': '文献综述',
  'Ask any question about the Tipitaka. The Assistant will search the Pāli Canon and provide a grounded answer with sources.':
      '您可以就三藏提出任何问题。助手会检索 Pāli 圣典，并给出有据可依、附带出处的回答。',
  'Enter a research topic to search the Tipitaka and receive a structured literal review with Pāli quotes and citations.':
      '输入研究主题，即可在三藏中检索，并获得结构清晰、附有 Pāli 原文引用和出处的文献综述。',
  'API key required': '需要 API 密钥',
  'Configure API Key': '配置 API 密钥',
  'Start a conversation': '开始对话',
  'Enter a research topic…': '输入研究主题…',
  'Ask a question about the Tipitaka…': '就三藏提问…',
  'AI Settings': 'AI 设置',
  'Sources': '出处',
  'cited': '条引用',
  'Failed to load text': '加载文本失败',
  'Line-by-line': '逐行对照',
  'Start asking': '开始提问',
  'Build': '构建',
  'Delete conversation?': '删除对话？',
  'Copied!': '已复制！',
  'Copy message': '复制消息',
  'Thinking...': '正在思考…',
  'Researching...': '正在研究…',
  'Generating answer...': '正在生成回答…',
  'Passage not found in the database': '数据库中未找到该段落',

  // ── AI Settings Sheet ───────────────────────────────────────────────
  'AI Assistant Settings': 'AI 助手设置',
  'API key is configured': 'API 密钥已配置',
  'API key required — enter your Gemini key below':
      '需要 API 密钥——请在下方输入您的 Gemini 密钥',
  'Gemini API Key': 'Gemini API 密钥',
  'AIza...': 'AIza...',
  'Get your free Gemini API key at makersuite.google.com':
      '前往 makersuite.google.com 免费获取 Gemini API 密钥',
  'Render Model (for generating answers)': '回答模型（用于生成回答）',
  'Used for the main answer generation. Needs strong reasoning.':
      '用于生成主要回答，需要较强的推理能力。',
  'Lite Model (for filtering & search)': '轻量模型（用于筛选与搜索）',
  'Fast model for re-ranking results and query expansion.':
      '用于结果重排序和查询扩展的快速模型。',
  'Save Settings': '保存设置',
  'AI settings saved': 'AI 设置已保存',
  'AI Q&A settings saved': 'AI 问答设置已保存',
  'Failed to save: ': '保存失败：',
  'Could not open the link': '无法打开链接',
  'Could not open: ': '无法打开：',
  'AI Provider': 'AI 服务商',
  'API Key': 'API 密钥',
  'Base URL': '基础网址',
  'Check key & load models': '验证密钥并加载模型',
  'Checking key & loading models...': '正在验证密钥并加载模型…',
  'Tool Model (for search & function calling)': '工具模型（用于搜索与函数调用）',
  'Answer Model (for final answer generation)': '回答模型（用于生成最终回答）',
  'Max chars per tool result': '每个工具结果的最大字符数',
  '0 = no truncation': '0 = 不截断',
  'Answer max output tokens': '回答的最大输出 token 数',
  'Max queries per chat': '每次对话的最大提问数',
  'Custom System Prompt (optional)': '自定义系统提示词（可选）',
  'Suggestion Index': '建议索引',
  'Rebuild Suggestion Index': '重建建议索引',
  'Get a free Gemini API key': '免费获取 Gemini API 密钥',
  'Gemini is free for everyone — just 4 easy steps:':
      'Gemini 对所有人免费——只需简单 4 步：',
  'Tap "Get free Gemini API key" below.': '点按下方的“获取免费 Gemini API 密钥”。',
  'Sign in with your Google account (free, no credit card).':
      '使用您的 Google 账号登录（免费，无需信用卡）。',
  'Tap "Create API key" and copy it (it starts with AIza).':
      '点按“创建 API 密钥”并复制（以 AIza 开头）。',
  'Paste it in the API Key field above — it is checked automatically.':
      '将其粘贴到上方的 API 密钥栏中——系统会自动验证。',
  'No credit card needed. The free tier includes generous daily limits for Gemini Flash models.':
      '无需信用卡。免费额度为 Gemini Flash 模型提供充裕的每日用量。',
  'Get a free OpenRouter API key': '免费获取 OpenRouter API 密钥',
  'OpenRouter is free to join — just 4 easy steps:':
      'OpenRouter 可免费加入——只需简单 4 步：',
  'Tap "Get free OpenRouter API key" below.':
      '点按下方的“获取免费 OpenRouter API 密钥”。',
  'Sign in with Google or GitHub (free, no credit card).':
      '使用 Google 或 GitHub 登录（免费，无需信用卡）。',
  'Tap "Create API key" and copy it (it starts with sk-or-).':
      '点按“创建 API 密钥”并复制（以 sk-or- 开头）。',
  'No credit card needed. Free models (marked :free) are selected automatically.':
      '无需信用卡。系统会自动选用免费模型（标有 :free）。',
  'API key required — get your free OpenRouter key below':
      '需要 API 密钥——请在下方获取免费的 OpenRouter 密钥',
  'API key rejected — see the error below': 'API 密钥被拒绝——请查看下方的错误信息',
  'Key entered — press Enter or "Check key" to verify':
      '已输入密钥——按 Enter 或点击“验证密钥”进行验证',
  'Checking API key...': '正在验证 API 密钥…',
  'API key valid': 'API 密钥有效',
  'API key required — enter your key below': '需要 API 密钥——请在下方输入您的密钥',
  'API key required — get your free Gemini key below':
      '需要 API 密钥——请在下方获取免费的 Gemini 密钥',
  'models available': '个可用模型',
  'Examples: https://openrouter.ai/api/v1, https://api.deepseek.com/v1':
      '示例：https://openrouter.ai/api/v1, https://api.deepseek.com/v1',
  'Fast/cheap model for tool orchestration (e.g. gemini-flash-lite-latest)':
      '用于工具调度的快速、低成本模型（例如 gemini-flash-lite-latest）',
  'Capable model for final answers (e.g. gemini-2.0-flash, gemini-2.5-flash)':
      '用于生成最终回答的高性能模型（例如 gemini-2.0-flash、gemini-2.5-flash）',
  'Max characters per tool result sent to the model. Set to 0 for no truncation (full content). Large values may increase API usage.':
      '发送给模型的每个工具结果的最大字符数。设为 0 表示不截断（发送完整内容）。数值过大可能增加 API 用量。',
  'Max output tokens for the answer model. Higher values allow longer answers. (Default: 64000)':
      '回答模型的最大输出 token 数。数值越大，回答可以越长。（默认：64000）',
  'Max user queries (messages) allowed per chat thread before starting a new one. (Default: 8, min: 1)':
      '每个对话线程在需要新建对话之前，允许的最大提问（消息）数。（默认：8，最小：1）',
  'Leave empty to use the default system prompt.\n\nCustomize how the AI behaves, what tools to use,\nand how to format answers.':
      '留空则使用默认系统提示词。\n\n您可以自定义 AI 的行为方式、\n使用的工具以及回答的格式。',
  'Reset the @ mention suggestion index to pick up any new or updated books/headings.':
      '重置 @ 提及建议索引，以获取新增或更新的书籍/标题。',
  'Attached headings': '已附加的标题',
  'Clear all': '全部清除',

  // ── Gavesana Screen ─────────────────────────────────────────────────
  'Ask about the Tipitaka…': '就三藏提问…',

  'Search semantically across the Tipitaka': '在三藏中进行语义搜索',
  "Gavesana uses AI to find passages related to your\nquery, even if they don't share exact words.":
      'Gavesana 使用 AI 查找与您的查询相关的段落，\n即使这些段落并不包含完全相同的词语。',

  'Semantic search': '语义搜索',
  'Investigation & exploration': '探究与探索',
  'Tipiṭaka': 'Tipiṭaka（三藏）',
  'Feedback': '反馈',
  'Pāli Tipiṭaka Reader': 'Pāli 三藏阅读器',
  'Vīmaṃsā': 'Vīmaṃsā',

  // ── Gavesana FTS Build Dialog ───────────────────────────────────────

  // ── Indexing ────────────────────────────────────────────────────────
  'Available Translations': '可用译文',
  'No translations available.\nPlease download a translation first.':
      '暂无可用译文。\n请先下载一个译文。',
  'Build Index': '构建索引',
  'Select a Translation': '选择一个译文',
  'Build Failed': '构建失败',
  'Index Built!': '索引构建完成！',
  'Index Built': '索引已构建',
  'Preparing…': '正在准备…',
  'Installing…': '正在安装…',
  'Ready to index': '可以开始建立索引',
  'Download cancelled': '下载已取消',
  'Download failed': '下载失败',
  'Checking search index…': '正在检查搜索索引…',
  'Welcome to ePitaka': '欢迎使用 ePitaka',
  'To enable full-text search, we need to build a search index for the Pāli texts and translations.':
      '为了启用全文搜索，需要为 Pāli 原文和译文建立搜索索引。',
  'The indexing only needs to happen once.\nYou can rebuild later from Settings.':
      '索引只需建立一次。\n之后您可以在“设置”中重建。',
  'No translations available for download.': '暂无可下载的译文。',
  'Download a translation to get started:': '请下载一个译文以开始使用：',
  'Choose a translation to index:': '请选择要建立索引的译文：',
  'Build Index (Pāli)': '构建索引（Pāli）',
  'Something went wrong': '出了点问题',
  'Unknown error': '未知错误',
  'Download the required databases to get started.': '请下载必需的数据库以开始使用。',
  'You can add more translations later.': '您以后还可以添加更多译文。',
  'Required Databases': '必需的数据库',
  'These are needed for the app to function.': '应用运行需要这些数据库。',
  'Required Translations': '必需的译文',
  'An English translation is needed for AI search features.':
      'AI 搜索功能需要一个英文译本。',
  'Optional Translations': '可选译文',
  'Text Colors': '文字颜色',
  'Pick Pāli Text Color': '选择 Pāli 原文颜色',
  'Pick Translation Text Color': '选择译文颜色',
  'Download required items first': '请先下载必需项目',
  'Loading available translations…': '正在加载可用译文…',
  'Building Heading Index…': '正在构建标题索引…',
  'This will delete and rebuild the full-text search index from scratch. '
          'It may take a few seconds on slower devices. '
          'You can continue using the app while indexing runs in the background.':
      '这将删除并从头重建全文搜索索引。'
      '在较慢的设备上可能需要几秒钟。'
      '索引在后台运行时，您可以继续使用应用。',
  'This will clear the current search index and rebuild it from '
          'scratch. Previously indexed data will be lost until the rebuild '
          'completes.':
      '这将清除当前的搜索索引并从头重建。'
      '在重建完成之前，之前已建立的索引数据将不可用。',

  // ── Index Build Dialog ──────────────────────────────────────────────
  'Build Search Index': '构建搜索索引',
  'Choose a translation to include in the search index.':
      '请选择要纳入搜索索引的译文。',
  'Rebuild Search Index?': '重建搜索索引？',
  'Resetting & Rebuilding': '正在重置并重建',
  'Rebuilding Index': '正在重建索引',
  'Reset & Rebuild': '重置并重建',
  'Reset & Rebuild?': '重置并重建？',
  'Clear bookmarks, history & rebuild search index':
      '清除书签、历史记录并重建搜索索引',
  'This will permanently delete all bookmarks and reading history, then rebuild the search index from scratch.':
      '这将永久删除所有书签和阅读历史，然后从头重建搜索索引。',
  'Database location:': '数据库位置：',
  'Tip: Export your bookmarks and reading history as a JSON file before resetting. Online backup will be supported in a future update.':
      '提示：重置之前，请先将书签和阅读历史导出为 JSON 文件。在线备份将在后续更新中提供。',
  'Export Backups': '导出备份',
  'Reset Now': '立即重置',
  'Backup saved to: ': '备份已保存到：',
  'Failed to export data: ': '导出数据失败：',
  'Database folder': '数据库文件夹',
  'Open folder': '打开文件夹',
  'Copy path': '复制路径',
  'Path copied to clipboard': '路径已复制到剪贴板',
  'Could not open folder: ': '无法打开文件夹：',
  'Loading databases…': '正在加载数据库…',
  'No databases found.': '未找到数据库。',

  // ── Feedback ────────────────────────────────────────────────────────
  'Send Feedback': '发送反馈',

  // ── Page systems ────────────────────────────────────────────────────
  'Thai': '泰国版',
  'Myanmar': '缅甸版',

  // ── Mention overlay ─────────────────────────────────────────────────
  'Attach: ': '附加：',
  'Type a sutta or heading name': '输入经名或标题',
  'Start typing a sutta or heading name': '开始输入经名或标题',
  'Tip: Try @cankisutta, @dn1, or a heading title':
      '提示：可以试试 @cankisutta、@dn1 或某个标题',
  'Select': '选择',
  'Navigate': '导航',
  'Esc': 'Esc',
  'Rebuild suggestion index': '重建建议索引',

  // ── Search panel / search screen ───────────────────────────────────
  'Search Pāli…': '搜索 Pāli…',
  'Toggle filters': '切换筛选',
  'Layer': '层次',
  'Nikāya': 'Nikāya（部）',
  'No matches for': '没有匹配：',
  'No matches found for': '未找到匹配：',
  'Did you mean…': '您是不是想找…',
  'No results': '没有结果',
  'Font size': '字号',
  'words': '个词',
  'Show': '显示',
  'more': '更多',
  'result': '条结果',
  'Recent searches': '最近搜索',
  'Clear history': '清除历史记录',

  // ── Dictionary panel / sheet ────────────────────────────────────────
  'DPD Dictionary': 'DPD 词典',
  'Compound breakdown': '复合词拆分',
  'Pin to side panel': '固定到侧边栏',
  'Unpin from side panel': '从侧边栏取消固定',

  // ── Reader toolbar / paragraphs ─────────────────────────────────────
  'Jump': '跳转',
  'Hide': '隐藏',
  'Line/L': '行/L',
  'Side/S': '并排/S',
  'Stop': '停止',
  'Play': '播放',
  'Pause': '暂停',
  'Previous paragraph': '上一段',
  'Next paragraph': '下一段',
  'Less': '收起',
  'Library': '藏经库',
  'Reset layout': '重置版式',

  // ── Gavesana ────────────────────────────────────────────────────────
  'Gavesanā': 'Gavesanā',
  'Gavesanā AI Search': 'Gavesanā AI 搜索',
  'AI-powered semantic search across the Tipiṭaka.\n\nOpen the full Gavesanā panel for detailed results.':
      '基于 AI 的三藏语义搜索。\n\n打开完整的 Gavesanā 面板可查看详细结果。',

  // ── AI Q&A (Vīmaṃsā) ────────────────────────────────────────────────
  'Navigation menu': '导航菜单',
  'Chat history': '对话历史',
  'New chat': '新对话',
  'Clear chat': '清空对话',
  'Vīmaṃsā Settings': 'Vīmaṃsā 设置',
  'Building heading index…': '正在构建标题索引…',
  'Heading index needed for @ — build now?': '使用 @ 需要标题索引——现在构建吗？',
  'Ask about the Tipitaka': '就三藏提问',
  'Vīmaṃsā — investigation through questioning.\n'
          'The AI searches the Tipiṭaka using tools, gathers relevant passages,\n'
          'and provides detailed answers with clickable citations.\n'
          'Each chat thread is saved — you can continue later.':
      'Vīmaṃsā——以提问进行探究。\n'
      'AI 借助工具检索三藏，汇集相关段落，\n'
      '并给出附有可点击引文的详细回答。\n'
      '每个对话线程都会保存，您可以随时继续。',
  'View past conversations': '查看过往对话',
  'Orthodox': '正统',
  'Answers use only the passages found in the Tipitaka.':
      '回答仅使用在三藏中找到的段落。',
  'The AI may also use its own knowledge alongside the found passages.':
      'AI 也可能在所找到的段落之外，结合自身的知识作答。',
  'Type @ to attach a heading': '输入 @ 以附加标题',
  'Thread is full — start a new chat': '此对话已满——请开始新对话',
  'Ask about the Tipitaka, or type @ to attach a heading…':
      '就三藏提问，或输入 @ 以附加标题…',
  'Chat History': '对话历史',
  'New Chat': '新对话',
  'No conversations yet': '暂无对话',
  'Start a new chat to begin': '开始一个新对话吧',
  'and all its messages?': '及其所有消息？',
  'query': '次提问',
  'queries': '次提问',
  'remaining in this thread': '在此对话中剩余',
  'Translation': '译文',

  // ── Context Menu ────────────────────────────────────────────────────
  'Context Menu': '选区菜单',
  'Customize the selection toolbar': '自定义选区工具栏',
  'Customize the actions shown when you select text in the reader. Drag to reorder, toggle to hide, and add apps or AI prompts.':
      '自定义在阅读器中选择文字时显示的操作。可拖动调整顺序、开关切换显示，并添加应用或 AI 提示词。',
  'Add Prompt': '添加提示词',
  'Add App': '添加应用',
  'Prompt Name': '提示词名称',
  'Prompt': '提示词',
  'Use {selectedText} as a placeholder for the selected text.':
      '使用 {selectedText} 作为所选文字的占位符。',
  'Edit Prompt': '编辑提示词',
  'Installed Apps': '已安装的应用',
  'No compatible apps found on this device.': '此设备上未找到兼容的应用。',
  'Install a dictionary or translator app that supports text sharing, then tap Add App again.':
      '请安装支持文本分享的词典或翻译应用，然后再次点按“添加应用”。',
  'No context menu actions yet. Add apps or prompts below.':
      '暂无选区菜单操作。请在下方添加应用或提示词。',
  'External app': '外部应用',
  'Copy': '复制',
  'Copy the selected text': '复制所选文字',
  'Excerpt': '摘录',
  'Copy with citation': '连同引文一起复制',
  'Copy Link': '复制链接',
  'Copy a link to this passage': '复制指向此段落的链接',
  'Explain': '解释',
  'Explain the selected text with AI': '用 AI 解释所选文字',
  'Summarize Ch.': '总结本章',
  'Summarize the current chapter with AI': '用 AI 总结当前章节',
  'Share': '分享',
  'Share the selected text': '分享所选文字',
  'Look up the selected word': '查询所选词语',
  'Look Up': '查询',
  'Look up in device dictionary (iOS/macOS)': '在设备词典中查询（iOS/macOS）',
  'Speak the selected text (iOS/macOS)': '朗读所选文字（iOS/macOS）',
  'Reset to default': '恢复默认',
  'Reset context menu actions and order to default?':
      '将选区菜单的操作和顺序恢复为默认设置？',
  'Speak from here': '从此处开始朗读',
  'Start TTS from the selected line': '从所选行开始语音朗读',

  // ── Toolbar (reader bottom toolbar) ────────────────────────────────
  'Toolbar': '工具栏',
  'Customize the reader toolbar': '自定义阅读器工具栏',
  'Choose which actions appear in the reader toolbar and their order. Drag to reorder, toggle to hide.':
      '选择阅读器工具栏中显示哪些操作及其顺序。可拖动调整顺序，开关切换显示。',
  'Contents, Outline, Search, Dictionary and Annotations appear on the mobile toolbar only.':
      '目录、大纲、搜索、词典和批注仅出现在移动端工具栏中。',
  'Display layout': '显示版式',
  'Bookmark': '书签',
  'Reset toolbar items and order to default?': '将工具栏项目和顺序恢复为默认设置？',

  // ── Feature Guide ──────────────────────────────────────────────────
  'Feature Guide': '功能指南',
  'Learn what ePitaka can do': '了解 ePitaka 能做什么',
  'Step-by-step instructions for the reader toolbar, text selection, settings and the AI assistant.':
      '关于阅读器工具栏、文字选择、设置和 AI 助手的分步说明。',
  'Take a quick tour of the main features — you can reopen this guide anytime from the menu.':
      '快速浏览主要功能——您随时可以从菜单中重新打开此指南。',
  'Explore features': '探索功能',
  'Got it': '知道了',
  'While you wait…': '等待期间…',
  'While you wait, here is a quick tour of what you can do with ePitaka.':
      '趁着等待的时间，来快速了解一下 ePitaka 的功能吧。',

  // ── Feature Guide: Reader Toolbar ─────────────────────────────────
  'Reader Toolbar': '阅读器工具栏',
  'The floating toolbar at the bottom of the reader puts every action one tap away.':
      '阅读器底部的悬浮工具栏让每个操作都只需轻点一下。',
  'Contents — jump between sections from the table of contents.':
      '目录——通过目录在各章节之间跳转。',
  'Search — find a word or phrase inside the current book.':
      '搜索——在当前书籍中查找词语或短语。',
  'Dictionary — look up any Pāli word instantly.': '词典——即时查询任意 Pāli 词汇。',
  'Jump — go to a page number or a connected book.': '跳转——前往某个页码或关联书籍。',
  'Display layout — switch between hide-translation, line-by-line and side-by-side views.':
      '显示版式——在隐藏译文、逐行对照和左右对照视图之间切换。',
  'Listen — read the passage aloud with text-to-speech; tap again to stop.':
      '收听——用文字转语音朗读段落；再次点按即可停止。',
  'Bookmark — save your place and return to it later from the Library.':
      '书签——保存阅读位置，之后可从藏经库返回。',

  // ── Feature Guide: Context Menu ───────────────────────────────────
  'Select any text in the reader and a toolbar of smart actions appears above it.':
      '在阅读器中选择任意文字，其上方会出现一栏智能操作工具栏。',
  'Select text — tap and drag, or double-tap a word.':
      '选择文字——点按并拖动，或双击某个词。',
  'Copy — copy the selection as plain text.': '复制——将所选内容复制为纯文本。',
  'Excerpt — copy with a formatted citation.': '摘录——连同格式化引文一起复制。',
  'Copy Link — copy a shareable link to this exact passage.':
      '复制链接——复制指向该段落的可分享链接。',
  'Dictionary — look up the selected word.': '词典——查询所选词语。',
  'Explain — ask Vīmaṃsā AI to explain the selection.':
      '解释——请 Vīmaṃsā AI 解释所选内容。',
  'Summarize Ch. — summarize the current chapter with AI.':
      '总结本章——用 AI 总结当前章节。',
  'Share — share the selection via the system share sheet.':
      '分享——通过系统分享面板分享所选内容。',
  'Customize — Settings → Context Menu lets you reorder, hide, or add apps and AI prompts.':
      '自定义——在“设置 → 选区菜单”中可以调整顺序、隐藏，或添加应用和 AI 提示词。',

  // ── Feature Guide: Settings ───────────────────────────────────────
  'Everything you need to personalize ePitaka.': '个性化 ePitaka 所需的一切设置。',
  'Language & script — choose the UI language and the Pāli script (Roman, Devanagari, Sinhala, Myanmar, Thai…).':
      '语言与文字——选择界面语言和 Pāli 文字（罗马字、天城文、僧伽罗文、缅文、泰文…）。',
  'Appearance — themes, accent color and reading colors.':
      '外观——主题、强调色和阅读颜色。',
  'Translations & Downloads — download, update and reorder translation databases.':
      '译文与下载——下载、更新译文数据库并调整其顺序。',
  'Reading Options — layout, page numbering, quote format and auto-scroll.':
      '阅读选项——版式、页码、引文格式和自动滚动。',
  'Text-to-Speech — voice, speed, pitch and word replacements.':
      '文字转语音——语音、语速、音调和词语替换。',
  'Dictionaries — enable, disable and reorder dictionaries.':
      '词典——启用、停用并调整词典顺序。',
  'AI Q&A — enter your API key and pick models for Vīmaṃsā.':
      'AI 问答——输入 API 密钥，并为 Vīmaṃsā 选择模型。',

  // ── Feature Guide: AI (Vīmaṃsā) ───────────────────────────────────
  'AI — Vīmaṃsā': 'AI — Vīmaṃsā',
  'Ask the AI about the Tipiṭaka. It searches the Canon and answers with citations.':
      '就三藏向 AI 提问。AI 会检索圣典，并附上引文作答。',
  'Ask a question — open Vīmaṃsā from the menu and ask anything.':
      '提问——从菜单打开 Vīmaṃsā，随意提问。',
  'Explain — select text in the reader and tap Explain for a commentary-grounded explanation.':
      '解释——在阅读器中选择文字并点按“解释”，即可获得以注释为依据的讲解。',
  'Summarize — tap Summarize Ch. to get an overview of the current chapter.':
      '总结——点按“总结本章”，即可获得当前章节的概述。',
  'Attach a passage — type @ to attach a sutta or heading to your question.':
      '附加段落——输入 @，将某部经或某个标题附加到您的提问中。',
  'Chat history — your conversations are saved; continue them anytime.':
      '对话历史——您的对话会被保存，可随时继续。',
  'Custom prompts — add your own AI prompts in Settings → Context Menu; use {selectedText} as a placeholder.':
      '自定义提示词——在“设置 → 选区菜单”中添加您自己的 AI 提示词；使用 {selectedText} 作为占位符。',

  // ── App shell ───────────────────────────────────────────────────────
  'Listen': '收听',

  // ── AI error card ───────────────────────────────────────────────────
  'Search Google': '用 Google 搜索',
  'Show full error': '显示完整错误信息',
  'Hide full error': '隐藏完整错误信息',

  // ── Go to sutta ─────────────────────────────────────────────────────
  'Go to sutta': '前往经文',
  'Type a sutta code or name, e.g. mn10': '输入经文编号或名称，例如 mn10',
  'No sutta found for ': '未找到经文：',
  'Could not look up sutta codes. The error is in the log.':
      '无法查询经文编号。错误详情见日志。',
};