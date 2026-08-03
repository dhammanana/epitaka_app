/// Riverpod provider for the Vimaṃsa settings (API key, model selection,
/// custom system prompt).
///
/// Settings are persisted to SharedPreferences under the key
/// `ai_qa_settings`. The provider exposes the raw state and mutation
/// methods.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/ai_provider.dart';
import '../models/ai_qa_models.dart';

/// Persistence key in SharedPreferences.
const _kPrefsKey = 'ai_qa_settings';

/// StateNotifier that manages [AiQaSettings] with SharedPreferences
/// persistence.
class AiQaSettingsNotifier extends StateNotifier<AiQaSettings> {
  AiQaSettingsNotifier() : super(const AiQaSettings()) {
    load();
  }

  /// Load settings from SharedPreferences. Call once at startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        state = AiQaSettings.fromJson(json);
      } catch (_) {
        // Invalid JSON — use defaults
      }
    }
  }

  /// Save the current settings to SharedPreferences.
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, jsonEncode(state.toJson()));
  }

  /// Set the AI provider.
  Future<void> setProvider(AiProvider provider) async {
    state = state.copyWith(provider: provider);
    await _persist();
  }

  /// Set the base URL (for OpenAI-compatible providers).
  Future<void> setBaseUrl(String baseUrl) async {
    state = state.copyWith(baseUrl: baseUrl.trim());
    await _persist();
  }

  /// Set the API key.
  Future<void> setApiKey(String apiKey) async {
    state = state.copyWith(apiKey: apiKey.trim());
    await _persist();
  }

  /// Set the tool model name (e.g. gemini-2.0-flash-lite).
  Future<void> setToolModel(String model) async {
    state = state.copyWith(toolModel: model.trim());
    await _persist();
  }

  /// Set the answer model name (e.g. gemini-2.0-flash).
  Future<void> setAnswerModel(String model) async {
    state = state.copyWith(answerModel: model.trim());
    await _persist();
  }

  /// Set the custom system prompt.
  Future<void> setCustomSystemPrompt(String prompt) async {
    state = state.copyWith(customSystemPrompt: prompt.trim());
    await _persist();
  }

  /// Set max chars per tool result (0 = no truncation).
  Future<void> setMaxToolResultChars(int chars) async {
    state = state.copyWith(maxToolResultChars: chars);
    await _persist();
  }

  /// Set max output tokens for the answer model.
  Future<void> setAnswerMaxTokens(int tokens) async {
    state = state.copyWith(answerMaxTokens: tokens);
    await _persist();
  }

  /// Set max queries per chat thread.
  Future<void> setMaxQueriesPerChat(int count) async {
    state = state.copyWith(maxQueriesPerChat: count);
    await _persist();
  }

  /// Set whether answers must be based ONLY on the passages found in the
  /// Tipitaka (orthodox mode).
  Future<void> setOrthodoxMode(bool value) async {
    state = state.copyWith(orthodoxMode: value);
    await _persist();
  }

  /// Update multiple settings at once.
  Future<void> updateAll(AiQaSettings newSettings) async {
    state = newSettings;
    await _persist();
  }

  /// Clear the API key (for security).
  Future<void> clearApiKey() async {
    state = state.copyWith(apiKey: '');
    await _persist();
  }
}

/// Provider for [AiQaSettings].
final aiQaSettingsProvider =
    StateNotifierProvider<AiQaSettingsNotifier, AiQaSettings>((ref) {
  return AiQaSettingsNotifier();
});
