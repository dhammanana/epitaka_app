// lib/features/translator/translator_settings.dart
//
// Persisted settings for the on-device Translation Builder: which AI
// provider/key/model to run, the target language, the books to translate,
// the (editable) system prompt, and the overwrite toggle.
//
// Model + Riverpod provider, persisted to SharedPreferences under a single
// JSON key (same pattern as AiQaSettings).

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/models/ai_provider.dart';
import 'translator_constants.dart';

/// Persistence key in SharedPreferences.
const String kTranslatorPrefsKey = 'translator_settings';

/// Settings for the in-app Translation Builder.
class TranslatorSettings {
  final AiProvider provider;

  /// API keys to use for translation, in priority order. The runner
  /// round-robins across them so multiple keys can share the load (the
  /// server's KeyRotator pattern). Empty means "fall back to the AI Q&A
  /// settings key".
  final List<String> apiKeys;
  final String baseUrl;
  final String model;

  /// Target language code (e.g. 'vi', 'my').
  final String langCode;

  /// Book IDs to translate (empty = all books).
  final List<String> bookIds;

  /// Custom system prompt; empty = the default template.
  final String customPrompt;

  /// Re-translate lines that already have a translation.
  final bool overwrite;

  /// Token budget per AI call (chars/4 ≈ tokens). Larger chunks mean fewer
  /// calls (cheaper, faster) but risk hitting provider context limits.
  final int chunkMaxTokens;

  const TranslatorSettings({
    this.provider = AiProvider.gemini,
    this.apiKeys = const [],
    this.baseUrl = '',
    this.model = kTranslatorDefaultModel,
    this.langCode = 'vi',
    this.bookIds = const [],
    this.customPrompt = '',
    this.overwrite = false,
    this.chunkMaxTokens = kTranslatorChunkMaxTokens,
  });

  /// First configured key, or empty.
  String get primaryApiKey => apiKeys.isEmpty ? '' : apiKeys.first;

  /// Whether at least one usable (non-trivial) key is configured.
  bool get hasApiKey => apiKeys.any((k) => k.trim().length >= 5);

  /// Usable keys only (trimmed, non-empty, ≥ 5 chars).
  List<String> get usableApiKeys =>
      apiKeys.map((k) => k.trim()).where((k) => k.length >= 5).toList();

  TranslatorSettings copyWith({
    AiProvider? provider,
    List<String>? apiKeys,
    String? baseUrl,
    String? model,
    String? langCode,
    List<String>? bookIds,
    String? customPrompt,
    bool? overwrite,
    int? chunkMaxTokens,
  }) {
    return TranslatorSettings(
      provider: provider ?? this.provider,
      apiKeys: apiKeys ?? this.apiKeys,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      langCode: langCode ?? this.langCode,
      bookIds: bookIds ?? this.bookIds,
      customPrompt: customPrompt ?? this.customPrompt,
      overwrite: overwrite ?? this.overwrite,
      chunkMaxTokens: chunkMaxTokens ?? this.chunkMaxTokens,
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider.serialise,
    'apiKeys': apiKeys,
    'baseUrl': baseUrl,
    'model': model,
    'langCode': langCode,
    'bookIds': bookIds,
    'customPrompt': customPrompt,
    'overwrite': overwrite,
    'chunkMaxTokens': chunkMaxTokens,
  };

  factory TranslatorSettings.fromJson(Map<String, dynamic> json) {
    // Backwards compatibility: older saves stored a single `apiKey`.
    final legacyKey = json['apiKey'] as String? ?? '';
    final keys = (json['apiKeys'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    if (keys.isEmpty && legacyKey.isNotEmpty) keys.add(legacyKey);
    return TranslatorSettings(
      provider: AiProvider.fromString(json['provider'] as String? ?? 'gemini'),
      apiKeys: keys,
      baseUrl: json['baseUrl'] as String? ?? '',
      model: (json['model'] as String? ?? '').isNotEmpty
          ? json['model'] as String
          : kTranslatorDefaultModel,
      langCode: json['langCode'] as String? ?? 'vi',
      bookIds: (json['bookIds'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      customPrompt: json['customPrompt'] as String? ?? '',
      overwrite: json['overwrite'] as bool? ?? false,
      chunkMaxTokens: (json['chunkMaxTokens'] as num?)?.toInt() ??
          kTranslatorChunkMaxTokens,
    );
  }
}

/// StateNotifier managing [TranslatorSettings] with SharedPreferences
/// persistence.
class TranslatorSettingsNotifier extends StateNotifier<TranslatorSettings> {
  TranslatorSettingsNotifier() : super(const TranslatorSettings()) {
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kTranslatorPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        state = TranslatorSettings.fromJson(json);
      } catch (_) {
        // Invalid JSON — keep defaults.
      }
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kTranslatorPrefsKey, jsonEncode(state.toJson()));
  }

  Future<void> setProvider(AiProvider provider) async {
    state = state.copyWith(provider: provider);
    await _persist();
  }

  /// Replace the full ordered key list.
  Future<void> setApiKeys(List<String> keys) async {
    state = state.copyWith(apiKeys: keys);
    await _persist();
  }

  /// Add a key to the end of the list (deduplicated).
  Future<void> addApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;
    final keys = List<String>.from(state.apiKeys);
    if (!keys.contains(trimmed)) keys.add(trimmed);
    await setApiKeys(keys);
  }

  /// Remove a key from the list.
  Future<void> removeApiKey(String key) async {
    final keys = List<String>.from(state.apiKeys)..remove(key);
    await setApiKeys(keys);
  }

  Future<void> setBaseUrl(String url) async {
    state = state.copyWith(baseUrl: url.trim());
    await _persist();
  }

  Future<void> setModel(String model) async {
    state = state.copyWith(model: model.trim());
    await _persist();
  }

  Future<void> setLangCode(String code) async {
    state = state.copyWith(langCode: code);
    await _persist();
  }

  Future<void> setBookIds(List<String> ids) async {
    state = state.copyWith(bookIds: ids);
    await _persist();
  }

  Future<void> toggleBook(String id) async {
    final current = List<String>.from(state.bookIds);
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    await setBookIds(current);
  }

  Future<void> setCustomPrompt(String prompt) async {
    state = state.copyWith(customPrompt: prompt);
    await _persist();
  }

  Future<void> setOverwrite(bool value) async {
    state = state.copyWith(overwrite: value);
    await _persist();
  }

  /// Reset the system prompt to the default template.
  Future<void> resetCustomPrompt() async {
    await setCustomPrompt('');
  }

  Future<void> setChunkMaxTokens(int tokens) async {
    state = state.copyWith(chunkMaxTokens: tokens);
    await _persist();
  }
}

/// Provider for [TranslatorSettings].
final translatorSettingsProvider =
    StateNotifierProvider<TranslatorSettingsNotifier, TranslatorSettings>((ref) {
  return TranslatorSettingsNotifier();
});
