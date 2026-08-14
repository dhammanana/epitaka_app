import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_provider.dart';

/// Result of fetching models from an AI provider.
class AiModelFetchResult {
  final List<String> models;
  final String? error;

  /// Model ids that are completely free (OpenRouter `pricing` of 0).
  /// Empty for providers that don't report per-model pricing.
  final List<String> freeModels;

  const AiModelFetchResult({
    required this.models,
    this.error,
    this.freeModels = const [],
  });

  bool get isSuccess => error == null;
}

/// Service to list available models from various AI providers.
class AiModelService {
  /// Fetch models from the given provider.
  ///
  /// For [AiProvider.gemini], uses the Gemini models list endpoint.
  /// For [AiProvider.openai], calls the OpenAI-compatible `/models` endpoint.
  /// For [AiProvider.openrouter], calls the OpenRouter `/models` endpoint and
  /// also reports which models are free (pricing of 0).
  static Future<AiModelFetchResult> fetchModels({
    required AiProvider provider,
    required String apiKey,
    String baseUrl = '',
  }) async {
    try {
      switch (provider) {
        case AiProvider.gemini:
          return _fetchGeminiModels(apiKey);
        case AiProvider.openai:
          return _fetchOpenAiModels(
            apiKey,
            baseUrl.isNotEmpty ? baseUrl : provider.defaultBaseUrl,
          );
        case AiProvider.openrouter:
          return _fetchOpenRouterModels(
            apiKey,
            baseUrl.isNotEmpty ? baseUrl : provider.defaultBaseUrl,
          );
      }
    } catch (e) {
      return AiModelFetchResult(
        models: [],
        error: 'Failed to fetch models: $e',
      );
    }
  }

  static Future<AiModelFetchResult> _fetchGeminiModels(
    String apiKey,
  ) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      return AiModelFetchResult(
        models: [],
        error: 'API error ${response.statusCode}: ${_parseError(response.body)}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final modelsList = data['models'] as List<dynamic>? ?? [];

    // Gemini model names are like "models/gemini-2.0-flash"
    // We extract the short name and filter for generateContent-capable models
    final models = modelsList
        .where((m) {
          final model = m as Map<String, dynamic>;
          final supportedMethods =
              model['supportedGenerationMethods'] as List<dynamic>?;
          return supportedMethods?.contains('generateContent') ?? false;
        })
        .map((m) {
          final name = (m as Map<String, dynamic>)['name'] as String? ?? '';
          // Strip "models/" prefix
          return name.startsWith('models/') ? name.substring(7) : name;
        })
        .where((n) => n.isNotEmpty)
        // Only include gemini-NNN models (skip embedding, aqa, imagen, etc.)
        .where((n) => RegExp(r'^gemini-\d+').hasMatch(n))
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (models.isEmpty) {
      return AiModelFetchResult(
        models: [],
        error: 'No chat-capable models found for this API key.',
      );
    }

    return AiModelFetchResult(models: models);
  }

  static Future<AiModelFetchResult> _fetchOpenAiModels(
    String apiKey,
    String baseUrl,
  ) async {
    final url = Uri.parse('$baseUrl/models');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200) {
      return AiModelFetchResult(
        models: [],
        error: 'API error ${response.statusCode}: ${_parseError(response.body)}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final modelsList = data['data'] as List<dynamic>? ?? [];

    final models = modelsList
        .map((m) => (m as Map<String, dynamic>)['id'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList()
      ..sort();

    if (models.isEmpty) {
      return AiModelFetchResult(
        models: [],
        error: 'No models found for this API key.',
      );
    }

    return AiModelFetchResult(models: models);
  }

  /// Fetch models from OpenRouter.
  ///
  /// The response includes per-model `pricing` (USD per token as strings;
  /// `"0"` means the model is free). We surface the free models so the UI can
  /// auto-pick a free model without hardcoding model names.
  static Future<AiModelFetchResult> _fetchOpenRouterModels(
    String apiKey,
    String baseUrl,
  ) async {
    final url = Uri.parse('$baseUrl/models');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200) {
      return AiModelFetchResult(
        models: [],
        error: 'API error ${response.statusCode}: ${_parseError(response.body)}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final modelsList = data['data'] as List<dynamic>? ?? [];

    final models = <String>[];
    final freeModels = <String>[];

    for (final item in modelsList) {
      final m = item as Map<String, dynamic>;
      final id = m['id'] as String? ?? '';
      if (id.isEmpty) continue;

      models.add(id);

      // A model is free when OpenRouter reports zero pricing OR its id
      // carries the documented `:free` variant suffix (used when pricing
      // data is absent).
      final pricing = m['pricing'] as Map<String, dynamic>?;
      final prompt = pricing == null ? -1 : _parsePrice(pricing['prompt']);
      final completion =
          pricing == null ? -1 : _parsePrice(pricing['completion']);
      if ((prompt == 0 && completion == 0) ||
          id.toLowerCase().endsWith(':free')) {
        freeModels.add(id);
      }
    }

    // Sort: free models first (so chips show them up front), then by name.
    models.sort((a, b) {
      final aFree = freeModels.contains(a);
      final bFree = freeModels.contains(b);
      if (aFree != bFree) return aFree ? -1 : 1;
      return a.compareTo(b);
    });
    freeModels.sort();

    if (models.isEmpty) {
      return AiModelFetchResult(
        models: [],
        error: 'No models found for this API key.',
      );
    }

    return AiModelFetchResult(models: models, freeModels: freeModels);
  }

  /// Parse a pricing string like `"0"` or `"0.0000025"` into a double.
  /// Malformed values fall back to a sentinel so they're never treated as free.
  static double _parsePrice(dynamic value) {
    if (value == null) return -1;
    return double.tryParse(value.toString()) ?? -1;
  }

  static String _parseError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>?;
      if (error != null) {
        return error['message'] as String? ?? error['code'] as String? ?? body;
      }
      return body;
    } catch (_) {
      return body;
    }
  }
}
