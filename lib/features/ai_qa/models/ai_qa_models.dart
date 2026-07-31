/// Data models for the Vimaṃsa (AI Q&A) feature.
///
/// Vimaṃsa (विमंसा) means investigation, examination, or exploration —
/// the systematic probing of the Dhamma through questioning.
///
/// Unlike the existing AI Assistant (Paññā) which pre-searches the DB and
/// sends everything in one prompt, this feature uses Gemini **function
/// calling** so the model itself decides which tools to invoke based on
/// the user's question.
library;

import 'package:uuid/uuid.dart';

import '../../shared/models/ai_provider.dart';

const _uuid = Uuid();

// ═══════════════════════════════════════════════════════════════════════════
//  CHAT THREAD
// ═══════════════════════════════════════════════════════════════════════════

/// A single chat thread in Vimaṃsa.
class ChatThread {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;
  final int maxMessages;

  const ChatThread({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messageCount = 0,
    this.maxMessages = 8,
  });

  bool get isFull => messageCount >= maxMessages;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'message_count': messageCount,
    'max_messages': maxMessages,
  };

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
      maxMessages: (json['max_messages'] as num?)?.toInt() ?? 8,
    );
  }

  ChatThread copyWith({
    String? title,
    DateTime? updatedAt,
    int? messageCount,
    int? maxMessages,
  }) {
    return ChatThread(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messageCount: messageCount ?? this.messageCount,
      maxMessages: maxMessages ?? this.maxMessages,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CHAT MESSAGE (persisted)
// ═══════════════════════════════════════════════════════════════════════════

/// A persisted chat message within a thread.
class ChatMessageRecord {
  final int id;
  final String threadId;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime createdAt;
  final String? metadata; // JSON: citations, toolCalls, etc.

  const ChatMessageRecord({
    required this.id,
    required this.threadId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.metadata,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
//  SETTINGS
// ═══════════════════════════════════════════════════════════════════════════

/// Persisted settings for the Vimaṃsa feature.
class AiQaSettings {
  /// Gemini API key (or any Google AI Studio key).
  final String apiKey;

  /// The "tool" model used for function calling (fast/cheap).
  final String toolModel;

  /// The "answer" model used for generating the final answer (capable).
  final String answerModel;

  /// Optional custom system prompt override.
  final String customSystemPrompt;

  /// Max chars per tool result sent to the model (0 = no truncation).
  final int maxToolResultChars;

  /// Max output tokens for the answer model.
  final int answerMaxTokens;

  /// AI provider (Gemini or OpenAI-compatible).
  final AiProvider provider;

  /// Base URL for the API. Only used for OpenAI-compatible providers.
  final String baseUrl;

  /// Max queries (user messages) allowed per chat thread.
  final int maxQueriesPerChat;

  /// Whether answers must be based ONLY on the passages found in the
  /// Tipitaka ("orthodox" mode).  When false, the AI may supplement the
  /// found passages with its own knowledge of the Pāli Canon.
  /// Defaults to true.
  final bool orthodoxMode;

  const AiQaSettings({
    this.apiKey = '',
    this.provider = AiProvider.gemini,
    this.baseUrl = '',
    this.toolModel = 'gemini-flash-lite-latest',
    this.answerModel = 'gemini-flash-latest',
    this.customSystemPrompt = '',
    this.maxToolResultChars = 200000,
    this.answerMaxTokens = 64000,
    this.maxQueriesPerChat = 8,
    this.orthodoxMode = true,
  });

  bool get isValid {
    if (apiKey.isEmpty) return false;
    if (provider == AiProvider.gemini) return apiKey.startsWith('AI');
    return apiKey.length >= 20;
  }

  AiQaSettings copyWith({
    String? apiKey,
    AiProvider? provider,
    String? baseUrl,
    String? toolModel,
    String? answerModel,
    String? customSystemPrompt,
    int? maxToolResultChars,
    int? answerMaxTokens,
    int? maxQueriesPerChat,
    bool? orthodoxMode,
  }) {
    return AiQaSettings(
      apiKey: apiKey ?? this.apiKey,
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      toolModel: toolModel ?? this.toolModel,
      answerModel: answerModel ?? this.answerModel,
      customSystemPrompt: customSystemPrompt ?? this.customSystemPrompt,
      maxToolResultChars: maxToolResultChars ?? this.maxToolResultChars,
      answerMaxTokens: answerMaxTokens ?? this.answerMaxTokens,
      maxQueriesPerChat: maxQueriesPerChat ?? this.maxQueriesPerChat,
      orthodoxMode: orthodoxMode ?? this.orthodoxMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'apiKey': apiKey,
    'provider': provider.serialise,
    'baseUrl': baseUrl,
    'toolModel': toolModel,
    'answerModel': answerModel,
    'customSystemPrompt': customSystemPrompt,
    'maxToolResultChars': maxToolResultChars,
    'answerMaxTokens': answerMaxTokens,
    'maxQueriesPerChat': maxQueriesPerChat,
    'orthodoxMode': orthodoxMode,
  };

  factory AiQaSettings.fromJson(Map<String, dynamic> json) {
    return AiQaSettings(
      apiKey: json['apiKey'] as String? ?? '',
      provider: AiProvider.fromString(json['provider'] as String? ?? ''),
      baseUrl: json['baseUrl'] as String? ?? '',
      toolModel: json['toolModel'] as String? ?? 'gemini-flash-lite-latest',
      answerModel: json['answerModel'] as String? ?? 'gemini-flash-latest',
      customSystemPrompt: json['customSystemPrompt'] as String? ?? '',
      maxToolResultChars:
          (json['maxToolResultChars'] as num?)?.toInt() ?? 200000,
      answerMaxTokens: (json['answerMaxTokens'] as num?)?.toInt() ?? 64000,
      maxQueriesPerChat: (json['maxQueriesPerChat'] as num?)?.toInt() ?? 8,
      orthodoxMode: json['orthodoxMode'] as bool? ?? true,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CITATION
// ═══════════════════════════════════════════════════════════════════════════

/// A single source citation linking a claim back to the Tipitaka.
class SourceCitation {
  final String bookId;
  final String? bookName;
  final int paraId;
  final int lineId;

  /// Short excerpt of the Pāli text for display in the citation button.
  final String excerpt;

  const SourceCitation({
    required this.bookId,
    this.bookName,
    required this.paraId,
    required this.lineId,
    this.excerpt = '',
  });

  String get uniqueKey => '$bookId:$paraId:$lineId';

  String get displayRef => '$bookId §$paraId:$lineId';

  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'bookName': bookName,
    'paraId': paraId,
    'lineId': lineId,
    'excerpt': excerpt,
  };

  factory SourceCitation.fromJson(Map<String, dynamic> json) {
    return SourceCitation(
      bookId: json['bookId'] as String,
      bookName: json['bookName'] as String?,
      paraId: (json['paraId'] as num).toInt(),
      lineId: (json['lineId'] as num).toInt(),
      excerpt: json['excerpt'] as String? ?? '',
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MESSAGE
// ═══════════════════════════════════════════════════════════════════════════

/// A single message in the Vimaṃsa chat.
class AiQaMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  /// Source citations referenced in this message (for assistant messages).
  final List<SourceCitation> citations;

  /// Whether this is a "thinking" message (tool calls in progress).
  final bool isThinking;

  /// Whether the answer is still being streamed (typing indicator).
  final bool isStreaming;

  /// Log of tool calls made during this message's generation.
  final List<ToolCallLog> toolCalls;

  const AiQaMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.citations = const [],
    this.isThinking = false,
    this.isStreaming = false,
    this.toolCalls = const [],
  });

  AiQaMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    List<SourceCitation>? citations,
    bool? isThinking,
    bool? isStreaming,
    List<ToolCallLog>? toolCalls,
  }) {
    return AiQaMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      citations: citations ?? this.citations,
      isThinking: isThinking ?? this.isThinking,
      isStreaming: isStreaming ?? this.isStreaming,
      toolCalls: toolCalls ?? this.toolCalls,
    );
  }

  factory AiQaMessage.user(String text) {
    return AiQaMessage(
      id: _uuid.v4(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
  }

  factory AiQaMessage.assistantPlaceholder() {
    return AiQaMessage(
      id: _uuid.v4(),
      text: '',
      isUser: false,
      timestamp: DateTime.now(),
      isStreaming: true,
    );
  }
}

/// Record of a single tool call during the Q&A process.
class ToolCallLog {
  final String toolName;
  final Map<String, dynamic> arguments;
  final String resultSummary;

  const ToolCallLog({
    required this.toolName,
    required this.arguments,
    required this.resultSummary,
  });

  Map<String, dynamic> toJson() => {
    'toolName': toolName,
    'arguments': arguments,
    'resultSummary': resultSummary,
  };

  factory ToolCallLog.fromJson(Map<String, dynamic> json) {
    return ToolCallLog(
      toolName: json['toolName'] as String,
      arguments: json['arguments'] as Map<String, dynamic>? ?? {},
      resultSummary: json['resultSummary'] as String? ?? '',
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  STATE
// ═══════════════════════════════════════════════════════════════════════════

/// Full state of the Vimaṃsa chat interface.
class AiQaState {
  /// Chat message history.
  final List<AiQaMessage> messages;

  /// Whether a request is in flight.
  final bool isLoading;

  /// Error message, if any.
  final String? error;

  const AiQaState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  AiQaState copyWith({
    List<AiQaMessage>? messages,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AiQaState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
