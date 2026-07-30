import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_provider.dart';

/// Result of fetching models from an AI provider.
class AiModelFetchResult {
  final List<String> models;
  final String? error;

  const AiModelFetchResult({required this.models, this.error});

  bool get isSuccess => error == null;
}

/// Service to list available models from various AI providers.
class AiModelService {
  /// Fetch models from the given provider.
  ///
  /// For [AiProvider.gemini], uses the Gemini models list endpoint.
  /// For [AiProvider.openai], calls the OpenAI-compatible `/models` endpoint.
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
          return _fetchOpenAiModels(apiKey, baseUrl);
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
        .toList()
      ..sort();

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
    final effectiveBase = baseUrl.isNotEmpty ? baseUrl : 'https://api.openai.com/v1';
    final url = Uri.parse('$effectiveBase/models');

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
