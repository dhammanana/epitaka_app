/// Riverpod provider for managing chat thread history in Vimaṃsa.
///
/// Provides CRUD operations for [ChatThread] records, backed by the
/// local [AppDatabase] (which lazily creates `chat_threads` and
/// `chat_messages` tables).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/app_db_provider.dart';
import '../models/ai_qa_models.dart';

/// Provider that fetches all chat threads (sorted most recent first).
final chatThreadsProvider = FutureProvider<List<ChatThread>>((ref) async {
  final db = await ref.watch(appDbProvider.future);
  return db.getAllChatThreads();
});

/// Provider for a single chat thread by ID.
final chatThreadProvider =
    FutureProvider.family<ChatThread?, String>((ref, threadId) async {
  final db = await ref.watch(appDbProvider.future);
  return db.getChatThread(threadId);
});

/// Provider that fetches all messages for a thread.
final chatMessagesProvider =
    FutureProvider.family<List<ChatMessageRecord>, String>(
        (ref, threadId) async {
  final db = await ref.watch(appDbProvider.future);
  return db.getChatMessages(threadId);
});

/// Notifier for thread management operations.
final chatHistoryNotifierProvider =
    Provider<ChatHistoryNotifier>((ref) {
  return ChatHistoryNotifier(ref);
});

class ChatHistoryNotifier {
  final Ref _ref;
  ChatHistoryNotifier(this._ref);

  Future<ChatThread?> getThread(String id) async {
    final db = await _ref.read(appDbProvider.future);
    return db.getChatThread(id);
  }

  /// Create a new thread and invalidate the thread list.
  Future<ChatThread> createThread({
    required String id,
    required String title,
    int maxMessages = 8,
  }) async {
    final db = await _ref.read(appDbProvider.future);
    final thread = await db.createChatThread(
      id: id,
      title: title,
      maxMessages: maxMessages,
    );
    _ref.invalidate(chatThreadsProvider);
    return thread;
  }

  /// Delete a thread and invalidate relevant providers.
  Future<void> deleteThread(String id) async {
    final db = await _ref.read(appDbProvider.future);
    await db.deleteChatThread(id);
    _ref.invalidate(chatThreadsProvider);
    _ref.invalidate(chatThreadProvider(id));
    _ref.invalidate(chatMessagesProvider(id));
  }

  /// Delete all threads.
  Future<void> deleteAllThreads() async {
    final db = await _ref.read(appDbProvider.future);
    await db.deleteAllChatThreads();
    _ref.invalidate(chatThreadsProvider);
  }

  /// Save a user message to a thread.
  Future<void> saveUserMessage({
    required String threadId,
    required String content,
    String? metadata,
  }) async {
    final db = await _ref.read(appDbProvider.future);
    await db.saveUserMessage(
      threadId: threadId,
      content: content,
      metadata: metadata,
    );
    await db.incrementChatThreadMessageCount(threadId);
    _ref.invalidate(chatThreadsProvider);
    _ref.invalidate(chatThreadProvider(threadId));
    _ref.invalidate(chatMessagesProvider(threadId));
  }

  /// Save an assistant message to a thread.
  Future<int> saveAssistantMessage({
    required String threadId,
    required String content,
    String? metadata,
  }) async {
    final db = await _ref.read(appDbProvider.future);
    await db.saveAssistantMessage(
      threadId: threadId,
      content: content,
      metadata: metadata,
    );
    // Fetch the last inserted message to get its ID
    final messages = await db.getChatMessages(threadId);
    final lastMsg = messages.last;
    _ref.invalidate(chatMessagesProvider(threadId));
    return lastMsg.id;
  }

  /// Update an assistant message (for stream finalization).
  Future<void> updateAssistantMessage({
    required String threadId,
    required int messageId,
    required String content,
    required String metadata,
  }) async {
    final db = await _ref.read(appDbProvider.future);
    await db.updateAssistantMessage(messageId, content, metadata);
    _ref.invalidate(chatMessagesProvider(threadId));
  }

  /// Update thread title.
  Future<void> updateThreadTitle(String id, String title) async {
    final db = await _ref.read(appDbProvider.future);
    await db.updateChatThreadTitle(id, title);
    _ref.invalidate(chatThreadsProvider);
    _ref.invalidate(chatThreadProvider(id));
  }
}
