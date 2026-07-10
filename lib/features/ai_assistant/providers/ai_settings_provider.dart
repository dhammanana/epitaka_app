/// Riverpod provider for the AI Assistant settings (API key, model selection).
///
/// Settings are persisted to SharedPreferences under the key
/// `ai_assistant_settings`. The provider exposes the raw state and mutation
/// methods like `setApiKey`, `setRenderModel`, and `setLiteModel`.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_assistant_models.dart';

/// Persistence key in SharedPreferences.
const _kPrefsKey = 'ai_assistant_settings';

/// StateNotifier that manages [AiAssistantSettings] with SharedPreferences
/// persistence.
class AiSettingsNotifier extends StateNotifier<AiAssistantSettings> {
  AiSettingsNotifier() : super(const AiAssistantSettings());

  /// Load settings from SharedPreferences. Call once at startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        state = AiAssistantSettings.fromJson(json);
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

  /// Set the Gemini API key.
  Future<void> setApiKey(String apiKey) async {
    state = state.copyWith(apiKey: apiKey.trim());
    await _persist();
  }

  /// Set the render model name.
  Future<void> setRenderModel(String model) async {
    state = state.copyWith(renderModel: model.trim());
    await _persist();
  }

  /// Set the lite model name.
  Future<void> setLiteModel(String model) async {
    state = state.copyWith(liteModel: model.trim());
    await _persist();
  }

  /// Update multiple settings at once.
  Future<void> updateAll(AiAssistantSettings newSettings) async {
    state = newSettings;
    await _persist();
  }

  /// Clear the API key (for security).
  Future<void> clearApiKey() async {
    state = state.copyWith(apiKey: '');
    await _persist();
  }
}

/// Provider for [AiAssistantSettings].
final aiSettingsProvider =
    StateNotifierProvider<AiSettingsNotifier, AiAssistantSettings>((ref) {
  return AiSettingsNotifier();
});
