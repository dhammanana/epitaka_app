/// Data models for the AI Assistant (Paññā) feature.
///
/// Provides a RAG-powered chat interface for the Tipitaka, inspired by
/// the Python aichat app. Supports two modes:
///   - **Literal Review**: deep research with citations back to source text
///   - **Answer Question**: general grounded Q&A
library;

/// The two chat modes the AI Assistant supports.
enum AiChatMode {
  /// Deep literal review — search Tipitaka for a topic and produce a
  /// research synthesis with inline source citations.
  literalReview,

  /// Grounded Q&A — answer a question using the Tipitaka corpus.
  answerQuestion,
}

/// Persisted settings for the AI Assistant.
///
/// Stored in SharedPreferences under the `ai_assistant_settings` key.
class AiAssistantSettings {
  /// Gemini API key (or any Google AI Studio key).
  final String apiKey;

  /// The "render" model used for generating final answers.
  /// Should be capable (e.g. gemini-2.0-flash, gemini-1.5-pro).
  final String renderModel;

  /// The "lite" model used for filtering/reranking/agentic tasks.
  /// Should be fast/cheap (e.g. gemini-2.0-flash-lite).
  final String liteModel;

  /// Whether the AI must strictly follow provided sources (true) or
  /// can answer freely using its own knowledge (false).
  final bool strictMode;

  const AiAssistantSettings({
    this.apiKey = '',
    this.renderModel = 'gemini-2.0-flash',
    this.liteModel = 'gemini-2.0-flash-lite',
    this.strictMode = true,
  });

  /// Whether the settings are valid enough to make API calls.
  bool get isValid => apiKey.isNotEmpty && apiKey.startsWith('AI');

  AiAssistantSettings copyWith({
    String? apiKey,
    String? renderModel,
    String? liteModel,
    bool? strictMode,
  }) {
    return AiAssistantSettings(
      apiKey: apiKey ?? this.apiKey,
      renderModel: renderModel ?? this.renderModel,
      liteModel: liteModel ?? this.liteModel,
      strictMode: strictMode ?? this.strictMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'apiKey': apiKey,
        'renderModel': renderModel,
        'liteModel': liteModel,
        'strictMode': strictMode,
      };

  factory AiAssistantSettings.fromJson(Map<String, dynamic> json) {
    return AiAssistantSettings(
      apiKey: json['apiKey'] as String? ?? '',
      renderModel: json['renderModel'] as String? ?? 'gemini-2.0-flash',
      liteModel: json['liteModel'] as String? ?? 'gemini-2.0-flash-lite',
      strictMode: json['strictMode'] as bool? ?? true,
    );
  }
}

/// A single source reference linking a claim back to the Tipitaka.
class SourceReference {
  /// The book identifier (e.g. "dn1", "mn141").
  final String bookId;

  /// Paragraph number within the book.
  final int paraId;

  /// Line number within the paragraph (1-based).
  final int lineId;

  /// Short excerpt of the text for display in the citation popup.
  final String? excerpt;

  /// Human-readable book name (e.g. "Mahāsatipaṭṭhāna Sutta").
  final String? bookName;

  /// Optional relevance score from the LLM (0.0–1.0).
  final double? relevance;

  /// Optional language of the excerpt (english, pali).
  final String? language;

  const SourceReference({
    required this.bookId,
    required this.paraId,
    required this.lineId,
    this.excerpt,
    this.bookName,
    this.relevance,
    this.language,
  });

  /// Unique key used for deduplication and indexing in the UI.
  String get uniqueKey => '$bookId:$paraId:$lineId';

  /// Construct a URL-like reference string for display.
  String get displayRef => '$bookId §$paraId:$lineId';

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'paraId': paraId,
        'lineId': lineId,
        if (excerpt != null) 'excerpt': excerpt,
        if (bookName != null) 'bookName': bookName,
        if (relevance != null) 'relevance': relevance,
        if (language != null) 'language': language,
      };

  factory SourceReference.fromJson(Map<String, dynamic> json) {
    return SourceReference(
      bookId: json['bookId'] as String,
      paraId: (json['paraId'] as num).toInt(),
      lineId: (json['lineId'] as num).toInt(),
      excerpt: json['excerpt'] as String?,
      bookName: json['bookName'] as String?,
      relevance: (json['relevance'] as num?)?.toDouble(),
      language: json['language'] as String?,
    );
  }
}

/// A single message in the AI Assistant chat.
class AiChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final AiChatMode mode;

  /// Source references cited in this message (for assistant messages).
  final List<SourceReference> sources;

  /// Whether the answer is still being streamed (typing indicator).
  final bool isStreaming;

  /// English translation of the message text (for user messages in
  /// non-English languages). Null if the message is already in English.
  final String? translation;

  /// Detected language of the message (e.g. "Burmese", "Thai").
  final String? detectedLanguage;

  const AiChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    required this.mode,
    this.sources = const [],
    this.isStreaming = false,
    this.translation,
    this.detectedLanguage,
  });

  AiChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    AiChatMode? mode,
    List<SourceReference>? sources,
    bool? isStreaming,
    String? translation,
    String? detectedLanguage,
    bool clearTranslation = false,
    bool clearDetectedLanguage = false,
  }) {
    return AiChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      mode: mode ?? this.mode,
      sources: sources ?? this.sources,
      isStreaming: isStreaming ?? this.isStreaming,
      translation: clearTranslation ? null : (translation ?? this.translation),
      detectedLanguage: clearDetectedLanguage ? null : (detectedLanguage ?? this.detectedLanguage),
    );
  }
}

/// Full state of the AI Assistant chat interface.
class AiChatState {
  /// Chat message history.
  final List<AiChatMessage> messages;

  /// Whether a request is in flight.
  final bool isLoading;

  /// Whether a request is being streamed (receiving tokens).
  final bool isStreaming;

  /// Current accumulated streaming text.
  final String streamingText;

  /// Selected chat mode.
  final AiChatMode mode;

  /// Error message, if any.
  final String? error;

  const AiChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isStreaming = false,
    this.streamingText = '',
    this.mode = AiChatMode.answerQuestion,
    this.error,
  });

  AiChatState copyWith({
    List<AiChatMessage>? messages,
    bool? isLoading,
    bool? isStreaming,
    String? streamingText,
    AiChatMode? mode,
    String? error,
    bool clearError = false,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isStreaming: isStreaming ?? this.isStreaming,
      streamingText: streamingText ?? this.streamingText,
      mode: mode ?? this.mode,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

