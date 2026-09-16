/// Riverpod provider for the Vīmaṃsā settings (API key, model selection,
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

/// Per-provider profile history (anx-reader pattern): each provider keeps
/// its own api key, base URL and models, so switching providers restores
/// what was last used for that provider instead of showing one shared set
/// of fields.
const _kProfilesPrefsKey = 'ai_qa_provider_profiles';

/// Default tool/answer models per provider (used when a provider is
/// selected for the first time and has no saved profile yet).
String _defaultToolModelFor(AiProvider provider) {
  switch (provider) {
    case AiProvider.gemini:
      return 'gemini-flash-lite-latest';
    case AiProvider.openai:
      return 'gpt-4o-mini';
    case AiProvider.openrouter:
      return 'google/gemini-2.5-flash-lite:free';
    case AiProvider.claude:
      return 'claude-3-5-haiku-latest';
    case AiProvider.deepseek:
      return 'deepseek-chat';
  }
}

String _defaultAnswerModelFor(AiProvider provider) {
  switch (provider) {
    case AiProvider.gemini:
      return 'gemini-flash-latest';
    case AiProvider.openai:
      return 'gpt-4o';
    case AiProvider.openrouter:
      return 'meta-llama/llama-4-maverick:free';
    case AiProvider.claude:
      return 'claude-3-5-sonnet-latest';
    case AiProvider.deepseek:
      return 'deepseek-chat';
  }
}

/// StateNotifier that manages [AiQaSettings] with SharedPreferences
/// persistence.
class AiQaSettingsNotifier extends StateNotifier<AiQaSettings> {
  /// Last-used fields per provider name (see [_kProfilesPrefsKey]).
  Map<String, Map<String, String>> _profiles = {};

  AiQaSettingsNotifier() : super(const AiQaSettings()) {
    load();
  }

  /// Load settings from SharedPreferences. Call once at startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _profiles = _decodeProfiles(prefs.getString(_kProfilesPrefsKey));
    final raw = prefs.getString(_kPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        state = AiQaSettings.fromJson(json);
      } catch (_) {
        // Invalid JSON — use defaults
      }
    }
    // Backfill the active provider's profile so a first switch away
    // preserves the current fields.
    _profiles[state.provider.name] = _snapshot(state);
    await _persistProfiles();
  }

  /// Save the current settings to SharedPreferences.
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, jsonEncode(state.toJson()));
  }

  static Map<String, Map<String, String>> _decodeProfiles(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return json.map(
        (k, v) => MapEntry(
          k,
          (v as Map<String, dynamic>).map((a, b) => MapEntry(a, '$b')),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _persistProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfilesPrefsKey, jsonEncode(_profiles));
  }

  static Map<String, String> _snapshot(AiQaSettings s) => {
    'apiKey': s.apiKey,
    'baseUrl': s.baseUrl,
    'toolModel': s.toolModel,
    'answerModel': s.answerModel,
  };

  /// Remember the current fields under the active provider.
  Future<void> _snapshotActive() async {
    _profiles[state.provider.name] = _snapshot(state);
    await _persistProfiles();
  }

  /// Set the AI provider, restoring that provider's saved key/URL/models.
  Future<void> setProvider(AiProvider provider) async {
    if (provider == state.provider) return;
    await _snapshotActive();
    final saved = _profiles[provider.name];
    if (saved != null) {
      state = state.copyWith(
        provider: provider,
        apiKey: saved['apiKey'] ?? '',
        baseUrl: saved['baseUrl'] ?? '',
        toolModel: (saved['toolModel'] ?? '').isNotEmpty
            ? saved['toolModel']!
            : _defaultToolModelFor(provider),
        answerModel: (saved['answerModel'] ?? '').isNotEmpty
            ? saved['answerModel']!
            : _defaultAnswerModelFor(provider),
      );
    } else {
      state = state.copyWith(
        provider: provider,
        apiKey: '',
        baseUrl: '',
        toolModel: _defaultToolModelFor(provider),
        answerModel: _defaultAnswerModelFor(provider),
      );
      _profiles[provider.name] = _snapshot(state);
      await _persistProfiles();
    }
    await _persist();
  }

  /// Set the base URL (for OpenAI-compatible providers).
  Future<void> setBaseUrl(String baseUrl) async {
    state = state.copyWith(baseUrl: baseUrl.trim());
    await _snapshotActive();
    await _persist();
  }

  /// Set the API key.
  Future<void> setApiKey(String apiKey) async {
    state = state.copyWith(apiKey: apiKey.trim());
    await _snapshotActive();
    await _persist();
  }

  /// Set the tool model name (e.g. gemini-2.0-flash-lite).
  Future<void> setToolModel(String model) async {
    state = state.copyWith(toolModel: model.trim());
    await _snapshotActive();
    await _persist();
  }

  /// Set the answer model name (e.g. gemini-2.0-flash).
  Future<void> setAnswerModel(String model) async {
    state = state.copyWith(answerModel: model.trim());
    await _snapshotActive();
    await _persist();
  }

  /// Set the saved answer-model fallbacks (tried in order).
  Future<void> setAnswerFallbacks(List<String> fallbacks) async {
    state = state.copyWith(
      answerFallbacks: fallbacks
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty && m != state.answerModel.trim())
          .take(2)
          .toList(),
    );
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

  /// Set the chat font size scale (1.0 = default).
  Future<void> setChatFontSize(double value) async {
    state = state.copyWith(chatFontSize: value.clamp(0.7, 2.0));
    await _persist();
  }

  /// Update multiple settings at once.
  Future<void> updateAll(AiQaSettings newSettings) async {
    state = newSettings;
    await _snapshotActive();
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
