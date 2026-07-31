/// Riverpod provider managing the Vimaṃsa chat state with the tool-based
/// function calling pipeline and persistent chat threads.
///
/// Architecture (two-model pipeline):
///
///   Step 1 — Tool model (fast/cheap, e.g. gemini-2.0-flash-lite)
///     The user's question is sent to a small model with **function
///     declarations** (tools). The model decides which tool(s) to call,
///     with what arguments. Each tool response is fed back, allowing
///     multi-step reasoning (e.g. search → get headings → get content).
///
///   Step 2 — Answer model (capable, e.g. gemini-2.0-flash)
///     Once all tool results are collected, the conversation history +
///     tool results are sent to a more capable model for a final,
///     well-structured answer with clickable citations.
///
/// Threads:
///   - Each conversation is a ChatThread, persisted to AppDatabase.
///   - Messages (user + assistant) are saved to DB as they complete.
///   - Each thread has a max_messages cap (from settings).
///   - Users can load old threads and continue chatting.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/app_db_provider.dart';
import '../../shared/models/ai_provider.dart';
import '../models/ai_qa_models.dart';
import '../models/heading_attachment.dart';
import '../services/ai_qa_tool_service.dart';
import 'ai_qa_settings_provider.dart';
import 'chat_history_provider.dart';

const _uuid = Uuid();

/// Helper to hold a pending tool call before parallel execution.
class _ToolCallSpec {
  final String name;
  final Map<String, dynamic> args;
  const _ToolCallSpec({required this.name, required this.args});
}

/// Staged initial prompt to auto-send when the Vimaṃsa screen opens.
/// Set by the reader's context menu (Explain / Summarize Chapter) before
/// navigating to the Vimaṃsa screen. The screen reads and clears it on init.
final aiQaInitialPromptProvider = StateProvider<String?>((ref) => null);

/// Separate providers for streaming text — kept outside [AiQaState] so
/// updating them on each token does NOT rebuild the entire screen.
final streamingTextProvider = StateProvider<String>((ref) => '');

/// Tracks which message ID is currently being streamed into.
final streamingMessageIdProvider = StateProvider<String?>((ref) => null);

/// Current active thread ID (null if no thread is active).
final currentThreadIdProvider = StateProvider<String?>((ref) => null);

/// Current thread title.
final currentThreadTitleProvider = StateProvider<String>((ref) => '');

/// StateNotifier managing the Vimaṃsa chat.
class AiQaNotifier extends StateNotifier<AiQaState> {
  final Ref _ref;

  AiQaNotifier(this._ref) : super(const AiQaState());

  StreamSubscription<String>? _streamSubscription;
  String? _currentStreamingMessageId;
  bool _finalized = false;

  /// DB ID of the last assistant message (for stream finalization updates).
  int? _dbMessageId;

  /// Gemini default base URL.
  String get _geminiBaseUrl =>
      'https://generativelanguage.googleapis.com/v1beta/models';

  static const _encoder = JsonEncoder.withIndent('  ');

  static const int _maxRetries = 2;
  static const int _maxToolIterations = 8;

  // ── Tool definitions (Gemini function declarations) ───────────────────

  static List<Map<String, dynamic>> get _toolDeclarations => [
    {
      'name': 'search_tipitaka',
      'description':
          'Search the Tipitaka database for relevant passages using full-text search. '
          'Use this when you need to find passages related to a specific topic, term, '
          'or concept in the Pāli Canon.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'query': {
            'type': 'STRING',
            'description':
                'Search query — a phrase or keywords to search for in the Pāli text.',
          },
        },
        'required': ['query'],
      },
    },
    {
      'name': 'search_tipitaka_batch',
      'description':
          'Search the Tipitaka using MULTIPLE different search terms in one call. '
          'Use this to search for a concept using several synonyms or related terms '
          'simultaneously. All queries are executed in parallel for speed.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'queries': {
            'type': 'ARRAY',
            'description':
                'Array of search queries to run in parallel. '
                'Include different phrasings, synonyms, and related terms '
                'to maximize coverage.',
            'items': {'type': 'STRING'},
            'minItems': 2,
            'maxItems': 5,
          },
        },
        'required': ['queries'],
      },
    },
    {
      'name': 'search_by_category',
      'description':
          'Search the Tipitaka within specific book categories or nikayas. '
          'Use this when you know which part of the canon the answer is likely in. '
          'Categories: "vinaya", "sutta", "abhidhamma". '
          'Nikaya prefixes: "dn", "mn", "sn", "an", "khp", "dhp", "ud", "it", "snp", '
          '"vv", "pv", "thag", "thig", "ja", "bi", "patis", "nm", "ne", "pk". '
          'Combine with queries to find specific passages within those books.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'queries': {
            'type': 'ARRAY',
            'description':
                'Array of search queries. Include 2-3 specific terms '
                '(Pāli keywords, English phrases) to find within the target books.',
            'items': {'type': 'STRING'},
            'minItems': 2,
            'maxItems': 5,
          },
          'categories': {
            'type': 'ARRAY',
            'description':
                'Book categories to search within. '
                'Choose from: "vinaya", "sutta", or "abhidhamma". '
                'Can be combined with nikayas. Leave empty to search all categories.',
            'items': {'type': 'STRING'},
          },
          'nikayas': {
            'type': 'ARRAY',
            'description':
                'Nikāya book prefixes to narrow the search further. '
                'E.g. ["dn"] for Dīgha Nikāya, ["an"] for Aṅguttara Nikāya, '
                '["dhp"] for Dhammapada. Can be combined with categories.',
            'items': {'type': 'STRING'},
          },
        },
        'required': ['queries', 'categories'],
      },
    },
    {
      'name': 'get_headings',
      'description':
          'Get the table of contents / section headings for a specific book. '
          'Use this to understand the structure of a book, find specific sections, '
          'or navigate to a particular topic within a book.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'book_id': {
            'type': 'STRING',
            'description':
                'Book ID (e.g. "dn1", "mn141", "sn12.2", "an3.1", "dhp").',
          },
        },
        'required': ['book_id'],
      },
    },
    {
      'name': 'get_books',
      'description':
          'Get a list of all available books in the Tipitaka database. '
          'Use this when you need to know which books are available, their categories, '
          'or to find the correct book_id for a specific text.',
      'parameters': {'type': 'OBJECT', 'properties': {}},
    },
    {
      'name': 'get_paragraph_content',
      'description':
          'Get the full Pāli content of a range of paragraphs from a specific book. '
          'Use this to read the actual text of a passage after you have identified '
          'the relevant book and paragraph range (e.g. from search results or headings).',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'book_id': {
            'type': 'STRING',
            'description': 'Book ID (e.g. "dn1", "mn141").',
          },
          'para_start': {
            'type': 'INTEGER',
            'description': 'Starting paragraph number (inclusive).',
          },
          'para_end': {
            'type': 'INTEGER',
            'description':
                'Ending paragraph number (inclusive). Can be the same as para_start for a single paragraph.',
          },
        },
        'required': ['book_id', 'para_start', 'para_end'],
      },
    },
    {
      'name': 'get_paragraph_content_batch',
      'description':
          'Get Pāli content from MULTIPLE book/paragraph ranges in ONE call. '
          'Use this to read several passages at once after you have identified '
          'the relevant locations (e.g. from search results or headings). '
          'All ranges are fetched in parallel for speed.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'ranges': {
            'type': 'ARRAY',
            'description':
                'Array of paragraph ranges to fetch. Each range is an object '
                'with book_id, para_start, para_end.',
            'items': {
              'type': 'OBJECT',
              'properties': {
                'book_id': {
                  'type': 'STRING',
                  'description': 'Book ID (e.g. "dn1", "mn141").',
                },
                'para_start': {
                  'type': 'INTEGER',
                  'description': 'Starting paragraph number (inclusive).',
                },
                'para_end': {
                  'type': 'INTEGER',
                  'description': 'Ending paragraph number (inclusive).',
                },
              },
              'required': ['book_id', 'para_start', 'para_end'],
            },
            'minItems': 2,
            'maxItems': 10,
          },
        },
        'required': ['ranges'],
      },
    },
    {
      'name': 'get_commentaries',
      'description':
          'Get related commentary (Aṭṭhakathā) and sub-commentary (Ṭīkā) passages '
          'for a given Mūla (root text) paragraph. Use this when a user asks about '
          'commentarial explanations of a specific passage in the Tipitaka.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'mula_book_id': {
            'type': 'STRING',
            'description':
                'Book ID of the Mūla (root) text (e.g. "dn1", "mn141").',
          },
          'mula_para_id': {
            'type': 'INTEGER',
            'description':
                'Paragraph number in the Mūla text to find commentaries for.',
          },
        },
        'required': ['mula_book_id', 'mula_para_id'],
      },
    },
    {
      'name': 'final_answer',
      'description':
          'Call this when you have collected all the information needed to answer the user\'s question. '
          'The results will be passed to a more capable model to write the final answer. '
          'Use the args to summarize what you found.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'summary': {
            'type': 'STRING',
            'description':
                'Brief summary of what you found and what sources you collected.',
          },
        },
        'required': ['summary'],
      },
    },
  ];

  // ── Debug log ──────────────────────────────────────────────────────────

  /// Debug log data collected during the current pipeline run.
  Map<String, dynamic> _debugLog = {};

  /// Save the full AI pipeline trace to a debug file.
  /// Overwritten each time; open with any text editor to inspect.
  Future<void> _saveDebugLog() async {
    if (_debugLog.isEmpty) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = p.join(dir.path, 'vimamsa_debug.json');
      final file = File(filePath);
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(_debugLog));
      debugPrint('[VIMAṂSA] Debug log saved to: $filePath');
    } catch (e) {
      debugPrint('[VIMAṂSA] Failed to save debug log: $e');
    }
    _debugLog = {};
  }

  // ── Default system prompts ────────────────────────────────────────────

  static const String _defaultToolSystemPrompt =
      '''You are an expert research assistant for the Pāli Canon (Tipitaka).

## Available tools
1. **search_tipitaka(query)** — Full-text search across the Tipitaka.
2. **search_tipitaka_batch(queries: [...])** — Search with MULTIPLE different terms in ONE call (parallel).
3. **search_by_category(queries, categories, [nikayas])** — Search WITHIN specific book categories ("vinaya"/"sutta"/"abhidhamma") or nikāyas ("dn"/"mn"/"sn"/"an"/"dhp"/"ja"/etc). Results are filtered to only those books.
4. **get_headings(book_id)** — Get table of contents for a book.
5. **get_books()** — List all available books with their categories.
6. **get_paragraph_content(book_id, para_start, para_end)** — Read Pāli text.
7. **get_paragraph_content_batch(ranges: [...])** — Read MULTIPLE ranges in parallel.
8. **get_commentaries(mula_book_id, mula_para_id)** — Find Aṭṭhakathā/Ṭīkā.

## CRITICAL: Strategic search process
You have up to 8 tool iterations. Use them WISELY. Follow this process:

### PHASE 1: Analyze the question (thinking, no tools yet)
Before searching, analyze:
- What is the UNIQUE core of this question? What makes it specific?
- Which part of the canon would contain the answer? (Vinaya for rules, Suttas for teachings, Jātakas for stories, etc.)
- What Pāli compounds or technical terms might capture the SPECIFIC concept?

### PHASE 2: Strategic search (use search_by_category FIRST)
- If you know WHERE the answer lives, use **search_by_category** to search only relevant books.
  Example: rules about monks → categories: ["vinaya"]
  Example: teachings on giving → nikayas: ["an"] (Aṅguttara has many dāna teachings)
  Example: stories → nikayas: ["ja"] (Jātaka)
- ALWAYS include SPECIFIC queries that target the unique aspect, not just generic keywords.
  BAD: ["dāna", "giving"] (returns 1000+ results, all generic)
  GOOD: ["dukkara dāna", "most difficult gift", "kicchena dāna", "supreme offering monk"]
- Use 3-4 queries at different specificity levels:
  1. Very specific (Pāli compound from the question's core concept)
  2. Phrase search (English description of the unique situation)
  3. Synonyms (related concepts)
  4. Broad fallback (if specific yields nothing)

### PHASE 3: Evaluate result quality
After each search batch, evaluate:
- How many results? 0-3 = too few (search again with broader terms)
- Are they actually about the user's question, or just tangentially related?
- If 30+ results and many are generic → search was too broad. Narrow down with search_by_category or more specific terms.
- If results are from wrong books → use search_by_category to correct.

### PHASE 4: Iterate until confident
- If results are insufficient → refine and search AGAIN (you have iterations)
- After finding relevant passages, read them with get_paragraph_content to confirm they answer the question.
- Use get_headings to understand the structure of a promising book before diving in.
- Only call final_answer when you have found passages that DIRECTLY address the user's question.

## Guidelines
- When searching, use search_tipitaka_batch or search_by_category (not single search).
- Pāli terms: try compounds (e.g. "sammāsambuddha" not just "buddha").
- If search_by_category returns nothing, fall back to search_tipitaka_batch across all books.
- For commentaries, use get_commentaries with the specific passage.
- Include precise citations [book_id:para_id:line_id] for every quoted passage.''';

  /// Build the answer-model system prompt, adapting the grounding rules to
  /// the selected answer mode.
  ///
  /// Orthodox mode (default): the answer may use ONLY the passages found by
  /// the tools.  Knowledge mode: the AI may supplement the found passages
  /// with its own knowledge of the Pāli Canon.
  static String _buildAnswerSystemPrompt({required bool orthodoxMode}) {
    final grounding = orthodoxMode
        ? '''## Strict rules
1. Every factual claim MUST be backed by an inline citation like [book_id:para_id:line_id].
2. Answer the user's question using ONLY the passages provided in the tool results. Never use outside knowledge.
3. Quote Pāli EXACTLY as given — never paraphrase Pāli words.
4. After each Pāli quote, provide the English meaning.
5. If the provided passages are insufficient, say so honestly rather than speculating.
6. Explain Pāli technical terms briefly on first use.
7. Use Markdown for structure (## headings, **bold**, *italic*, > blockquotes).
8. [book_id:para_id:line_id] citations will be rendered as interactive buttons — the user can click them to open the passage in the reader. Ensure every citation includes all three components.'''
        : '''## Strict rules
1. Every factual claim drawn from the sources MUST be backed by an inline citation like [book_id:para_id:line_id].
2. Answer the user's question using the passages provided in the tool results as your primary source.
3. You MAY supplement with your own knowledge of the Pāli Canon and Theravāda Buddhism when the sources are insufficient — but clearly distinguish what comes from the sources from your own explanation.
4. Quote Pāli EXACTLY as given — never paraphrase Pāli words.
5. After each Pāli quote, provide the English meaning.
6. Explain Pāli technical terms briefly on first use.
7. Use Markdown for structure (## headings, **bold**, *italic*, > blockquotes).
8. [book_id:para_id:line_id] citations will be rendered as interactive buttons — the user can click them to open the passage in the reader. Ensure every citation includes all three components.''';
    return '''You are a knowledgeable scholar of the Pāli Canon and Theravāda Buddhism. You have been provided with tool results from the database containing specific passages from the Tipitaka and/or commentaries.

## Your task
Write a clear, well-structured answer to the user's original question.

## Citation format
Every citation MUST be formatted as a **quote button** that users can click:
  `[book_id:para_id:line_id]`

For example:
  > "Yato kho bhikkhave ariyasāvako evaṃ kusalañca abhijānāti ..." [dn1:100:1]

The citation format [book_id:para_id:line_id] will be rendered as an interactive button in the UI that opens the passage when clicked.

$grounding''';
  }

  // ── Thread management ─────────────────────────────────────────────────

  /// Create a new thread and set it as active.
  Future<void> startNewThread({String? title}) async {
    // Cancel any ongoing stream
    await _streamSubscription?.cancel();
    _finalized = false;

    final threadId = _uuid.v4();
    final threadTitle = title ?? 'Vimaṃsa';

    final notifier = _ref.read(chatHistoryNotifierProvider);
    final thread = await notifier.createThread(
      id: threadId,
      title: threadTitle,
      maxMessages: _ref.read(aiQaSettingsProvider).maxQueriesPerChat,
    );

    _ref.read(currentThreadIdProvider.notifier).state = thread.id;
    _ref.read(currentThreadTitleProvider.notifier).state = thread.title;
    state = const AiQaState();
  }

  /// Load an existing thread's messages into the chat state.
  Future<void> loadThread(String threadId) async {
    await _streamSubscription?.cancel();
    _finalized = false;

    final notifier = _ref.read(chatHistoryNotifierProvider);
    final thread = await notifier.getThread(threadId);
    if (thread == null) return;

    final db = await _ref.read(appDbProvider.future);
    final records = await db.getChatMessages(threadId);

    // Convert DB records to AiQaMessage list
    final messages = <AiQaMessage>[];
    for (final record in records) {
      Map<String, dynamic>? metadata;
      if (record.metadata != null && record.metadata!.isNotEmpty) {
        try {
          metadata = jsonDecode(record.metadata!) as Map<String, dynamic>;
        } catch (_) {}
      }

      final citations =
          (metadata?['citations'] as List<dynamic>?)
              ?.map((c) => SourceCitation.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [];

      final toolCalls =
          (metadata?['toolCalls'] as List<dynamic>?)
              ?.map((t) => ToolCallLog.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [];

      messages.add(
        AiQaMessage(
          id: 'db_${record.id}',
          text: record.content,
          isUser: record.role == 'user',
          timestamp: record.createdAt,
          citations: record.role == 'assistant' ? citations : [],
          toolCalls: toolCalls,
        ),
      );
    }

    _ref.read(currentThreadIdProvider.notifier).state = thread.id;
    _ref.read(currentThreadTitleProvider.notifier).state = thread.title;
    state = state.copyWith(messages: messages);
  }

  // ── Main send method ──────────────────────────────────────────────────

  /// Send a user message with attached heading references.
  ///
  /// The attachment context is injected as a system message before the
  /// user's question, giving the AI model awareness of which Tipitaka
  /// sections the user has explicitly referenced.
  Future<void> sendMessageWithAttachments(
    String text,
    List<HeadingAttachment> attachments,
  ) async {
    if (attachments.isEmpty) {
      return sendMessage(text);
    }

    // Build attachment context block
    final buffer = StringBuffer();
    buffer.writeln(
      'The user has attached the following Tipitaka headings as context for their question:',
    );
    buffer.writeln();
    for (final attachment in attachments) {
      buffer.writeln(attachment.contextBlock);
    }
    buffer.writeln();
    buffer.writeln(
      'When answering, you should read the content of these sections using the get_paragraph_content '
      'tool if the attached heading is relevant to the question. '
      'The attachments are:',
    );
    final attachmentContext = buffer.toString();

    await sendMessage(text, attachmentContext: attachmentContext);
  }

  /// Send a user message and run the tool-based Q&A pipeline.
  /// Auto-creates a new thread if none is active.
  ///
  /// If [attachmentContext] is provided, it is injected as a system-level
  /// context message before the user's question so the AI is aware of
  /// any attached headings.
  Future<void> sendMessage(String text, {String? attachmentContext}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _streamSubscription?.cancel();

    // ── Ensure we have an active thread ────────────────────────────
    String? threadId = _ref.read(currentThreadIdProvider);
    if (threadId == null) {
      await startNewThread();
      threadId = _ref.read(currentThreadIdProvider);
    }

    // Fetch the latest thread info from DB
    if (threadId == null) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create thread',
      );
      return;
    }

    final notifier = _ref.read(chatHistoryNotifierProvider);
    final thread = await notifier.getThread(threadId);
    if (thread == null) {
      await startNewThread();
      final newId = _ref.read(currentThreadIdProvider);
      if (newId == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to create thread',
        );
        return;
      }
      threadId = newId;
    } else if (thread.isFull) {
      state = state.copyWith(
        error:
            'This chat thread has reached its limit of ${thread.maxMessages} queries. '
            'Please start a new chat.',
      );
      return;
    }

    // Init debug log for this pipeline run
    _debugLog = {
      'user_query': trimmed,
      'thread_id': threadId,
      'thread_title': _ref.read(currentThreadTitleProvider),
      'timestamp': DateTime.now().toIso8601String(),
      'settings': {
        'tool_model': _ref.read(aiQaSettingsProvider).toolModel,
        'answer_model': _ref.read(aiQaSettingsProvider).answerModel,
        'orthodox_mode': _ref.read(aiQaSettingsProvider).orthodoxMode,
      },
      'tool_loop': [],
      'answer_model_prompt': '',
      'final_answer': '',
    };

    debugPrint('');
    debugPrint('╔══════════════════════════════════════════════════════════');
    debugPrint('║  VIMAṂSA PIPELINE START');
    debugPrint('╠══════════════════════════════════════════════════════════');
    debugPrint(
      '║  Thread: ${_ref.read(currentThreadTitleProvider)} ($threadId)',
    );
    debugPrint('║  User: ${trimmed.substring(0, min(120, trimmed.length))}');
    debugPrint('╚══════════════════════════════════════════════════════════');
    _finalized = false;

    final userMessage = AiQaMessage.user(trimmed);
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      error: null,
    );
    _ref.read(streamingTextProvider.notifier).state = '';
    _ref.read(streamingMessageIdProvider.notifier).state = null;

    // Save user message to DB
    try {
      await notifier.saveUserMessage(threadId: threadId, content: trimmed);

      // Auto-generate thread title from the first user query.
      // If the title is still the default, update it with the query.
      final currentTitle = _ref.read(currentThreadTitleProvider);
      if (currentTitle == 'Vimaṃsa' || currentTitle.isEmpty) {
        _updateThreadTitle(threadId, trimmed);
      }
    } catch (e) {
      debugPrint('[VIMAṂSA] Failed to save user message: $e');
    }

    try {
      // ── 1. Validate settings ────────────────────────────────────
      final settings = _ref.read(aiQaSettingsProvider);
      if (!settings.isValid) {
        state = state.copyWith(
          isLoading: false,
          error: 'Please configure your API key in the Vimaṃsa settings first.',
        );
        return;
      }

      debugPrint('');
      debugPrint('╔══════════════════════════════════════════════════════════');
      debugPrint('║  SETTINGS');
      debugPrint('╠══════════════════════════════════════════════════════════');
      debugPrint('║  Tool model:  ${settings.toolModel}');
      debugPrint('║  Answer model: ${settings.answerModel}');
      debugPrint(
        '║  Custom prompt: ${settings.customSystemPrompt.isNotEmpty ? "YES (${settings.customSystemPrompt.length} chars)" : "NO (using default)"}',
      );
      debugPrint('╚══════════════════════════════════════════════════════════');

      // ── 2. Start tool loop (small model + function calling) ─────
      final conversation = <Map<String, dynamic>>[];
      final allToolResults = <Map<String, dynamic>>[];
      final debugToolSteps = <Map<String, dynamic>>[];

      // Build conversation from DB history + current user message
      // Load the thread's past messages for full context
      final db = await _ref.read(appDbProvider.future);
      final pastMessages = await db.getChatMessages(threadId);

      // Add ALL past messages (user + assistant) for full context.
      // Gemini uses 'model' role for AI responses (not 'assistant').
      for (final msg in pastMessages) {
        conversation.add({
          'role': msg.role == 'user' ? 'user' : 'model',
          'parts': [
            {'text': msg.content},
          ],
        });
      }

      // Inject attachment context (if any) as a system-level message
      // before the user's actual question.  This tells the AI which
      // headings the user explicitly referenced.
      if (attachmentContext != null && attachmentContext.isNotEmpty) {
        conversation.add({
          'role': 'user',
          'parts': [
            {'text': attachmentContext},
          ],
        });
        _debugLog['attachment_context'] = attachmentContext;
      }

      // Add current user message to conversation
      conversation.add({
        'role': 'user',
        'parts': [
          {'text': userMessage.text},
        ],
      });

      final toolLogs = <ToolCallLog>[];

      final systemPrompt = settings.customSystemPrompt.isNotEmpty
          ? settings.customSystemPrompt
          : _defaultToolSystemPrompt;

      // Tool loop
      bool toolsDone = false;
      int toolIterations = 0;

      while (!toolsDone && toolIterations < _maxToolIterations) {
        toolIterations++;

        final toolResponse = await _callToolModel(
          provider: settings.provider,
          baseUrl: settings.baseUrl,
          systemPrompt: systemPrompt,
          conversation: conversation,
          apiKey: settings.apiKey,
          toolModel: settings.toolModel,
        );

        final parsed = toolResponse['candidates'] as List<dynamic>?;
        if (parsed == null || parsed.isEmpty) {
          throw Exception('Empty response from tool model');
        }

        final candidate = parsed[0] as Map<String, dynamic>;
        final content = candidate['content'] as Map<String, dynamic>?;
        if (content == null) break;

        final parts = content['parts'] as List<dynamic>? ?? [];
        bool hasFunctionCall = false;
        final functionResponses = <Map<String, dynamic>>[];

        // Preserve the ENTIRE model response
        conversation.add(Map<String, dynamic>.from(content));

        // ── PHASE 1: Collect all function calls ──
        final callSpecs = <_ToolCallSpec>[];
        bool hasFinalAnswer = false;
        bool hasTextResponse = false;

        for (final part in parts) {
          final p = part as Map<String, dynamic>;
          if (p.containsKey('functionCall')) {
            hasFunctionCall = true;
            final fc = Map<String, dynamic>.from(
              p['functionCall'] as Map<String, dynamic>,
            );
            final name = fc['name'] as String? ?? '';
            final args = fc['args'] as Map<String, dynamic>? ?? {};

            if (name == 'final_answer') {
              hasFinalAnswer = true;
            } else {
              callSpecs.add(_ToolCallSpec(name: name, args: args));
            }
          } else if (p.containsKey('text')) {
            final textResponse = p['text'] as String? ?? '';
            if (textResponse.isNotEmpty) {
              hasTextResponse = true;
            }
          }
        }

        // ── PHASE 2: Execute all collected tools in PARALLEL ──────
        if (callSpecs.isNotEmpty) {
          for (final spec in callSpecs) {
            toolLogs.add(
              ToolCallLog(
                toolName: spec.name,
                arguments: spec.args,
                resultSummary: spec.name.contains('search')
                    ? '🔍 ${spec.args['query'] ?? spec.args['queries'] ?? "..."}'
                    : 'Calling ${spec.name}...',
              ),
            );
          }

          state = state.copyWith(
            messages: [
              ...state.messages.where((m) => m.id != 'thinking'),
              AiQaMessage(
                id: 'thinking',
                text: '',
                isUser: false,
                timestamp: DateTime.now(),
                isThinking: true,
                toolCalls: [...toolLogs],
              ),
            ],
            isLoading: true,
          );

          final results = await Future.wait(
            callSpecs.map((spec) async {
              try {
                return await _executeTool(spec.name, spec.args);
              } catch (e) {
                return ToolResult(
                  success: false,
                  data: '{}',
                  errorMessage: 'Tool execution error: $e',
                );
              }
            }),
          );

          for (int i = 0; i < callSpecs.length; i++) {
            final spec = callSpecs[i];
            final result = results[i];

            final summary = _buildToolSummary(spec.name, spec.args, result);
            toolLogs[i] = ToolCallLog(
              toolName: spec.name,
              arguments: spec.args,
              resultSummary: summary,
            );

            final resultData = result.success
                ? result.data
                : 'Error: ${result.errorMessage}';
            final maxChars = settings.maxToolResultChars;
            final truncatedData = maxChars > 0 && resultData.length > maxChars
                ? '${resultData.substring(0, maxChars)}\n... (truncated to $maxChars chars)'
                : resultData;

            allToolResults.add({
              'tool': spec.name,
              'args': spec.args,
              'result': resultData,
              'success': result.success,
            });

            // Record tool call in debug log
            debugToolSteps.add({
              'tool': spec.name,
              'args': spec.args,
              'result_summary': summary,
              'result_size': resultData.length,
            });

            functionResponses.add({
              'functionResponse': {
                'name': spec.name,
                'response': {'content': truncatedData},
              },
            });
          }

          state = state.copyWith(
            messages: [
              ...state.messages.where((m) => m.id != 'thinking'),
              AiQaMessage(
                id: 'thinking',
                text: '',
                isUser: false,
                timestamp: DateTime.now(),
                isThinking: true,
                toolCalls: [...toolLogs],
              ),
            ],
            isLoading: true,
          );
        }

        if (hasFinalAnswer) {
          toolsDone = true;
          functionResponses.add({
            'functionResponse': {
              'name': 'final_answer',
              'response': {
                'content':
                    'Proceeding to generate final answer with collected data.',
              },
            },
          });
        }
        if (hasTextResponse) {
          toolsDone = true;
        }

        if (functionResponses.isNotEmpty) {
          conversation.add({'role': 'user', 'parts': functionResponses});
        }

        if (!hasFunctionCall) {
          toolsDone = true;
        }

        if (toolIterations >= _maxToolIterations) {
          debugPrint('[VIMAṂSA] Max tool iterations reached');
          toolsDone = true;
        }
      }

      // Record tool loop in debug log
      _debugLog['tool_loop'] = debugToolSteps;
      _debugLog['conversation'] = conversation.map((c) {
        final role = c['role'];
        final parts = c['parts'];
        return {'role': role, 'parts': parts};
      }).toList();

      // ── 3. Generate final answer ──────────────────────────────────
      final answerSystemPrompt = settings.customSystemPrompt.isNotEmpty
          ? settings.customSystemPrompt
          : _buildAnswerSystemPrompt(orthodoxMode: settings.orthodoxMode);

      final contextBlock = _buildContextBlock(allToolResults);

      final answerPrompt = settings.orthodoxMode
          ? '''
═══════════════════════════════════════════
USER'S ORIGINAL QUESTION:
═══════════════════════════════════════════
${userMessage.text}

═══════════════════════════════════════════
TOOL RESULTS (sources from the database):
═══════════════════════════════════════════
$contextBlock

Please answer the user's question using ONLY the sources above.
If the sources do not cover the question, say so honestly instead of guessing.
Format every citation as [book_id:para_id:line_id] so users can click to open the passage.
'''
          : '''
═══════════════════════════════════════════
USER'S ORIGINAL QUESTION:
═══════════════════════════════════════════
${userMessage.text}

═══════════════════════════════════════════
TOOL RESULTS (sources from the database):
═══════════════════════════════════════════
$contextBlock

Please answer the user's question using the sources above as the primary reference.
You may supplement with your own knowledge of the Pāli Canon where the sources are insufficient.
Format every citation as [book_id:para_id:line_id] so users can click to open the passage.
''';

      final streamingMessageId = _uuid.v4();
      _currentStreamingMessageId = streamingMessageId;
      final streamingMessage = AiQaMessage(
        id: streamingMessageId,
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
        isStreaming: true,
        toolCalls: toolLogs,
      );

      state = state.copyWith(
        messages: [
          ...state.messages.where((m) => !m.isStreaming && m.id != 'thinking'),
          streamingMessage,
        ],
        isLoading: true,
      );
      _ref.read(streamingTextProvider.notifier).state = '';
      _ref.read(streamingMessageIdProvider.notifier).state = streamingMessageId;

      // Save a placeholder assistant message to DB so we can update it
      try {
        _dbMessageId = await notifier.saveAssistantMessage(
          threadId: threadId,
          content: '',
          metadata: '{}',
        );
      } catch (e) {
        debugPrint('[VIMAṂSA] Failed to save placeholder: $e');
        _dbMessageId = null;
      }

      // Stream final answer
      final streamDone = Completer<void>();
      String accumulatedText = '';
      String? streamError;
      final stream = _streamAnswer(
        provider: settings.provider,
        baseUrl: settings.baseUrl,
        systemPrompt: answerSystemPrompt,
        userPrompt: answerPrompt,
        apiKey: settings.apiKey,
        model: settings.answerModel,
        maxTokens: settings.answerMaxTokens,
      );

      _streamSubscription = stream.listen(
        (token) {
          accumulatedText += token;
          _ref.read(streamingTextProvider.notifier).state = accumulatedText;
        },
        onError: (error) {
          debugPrint('[VIMAṂSA] Stream error: $error');
          streamError = _friendlyErrorMessage(error);
          _finalizeMessage(accumulatedText, error: streamError);
          if (!streamDone.isCompleted) streamDone.complete();
        },
        onDone: () {
          // Guard: if the stream finished without producing any text AND no
          // error was reported, surface a clear reason instead of leaving
          // the user staring at a blank assistant bubble.
          if (accumulatedText.trim().isEmpty && streamError == null) {
            streamError =
                'The model returned an empty response. This can happen when '
                'the AI blocks the output or the question is too long. '
                'Try asking again or check the model name in Settings.';
          }
          _finalizeMessage(accumulatedText, error: streamError);
          if (!streamDone.isCompleted) streamDone.complete();
        },
        cancelOnError: false,
      );

      await streamDone.future;

      // Update the assistant message in DB with the final content
      if (_dbMessageId != null && accumulatedText.isNotEmpty) {
        final citations = _parseCitations(accumulatedText);
        final metadata = jsonEncode({
          'citations': citations.map((c) => c.toJson()).toList(),
          'toolCalls': toolLogs.map((t) => t.toJson()).toList(),
        });
        try {
          await notifier.updateAssistantMessage(
            threadId: threadId,
            messageId: _dbMessageId!,
            content: accumulatedText,
            metadata: metadata,
          );
        } catch (e) {
          debugPrint('[VIMAṂSA] Failed to update assistant message: $e');
        }
      }

      _debugLog['final_answer'] = accumulatedText;
      _debugLog['final_answer_length'] = accumulatedText.length;

      debugPrint('');
      debugPrint('╔══════════════════════════════════════════════════════════');
      debugPrint('║  ANSWER COMPLETE');
      debugPrint('╠══════════════════════════════════════════════════════════');
      debugPrint('║  Total tokens received: ${accumulatedText.length} chars');
      debugPrint('╚══════════════════════════════════════════════════════════');
    } catch (e, stack) {
      _debugLog['error'] = '$e';
      _saveDebugLog();
      debugPrint('[VIMAṂSA] Error: $e\n$stack');
      final friendlyError = _friendlyErrorMessage(e);
      if (_finalized) {
        // The stream already finished (e.g. DB save failure) — surface the
        // reason instead of silently swallowing it.
        state = state.copyWith(isLoading: false, error: friendlyError);
      } else {
        _finalizeMessage(
          _ref.read(streamingTextProvider),
          error: friendlyError,
        );
      }
    }

    // Save debug log after successful completion
    _saveDebugLog();
  }

  // ── Tool execution ─────────────────────────────────────────────────────

  Future<ToolResult> _executeTool(
    String name,
    Map<String, dynamic> args,
  ) async {
    final service = _ref.read(aiQaToolServiceProvider);

    switch (name) {
      case 'search_tipitaka':
        return service.searchTipitaka(args);
      case 'search_tipitaka_batch':
        return service.searchTipitakaBatch(args);
      case 'search_by_category':
        return service.searchByCategory(args);
      case 'get_headings':
        return service.getHeadings(args);
      case 'get_books':
        return service.getBooks(args);
      case 'get_paragraph_content':
        return service.getParagraphContent(args);
      case 'get_paragraph_content_batch':
        return service.getParagraphContentBatch(args);
      case 'get_commentaries':
        return service.getCommentaries(args);
      default:
        return ToolResult(
          success: false,
          data: '{}',
          errorMessage: 'Unknown tool: $name',
        );
    }
  }

  // ── API calls ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _callToolModel({
    required AiProvider provider,
    String baseUrl = '',
    required String systemPrompt,
    required List<Map<String, dynamic>> conversation,
    required String apiKey,
    required String toolModel,
  }) async {
    final payload = _buildToolPayload(
      provider: provider,
      systemPrompt: systemPrompt,
      conversation: conversation,
    );

    final payloadSize = utf8.encode(jsonEncode(payload)).length;
    debugPrint(
      '[VIMAṂSA] _callToolModel: $toolModel | '
      'contents=${conversation.length} | '
      'payload=~${(payloadSize / 1024).toStringAsFixed(1)}KB',
    );

    switch (provider) {
      case AiProvider.gemini:
        final response = await _callGeminiApi(
          model: toolModel,
          apiKey: apiKey,
          payload: payload,
        );
        return jsonDecode(response) as Map<String, dynamic>;
      case AiProvider.openai:
        final response = await _callOpenAiApiRaw(
          model: toolModel,
          apiKey: apiKey,
          baseUrl: baseUrl,
          payload: payload,
        );
        return jsonDecode(response) as Map<String, dynamic>;
    }
  }

  /// Build the request payload for the tool model, adapting to the provider.
  Map<String, dynamic> _buildToolPayload({
    required AiProvider provider,
    required String systemPrompt,
    required List<Map<String, dynamic>> conversation,
  }) {
    switch (provider) {
      case AiProvider.gemini:
        return {
          'system_instruction': {
            'parts': [
              {'text': systemPrompt},
            ],
          },
          'contents': conversation,
          'tools': [
            {'functionDeclarations': _toolDeclarations},
          ],
          'generationConfig': {'maxOutputTokens': 2048, 'temperature': 0.3},
        };
      case AiProvider.openai:
        // Convert Gemini-style conversation to OpenAI messages format
        final messages = <Map<String, dynamic>>[];
        messages.add({'role': 'system', 'content': systemPrompt});
        for (final msg in conversation) {
          final role = msg['role'] as String? ?? 'user';
          final parts = msg['parts'] as List<dynamic>? ?? [];
          final text = parts
              .map((p) {
                if (p is Map && p['text'] is String) return p['text'] as String;
                if (p is Map && p['functionResponse'] is Map) {
                  final fr = p['functionResponse'] as Map;
                  return '[Tool result: ${fr['name']}]';
                }
                return '';
              })
              .join('\n');
          if (text.isNotEmpty) {
            messages.add({
              'role': role == 'model' ? 'assistant' : role,
              'content': text,
            });
          }
        }
        // Convert Gemini function declarations to OpenAI tools format
        final openaiTools = _toolDeclarations.map((d) {
          return {
            'type': 'function',
            'function': {
              'name': d['name'],
              'description': d['description'],
              'parameters': d['parameters'],
            },
          };
        }).toList();

        return {
          'messages': messages,
          'tools': openaiTools,
          'tool_choice': 'auto',
          'max_tokens': 2048,
          'temperature': 0.3,
        };
    }
  }

  String _buildToolSummary(
    String name,
    Map<String, dynamic> args,
    ToolResult result,
  ) {
    if (!result.success) {
      return '❌ ${result.errorMessage ?? "Unknown error"}';
    }

    int resultCount = 0;
    try {
      final parsed = jsonDecode(result.data);
      if (parsed is List) {
        resultCount = parsed.length;
      } else if (parsed is Map && parsed['headings'] is List) {
        resultCount = (parsed['headings'] as List).length;
      } else if (parsed is Map && parsed['books'] is List) {
        resultCount = (parsed['books'] as List).length;
      }
    } catch (_) {}

    switch (name) {
      case 'search_tipitaka':
        final query = args['query'] as String? ?? '';
        final queryShort = query.length > 40
            ? '${query.substring(0, 40)}…'
            : query;
        if (resultCount > 0) {
          return '🔍 "$queryShort" → $resultCount results';
        }
        return '🔍 "$queryShort" (${result.data.length} chars)';
      case 'search_tipitaka_batch':
        final queries =
            (args['queries'] as List<dynamic>?)
                ?.map((q) => q.toString())
                .toList() ??
            [];
        final queriesStr = queries
            .map((q) => q.length > 20 ? '${q.substring(0, 20)}…' : q)
            .join(', ');
        return '🔍 Batch[$resultCount results] ($queriesStr)';
      case 'search_by_category':
        final cats =
            (args['categories'] as List<dynamic>?)
                ?.map((c) => c.toString())
                .toList() ??
            [];
        final niks =
            (args['nikayas'] as List<dynamic>?)
                ?.map((n) => n.toString())
                .toList() ??
            [];
        final scope = [...cats, ...niks];
        final scopeStr = scope.isEmpty ? 'all' : scope.join(', ');
        return '🔍 $scopeStr[$resultCount results]';
      case 'get_headings':
        final bookId = args['book_id'] as String? ?? '';
        return '📋 $bookId — $resultCount headings';
      case 'get_books':
        return '📚 $resultCount books';
      case 'get_paragraph_content':
        final bookId = args['book_id'] as String? ?? '';
        final start = args['para_start'] ?? 0;
        final end = args['para_end'] ?? 0;
        return '📖 $bookId §$start–$end (${result.data.length} chars)';
      case 'get_paragraph_content_batch':
        return '📖 Batch $resultCount ranges (${result.data.length} chars)';
      case 'get_commentaries':
        final bookId = args['mula_book_id'] as String? ?? '';
        final paraId = args['mula_para_id'] ?? 0;
        return '📝 Commentary on $bookId §$paraId: $resultCount found';
      default:
        return '$name completed (${result.data.length} chars)';
    }
  }

  Stream<String> _streamAnswer({
    required AiProvider provider,
    String baseUrl = '',
    required String systemPrompt,
    required String userPrompt,
    required String apiKey,
    required String model,
    required int maxTokens,
  }) async* {
    switch (provider) {
      case AiProvider.gemini:
        yield* _geminiStreamAnswer(
          model: model,
          apiKey: apiKey,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          maxTokens: maxTokens,
        );
      case AiProvider.openai:
        yield* _openaiStreamAnswer(
          model: model,
          apiKey: apiKey,
          baseUrl: baseUrl,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          maxTokens: maxTokens,
        );
    }
  }

  Stream<String> _geminiStreamAnswer({
    required String model,
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
  }) async* {
    final payload = {
      'system_instruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'contents': [
        {
          'parts': [
            {'text': userPrompt},
          ],
        },
      ],
      'generationConfig': {
        'maxOutputTokens': maxTokens,
        'temperature': 0.3,
        'topP': 0.95,
      },
    };

    final url = Uri.parse(
      '$_geminiBaseUrl/$model:streamGenerateContent?alt=sse&key=$apiKey',
    );

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(payload);

    final httpClient = http.Client();
    try {
      final httpResponse = await httpClient.send(request);

      if (httpResponse.statusCode != 200) {
        final errorBody = await httpResponse.stream.bytesToString();
        throw Exception(
          'API error ${httpResponse.statusCode}: ${_parseApiError(errorBody)}',
        );
      }

      await for (final line
          in httpResponse.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data: ')) continue;
        final data = trimmed.substring(6).trim();
        if (data == '[DONE]' || data == '[done]') break;
        if (data.isEmpty) continue;

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final candidates = json['candidates'] as List<dynamic>?;
          if (candidates == null || candidates.isEmpty) continue;

          final content = candidates[0]['content'] as Map<String, dynamic>?;
          if (content == null) continue;

          final parts = content['parts'] as List<dynamic>?;
          if (parts == null || parts.isEmpty) continue;

          final text = parts[0]['text'] as String?;
          if (text != null && text.isNotEmpty) {
            yield text;
          }
        } catch (e) {
          // Skip malformed chunks
        }
      }
    } finally {
      httpClient.close();
    }
  }

  Stream<String> _openaiStreamAnswer({
    required String model,
    required String apiKey,
    required String baseUrl,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
  }) async* {
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ];

    final payload = {
      'model': model,
      'messages': messages,
      'stream': true,
      'max_tokens': maxTokens,
      'temperature': 0.3,
    };

    final effectiveBase = baseUrl.isNotEmpty
        ? baseUrl
        : 'https://api.openai.com/v1';
    final url = Uri.parse('$effectiveBase/chat/completions');

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..body = jsonEncode(payload);

    final httpClient = http.Client();
    try {
      final httpResponse = await httpClient.send(request);

      if (httpResponse.statusCode != 200) {
        final errorBody = await httpResponse.stream.bytesToString();
        throw Exception(
          'API error ${httpResponse.statusCode}: ${_parseApiError(errorBody)}',
        );
      }

      await for (final line
          in httpResponse.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data: ')) continue;
        final data = trimmed.substring(6).trim();
        if (data == '[DONE]' || data == '[done]') break;
        if (data.isEmpty) continue;

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final choices = json['choices'] as List<dynamic>?;
          if (choices == null || choices.isEmpty) continue;

          final delta = choices[0]['delta'] as Map<String, dynamic>?;
          if (delta == null) continue;

          final text = delta['content'] as String?;
          if (text != null && text.isNotEmpty) {
            yield text;
          }
        } catch (e) {
          // Skip malformed chunks
        }
      }
    } finally {
      httpClient.close();
    }
  }

  /// Gemini-style non-streaming API call.
  Future<String> _callGeminiApi({
    required String model,
    required String apiKey,
    required Map<String, dynamic> payload,
  }) async {
    final url = Uri.parse('$_geminiBaseUrl/$model:generateContent?key=$apiKey');

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final apiStopwatch = Stopwatch()..start();
        final httpResponse = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
        final apiDuration = apiStopwatch.elapsedMilliseconds;

        if (httpResponse.statusCode == 200) {
          debugPrint(
            '[VIMAṂSA] API $model: 200 OK (${apiDuration}ms, '
            '${(httpResponse.body.length / 1024).toStringAsFixed(1)}KB)',
          );
          return httpResponse.body;
        } else if (httpResponse.statusCode == 429) {
          if (attempt < _maxRetries) {
            final wait = Duration(seconds: (pow(2, attempt + 1) * 2).toInt());
            await Future.delayed(wait);
            continue;
          }
          throw Exception('Rate limit exceeded. Try again later.');
        } else {
          if (attempt < _maxRetries) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          throw Exception(
            'API error ${httpResponse.statusCode}: ${_parseApiError(httpResponse.body)}',
          );
        }
      } on http.ClientException {
        if (attempt < _maxRetries) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        rethrow;
      }
    }

    throw Exception('API call failed after $_maxRetries retries');
  }

  /// OpenAI-compatible non-streaming API call (raw response for tool pipeline).
  Future<String> _callOpenAiApiRaw({
    required String model,
    required String apiKey,
    required String baseUrl,
    required Map<String, dynamic> payload,
  }) async {
    final effectiveBase = baseUrl.isNotEmpty
        ? baseUrl
        : 'https://api.openai.com/v1';
    final url = Uri.parse('$effectiveBase/chat/completions');

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final apiStopwatch = Stopwatch()..start();
        final httpResponse = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode(payload),
        );
        final apiDuration = apiStopwatch.elapsedMilliseconds;

        if (httpResponse.statusCode == 200) {
          debugPrint(
            '[VIMAṂSA] API $model: 200 OK (${apiDuration}ms, '
            '${(httpResponse.body.length / 1024).toStringAsFixed(1)}KB)',
          );
          // Parse the OpenAI response and wrap it in a format compatible
          // with the tool pipeline (which expects Gemini-like structure).
          final data = jsonDecode(httpResponse.body) as Map<String, dynamic>;
          final choices = data['choices'] as List<dynamic>? ?? [];
          if (choices.isNotEmpty) {
            final message =
                choices[0]['message'] as Map<String, dynamic>? ?? {};
            final content = message['content'] as String? ?? '';
            final toolCalls = message['tool_calls'] as List<dynamic>?;

            // Build a response that the tool pipeline can parse
            final parts = <Map<String, dynamic>>[];
            if (content.isNotEmpty) {
              parts.add({'text': content});
            }
            if (toolCalls != null) {
              for (final tc in toolCalls) {
                final tcMap = tc as Map<String, dynamic>;
                parts.add({
                  'functionCall': {
                    'name': tcMap['function']['name'],
                    'args': jsonDecode(
                      tcMap['function']['arguments'] as String,
                    ),
                  },
                });
              }
            }

            final adaptedResponse = {
              'candidates': [
                {
                  'content': {'parts': parts, 'role': 'model'},
                  'finishReason': message['finish_reason'] ?? 'STOP',
                },
              ],
            };
            return jsonEncode(adaptedResponse);
          }
          return httpResponse.body;
        } else if (httpResponse.statusCode == 429) {
          if (attempt < _maxRetries) {
            final wait = Duration(seconds: (pow(2, attempt + 1) * 2).toInt());
            await Future.delayed(wait);
            continue;
          }
          throw Exception('Rate limit exceeded. Try again later.');
        } else {
          if (attempt < _maxRetries) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          throw Exception(
            'API error ${httpResponse.statusCode}: ${_parseApiError(httpResponse.body)}',
          );
        }
      } on http.ClientException {
        if (attempt < _maxRetries) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        rethrow;
      }
    }

    throw Exception('API call failed after $_maxRetries retries');
  }

  String _parseApiError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>?;
      if (error != null) {
        return error['message'] as String? ??
            error['status'] as String? ??
            body;
      }
      return body;
    } on FormatException {
      return body;
    }
  }

  /// Translate raw errors into a friendly, actionable message for the user.
  ///
  /// The raw exception text (HTTP status, socket errors, etc.) is often
  /// cryptic — this makes sure the reason is understandable and suggests
  /// what to do next.
  String _friendlyErrorMessage(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();

    final statusMatch = RegExp(r'API error (\d+)').firstMatch(raw);
    if (statusMatch != null) {
      switch (statusMatch.group(1)) {
        case '400':
          return 'The AI service rejected the request (400). The question may '
              'be too long or contain unsupported content. Try asking again.';
        case '401':
        case '403':
          return 'Your API key was rejected (${statusMatch.group(1)}). '
              'Please check the API key in Settings.';
        case '404':
          return 'Model not found (404). The selected model may have been '
              'renamed or is unavailable — update the model in Settings.';
        case '429':
          return 'Rate limit exceeded (429). Please wait a moment and try again.';
        case '500':
        case '502':
        case '503':
          return 'The AI service is temporarily unavailable '
              '(${statusMatch.group(1)}). Please try again shortly.';
        default:
          return 'The AI service returned an error '
              '(${statusMatch.group(1)}). Please try again.';
      }
    }

    if (lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('clientexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('handshake')) {
      return 'Network error — could not reach the AI service. '
          'Check your internet connection and try again.';
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'The request timed out. Try again, or ask a shorter question.';
    }
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return 'Rate limit exceeded. Please wait a moment and try again.';
    }
    if (lower.contains('empty response')) {
      return 'The AI service returned an empty response. '
          'Check that the selected model is correct in Settings and try again.';
    }
    if (lower.contains('quota') || lower.contains('billing')) {
      return 'Your API quota may be exhausted. Check your usage/billing on '
          'the provider console.';
    }
    return 'Something went wrong: $raw';
  }

  // ── Context building & finalization ───────────────────────────────────

  String _buildContextBlock(List<Map<String, dynamic>> toolResults) {
    final parts = <String>[];
    for (int i = 0; i < toolResults.length; i++) {
      final tr = toolResults[i];
      final toolName = tr['tool'] as String? ?? 'unknown';
      parts.add('--- Tool Result ${i + 1}: $toolName ---');
      parts.add('Arguments: ${_encoder.convert(tr['args'])}');
      parts.add('Result:');

      String resultStr;
      try {
        final resultRaw = tr['result'] as String? ?? '{}';
        final parsed = jsonDecode(resultRaw);
        resultStr = _encoder.convert(parsed);
      } catch (e) {
        resultStr = tr['result'] as String? ?? '';
      }
      final maxChars = _ref.read(aiQaSettingsProvider).maxToolResultChars;
      if (maxChars > 0 && resultStr.length > maxChars) {
        resultStr =
            '${resultStr.substring(0, maxChars)}\n... (truncated to $maxChars chars)';
      }
      parts.add(resultStr);
      parts.add('');
    }
    return parts.join('\n');
  }

  List<SourceCitation> _parseCitations(String text) {
    final regex = RegExp(r'\[([a-zA-Z0-9_.-]+):(\d+):(\d+)\]');
    final matches = regex.allMatches(text);
    final seen = <String>{};
    final citations = <SourceCitation>[];

    for (final match in matches) {
      final bookId = match.group(1)!;
      final paraId = int.tryParse(match.group(2)!) ?? 0;
      final lineId = int.tryParse(match.group(3)!) ?? 1;
      final key = '$bookId:$paraId:$lineId';

      if (seen.add(key)) {
        citations.add(
          SourceCitation(
            bookId: bookId,
            paraId: paraId,
            lineId: lineId,
            excerpt: '',
          ),
        );
      }
    }

    return citations;
  }

  void _finalizeMessage(String text, {String? error}) {
    if (_finalized) return;
    _finalized = true;

    final citations = _parseCitations(text);
    final messages = [...state.messages];

    final messageId = _currentStreamingMessageId;
    if (messageId != null) {
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index >= 0) {
        // If generation failed with no content, drop the blank bubble so the
        // user isn't left looking at an empty assistant message.
        if (error != null && text.trim().isEmpty) {
          messages.removeAt(index);
        } else {
          messages[index] = messages[index].copyWith(
            text: text,
            citations: citations,
            isStreaming: false,
          );
        }
      }
    }

    // Remove the transient "thinking" placeholder on failure so the chat
    // doesn't end on a stuck researching bubble.
    if (error != null) {
      messages.removeWhere((m) => m.id == 'thinking');
    }

    state = state.copyWith(messages: messages, isLoading: false, error: error);
    _ref.read(streamingTextProvider.notifier).state = '';
    _ref.read(streamingMessageIdProvider.notifier).state = null;
  }

  /// Clear all messages and reset the active thread.
  void clearChat() {
    _ref.read(currentThreadIdProvider.notifier).state = null;
    _ref.read(currentThreadTitleProvider.notifier).state = '';
    state = const AiQaState();
  }

  /// Generate a title from the user's query and update the thread.
  Future<void> _updateThreadTitle(String threadId, String query) async {
    // Truncate to first line, max ~50 chars, clean up whitespace
    var title = query.trim().split('\n').first.trim();
    if (title.length > 50) {
      title = '${title.substring(0, 47)}…';
    }
    // Remove trailing punctuation
    title = title.replaceAll(RegExp(r'[.:;!?,]+$'), '').trim();
    if (title.isEmpty) title = 'Vimaṃsa';

    _ref.read(currentThreadTitleProvider.notifier).state = title;
    try {
      await _ref
          .read(chatHistoryNotifierProvider)
          .updateThreadTitle(threadId, title);
    } catch (e) {
      debugPrint('[VIMAṂSA] Failed to update thread title: $e');
    }
  }

  /// Dismiss the current error.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for the Vimaṃsa chat state.
final aiQaProvider = StateNotifierProvider<AiQaNotifier, AiQaState>((ref) {
  return AiQaNotifier(ref);
});
