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
import 'package:uuid/uuid.dart';

import '../../../core/providers/app_db_provider.dart';
import '../../../core/utils/database_initializer.dart';
import '../../shared/models/ai_provider.dart';
import '../models/ai_qa_models.dart';
import '../models/heading_attachment.dart';
import '../services/ai_api_client.dart';
import 'ai_qa_settings_provider.dart';
import 'chat_history_provider.dart';

const _uuid = Uuid();

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

  static const _encoder = JsonEncoder.withIndent('  ');

  static const int _maxToolIterations = 8;  // ── Debug log ──────────────────────────────────────────────────────────

  /// Debug log data collected during the current pipeline run.
  Map<String, dynamic> _debugLog = {};

  /// Save the full AI pipeline trace to a debug file.
  /// Overwritten each time; open with any text editor to inspect.
  Future<void> _saveDebugLog() async {
    if (_debugLog.isEmpty) return;
    try {
      final dir = await getDatabaseDirectory();
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

  static const String _defaultToolSystemPrompt = kAiDefaultToolSystemPrompt;

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
      var settings = _ref.read(aiQaSettingsProvider);
      if (!settings.isValid) {
        await _ref.read(aiQaSettingsProvider.notifier).load();
        settings = _ref.read(aiQaSettingsProvider);
      }
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

      // Tool loop — shared engine (see ai_api_client.dart)
      // Tool loop — shared engine (see ai_api_client.dart)
      final loopResult = await runAiToolLoop(
        settings: settings,
        systemPrompt: systemPrompt,
        initialConversation: conversation,
        executeTool: (name, args) => executeAiTool(_ref, name, args),
        onToolUpdate: (logs) {
          toolLogs
            ..clear()
            ..addAll(logs);
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
        },
        maxIterations: _maxToolIterations,
        logTag: 'VIMAṂSA',
      );

      // Record tool loop in debug log
      _debugLog['tool_loop'] = loopResult.debugToolSteps;
      _debugLog['conversation'] = loopResult.conversation.map((c) {
        final role = c['role'];
        final parts = c['parts'];
        return {'role': role, 'parts': parts};
      }).toList();

      // ── 3. Generate final answer ──────────────────────────────────
      final answerSystemPrompt = settings.customSystemPrompt.isNotEmpty
          ? settings.customSystemPrompt
          : _buildAnswerSystemPrompt(orthodoxMode: settings.orthodoxMode);

      final contextBlock = _buildContextBlock(loopResult.allToolResults);

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
          streamError = AiApiClient.friendlyErrorMessage(error);
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
      final friendlyError = AiApiClient.friendlyErrorMessage(e);
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
      case AiProvider.openrouter:
        // OpenRouter speaks the OpenAI chat-completions protocol, so both
        // providers share the same streaming code path.
        yield* _openaiStreamAnswer(
          model: model,
          apiKey: apiKey,
          baseUrl: baseUrl.isNotEmpty ? baseUrl : provider.defaultBaseUrl,
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
      '$kGeminiBaseUrl/$model:streamGenerateContent?alt=sse&key=$apiKey',
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
          'API error ${httpResponse.statusCode}: ${AiApiClient.parseApiError(errorBody)}',
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
          'API error ${httpResponse.statusCode}: ${AiApiClient.parseApiError(errorBody)}',
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
