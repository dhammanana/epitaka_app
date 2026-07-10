/// Riverpod provider managing the AI Assistant chat state.
///
/// Implements a RAG pipeline inspired by the Python aichat app:
///   1. **Search** — query the local Tipitaka DB for relevant passages
///   2. **Rerank** — use the lite model to filter & re-rank results
///   3. **Answer** — use the render model to generate a grounded answer
///      with [Source N] citations
///   4. **Parse** — extract source references for tappable citations
///
/// The pipeline runs entirely client-side (local DB + Gemini API calls).
/// No server infrastructure required beyond the Gemini API key.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/ai_assistant_models.dart';
import '../services/ai_prompt_templates.dart';
import '../services/gemini_api_service.dart';
import '../services/tipitaka_search_service.dart';
import 'ai_settings_provider.dart';

/// UUID generator for message IDs.
const _uuid = Uuid();

/// StateNotifier managing the AI Assistant chat.
class AiChatNotifier extends StateNotifier<AiChatState> {
  final Ref _ref;

  AiChatNotifier(this._ref) : super(const AiChatState());

  /// Set the chat mode (Literal Review vs Answer Question).
  void setMode(AiChatMode mode) {
    if (state.mode != mode) {
      state = state.copyWith(mode: mode);
    }
  }

  /// Subscription for the current streaming response.
  /// Cancelled when a new message is sent or the provider is disposed.
  StreamSubscription<String>? _streamSubscription;

  /// ID of the current streaming message, used for robust lookup in
  /// [_finalizeStreamingMessage].
  String? _currentStreamingMessageId;

  /// Guard flag to prevent double finalization.
  bool _finalized = false;

  /// Send a user message and run the RAG pipeline with streaming output.
  ///
  /// Steps:
  /// 1. Add user message to history
  /// 2. Validate API settings
  /// 3. Search Tipitaka DB for relevant passages
  /// 4. (Optional) Rerank results using the lite model
  /// 5. Build context block + insert a placeholder streaming message
  /// 6. Stream answer tokens from the render model, updating in real-time
  /// 7. Parse answer for [Source N] references and finalize the message
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Cancel any in-flight stream before starting a new one
    await _streamSubscription?.cancel();
    _finalized = false;

    // ── 1. Add user message ─────────────────────────────────────────
    final userMessage = AiChatMessage(
      id: _uuid.v4(),
      text: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
      mode: state.mode,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      isStreaming: false,
      streamingText: '',
      error: null,
    );

    try {
      // ── 2. Validate settings ──────────────────────────────────────
      final settings = _ref.read(aiSettingsProvider);
      if (!settings.isValid) {
        state = state.copyWith(
          isLoading: false,
          error: 'Please configure your Gemini API key in the AI Assistant settings first.',
        );
        return;
      }

      // ── 3. Search Tipitaka DB ─────────────────────────────────────
      final searchService = _ref.read(tipitakaSearchServiceProvider);
      final searchResults = await searchService.search(
        query: trimmed,
        limit: 20,
      );

      if (searchResults.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'No passages found in the local Tipitaka database for this query.',
        );
        return;
      }

      // Convert to the format expected by the reranker
      final candidates = searchResults
          .map((r) => {
                'book_id': r.bookId,
                'para_id': r.paraId,
                'line_id': r.lineId,
                'book_name': r.bookName ?? r.bookId,
                'text': r.text,
                'translation': r.translation ?? '',
                'score': r.score,
              })
          .toList();

      // ── 4. Rerank using lite model ─────────────────────────────────
      final geminiService = _ref.read(geminiApiServiceProvider);
      List<int> rankedIndices;

      try {
        rankedIndices = await geminiService.rerankResults(
          question: trimmed,
          candidates: candidates,
          apiKey: settings.apiKey,
          liteModel: settings.liteModel,
        );
      } catch (e) {
        debugPrint('[AI_CHAT] Rerank failed, using all results: $e');
        rankedIndices = List.generate(candidates.length, (i) => i);
      }

      // Take top candidates for the context
      final topK = 8;
      final topIndices = rankedIndices.take(topK).toList();
      final topCandidates = topIndices.map((i) => candidates[i]).toList();

      // ── 5. Build context + insert placeholder streaming message ───
      final contextBlock = AiPromptTemplates.buildContextBlock(topCandidates);

      final systemPrompt = state.mode == AiChatMode.literalReview
          ? AiPromptTemplates.literalReviewSystem
          : AiPromptTemplates.answerQuestionSystem;

      final userPrompt = AiPromptTemplates.buildUserPrompt(
        question: trimmed,
        contextBlock: contextBlock,
      );

      final streamingMessageId = _uuid.v4();
      _currentStreamingMessageId = streamingMessageId;
      final streamingMessage = AiChatMessage(
        id: streamingMessageId,
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
        mode: state.mode,
        isStreaming: true,
      );

      state = state.copyWith(
        messages: [...state.messages, streamingMessage],
        isLoading: false,
        isStreaming: true,
        streamingText: '',
      );

      // ── 6. Stream answer tokens ───────────────────────────────────
      final stream = geminiService.generateAnswerStream(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        apiKey: settings.apiKey,
        model: settings.renderModel,
      );

      String accumulatedText = '';

      _streamSubscription = stream.listen(
        (token) {
          accumulatedText += token;
          state = state.copyWith(streamingText: accumulatedText);
        },
        onError: (error) {
          debugPrint('[AI_CHAT] Stream error: $error');
          // Finalize with what we have so far
          _finalizeStreamingMessage(accumulatedText, topCandidates);
        },
        onDone: () {
          _finalizeStreamingMessage(accumulatedText, topCandidates);
        },
        cancelOnError: false,
      );

      // Await the stream subscription completing
      await _streamSubscription!.asFuture<void>();
    } catch (e, stack) {
      debugPrint('[AI_CHAT] Error: $e\n$stack');
      // If we had started streaming, finalize with partial text
      if (state.isStreaming) {
        _finalizeStreamingMessage(state.streamingText, []);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Unexpected error: $e',
        );
      }
    }
  }

  /// Finalize the current streaming message: replace the placeholder
  /// with a complete [AiChatMessage] containing full text and sources.
  void _finalizeStreamingMessage(
    String text,
    List<Map<String, dynamic>> candidates,
  ) {
    // Guard against double finalization (onError + onDone can both fire)
    if (_finalized) return;
    _finalized = true;

    final sources = _parseSources(text, candidates);
    final messages = [...state.messages];

    // Find the streaming message by ID for robustness
    final messageId = _currentStreamingMessageId;
    if (messageId != null) {
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index >= 0) {
        messages[index] = messages[index].copyWith(
          text: text,
          sources: sources,
          isStreaming: false,
        );
      }
    }

    state = state.copyWith(
      messages: messages,
      isStreaming: false,
      streamingText: '',
    );
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  /// Parse [Source N] citations from the answer text and match them to
  /// the search results we provided.
  List<SourceReference> _parseSources(
    String answer,
    List<Map<String, dynamic>> candidates,
  ) {
    final matches = AiPromptTemplates.sourceRefRegex.allMatches(answer);
    final seen = <String>{};
    final sources = <SourceReference>[];

    for (final match in matches) {
      final num = int.tryParse(match.group(1) ?? '') ?? 0;
      if (num < 1 || num > candidates.length) continue;

      final candidate = candidates[num - 1];
      final bookId = candidate['book_id'] as String? ?? '';
      final paraId = candidate['para_id'] as int? ?? 0;
      final lineId = candidate['line_id'] as int? ?? 1;
      final key = '$bookId:$paraId:$lineId';

      if (seen.add(key)) {
        sources.add(SourceReference(
          bookId: bookId,
          paraId: paraId,
          lineId: lineId,
          excerpt: (candidate['text'] as String? ?? '').length > 200
              ? '${(candidate['text'] as String).substring(0, 200)}...'
              : candidate['text'] as String? ?? '',
          bookName: candidate['book_name'] as String?,
          relevance: (candidate['score'] as double?) ?? 0.0,
          language: 'pali',
        ));
      }
    }

    return sources;
  }

  /// Clear all messages from the chat.
  void clearChat() {
    state = const AiChatState();
  }

  /// Dismiss the current error.
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Provider for the AI Assistant chat state.
final aiChatProvider =
    StateNotifierProvider<AiChatNotifier, AiChatState>((ref) {
  return AiChatNotifier(ref);
});
