/// Service for calling AI APIs to generate grounded answers.
///
/// Supports two providers:
///   - **Google Gemini** — uses the Gemini REST API
///   - **OpenAI-compatible** — uses the Chat Completions API (covers
///     OpenAI, OpenRouter, DeepSeek, etc.)
///
/// Two model tiers:
///   - **Render model** (e.g. gemini-2.0-flash) — generates the final
///     answer with source citations.
///   - **Lite model** (e.g. gemini-2.0-flash-lite) — fast, cheap model
///     for re-ranking search results and keyword expansion.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../shared/models/ai_provider.dart';
import 'ai_prompt_templates.dart';

/// Response from an AI API call.
class _AiResponse {
  final String text;
  const _AiResponse({required this.text});
}

/// Service that encapsulates AI API calls (Gemini & OpenAI-compatible).
class GeminiApiService {
  GeminiApiService();

  /// Gemini default base URL.
  static const String _geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Maximum retries for transient failures.
  static const int _maxRetries = 2;

  // ── Streaming answer generation ──────────────────────────────────────

  /// Generate a grounded answer via SSE streaming.
  ///
  /// [provider] — which API provider to use.
  /// [baseUrl] — custom base URL (for OpenAI-compatible only).
  /// [systemPrompt] — the system instruction.
  /// [userPrompt] — the user turn with question + context block.
  /// [apiKey] — API key.
  /// [model] — model name.
  Stream<String> generateAnswerStream({
    required AiProvider provider,
    String baseUrl = '',
    required String systemPrompt,
    required String userPrompt,
    required String apiKey,
    required String model,
  }) async* {
    switch (provider) {
      case AiProvider.gemini:
        yield* _geminiStream(
          model: model,
          apiKey: apiKey,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
        );
      case AiProvider.openai:
        yield* _openaiStream(
          model: model,
          apiKey: apiKey,
          baseUrl: baseUrl,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
        );
    }
  }

  /// Non-streaming convenience wrapper (used internally for rerank/expand).
  Future<String> generateAnswer({
    required AiProvider provider,
    String baseUrl = '',
    required String systemPrompt,
    required String userPrompt,
    required String apiKey,
    required String model,
  }) async {
    switch (provider) {
      case AiProvider.gemini:
        final payload = _geminiPayload(systemPrompt, userPrompt,
            maxTokens: 4096);
        final response = await _callGeminiApi(
          model: model,
          apiKey: apiKey,
          payload: payload,
        );
        return response.text;
      case AiProvider.openai:
        final response = await _callOpenAiApi(
          model: model,
          apiKey: apiKey,
          baseUrl: baseUrl,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          maxTokens: 4096,
        );
        return response.text;
    }
  }

  // ── Rerank search results using the lite model ──────────────────────

  Future<List<int>> rerankResults({
    required AiProvider provider,
    String baseUrl = '',
    required String question,
    required List<Map<String, dynamic>> candidates,
    required String apiKey,
    required String liteModel,
  }) async {
    if (candidates.isEmpty) return [];

    final prompt = AiPromptTemplates.buildRerankPrompt(
      question: question,
      candidates: candidates,
    );

    try {
      final response = await _callLiteModel(
        provider: provider,
        baseUrl: baseUrl,
        prompt: prompt,
        apiKey: apiKey,
        liteModel: liteModel,
      );

      final text = response.text.trim();
      final json = text.startsWith('[')
          ? text
          : text
              .replaceFirst(RegExp(r'^```json\s*'), '')
              .replaceFirst(RegExp(r'\s*```$'), '');
      final parsed = jsonDecode(json) as List<dynamic>;

      final scores = <int, double>{};
      for (final item in parsed) {
        if (item is Map &&
            item.containsKey('i') &&
            item.containsKey('score')) {
          scores[(item['i'] as num).toInt()] =
              (item['score'] as num).toDouble();
        }
      }

      final ranked = <int>[];
      for (int i = 0; i < candidates.length; i++) {
        final score = scores[i] ?? 0.0;
        if (score >= 3.0) {
          ranked.add(i);
        }
      }

      ranked.sort((a, b) =>
          (scores[b] ?? 0.0).compareTo(scores[a] ?? 0.0));
      return ranked;
    } catch (e) {
      debugPrint('[AI_GEMINI] Rerank failed: $e — using original order');
      return List.generate(candidates.length, (i) => i);
    }
  }

  // ── Expand query using the lite model ───────────────────────────────

  Future<List<String>> expandQuery({
    required AiProvider provider,
    String baseUrl = '',
    required String query,
    required String apiKey,
    required String liteModel,
    int count = 3,
  }) async {
    final prompt = AiPromptTemplates.expandQueryPrompt
        .replaceFirst('{n}', count.toString())
        .replaceFirst('{query}', query);

    try {
      final response = await _callLiteModel(
        provider: provider,
        baseUrl: baseUrl,
        prompt: prompt,
        apiKey: apiKey,
        liteModel: liteModel,
      );

      final text = response.text
          .trim()
          .replaceAll(RegExp(r'^```json\s*'), '')
          .replaceAll(RegExp(r'\s*```$'), '');
      final parsed = jsonDecode(text) as List<dynamic>;
      return parsed.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('[AI_GEMINI] Query expansion failed: $e');
      return [];
    }
  }

  // ── Translate text using the lite model ───────────────────────────

  Future<String> translateToEnglish({
    required AiProvider provider,
    String baseUrl = '',
    required String text,
    required String apiKey,
    required String liteModel,
  }) async {
    if (text.trim().isEmpty) return text;

    final prompt = '''Translate the following text to English.
Return ONLY the translation, no explanations, no quotes.

Text to translate:
$text''';

    try {
      final response = await _callLiteModel(
        provider: provider,
        baseUrl: baseUrl,
        prompt: prompt,
        apiKey: apiKey,
        liteModel: liteModel,
      );
      final translated = response.text.trim();
      if (translated.isNotEmpty) return translated;
      return text;
    } catch (e) {
      debugPrint('[AI_GEMINI] Translation failed: $e');
      return text;
    }
  }

  /// Detect the language of [text] using the lite model.
  Future<String> detectLanguage({
    required AiProvider provider,
    String baseUrl = '',
    required String text,
    required String apiKey,
    required String liteModel,
  }) async {
    if (text.trim().isEmpty) return 'English';

    final prompt = '''Identify the language of the following text.
Return ONLY the language name in English (e.g., "English", "Burmese", "Thai", "Lao", "Sinhala", "Vietnamese", "Khmer", "Hindi").
Do NOT return anything else.

Text:
$text''';

    try {
      final response = await _callLiteModel(
        provider: provider,
        baseUrl: baseUrl,
        prompt: prompt,
        apiKey: apiKey,
        liteModel: liteModel,
      );
      final lang = response.text.trim();
      if (lang.isNotEmpty) return lang;
      return 'English';
    } catch (e) {
      debugPrint('[AI_GEMINI] Language detection failed: $e');
      return 'English';
    }
  }

  // ── Internal: call the lite model ───────────────────────────────────

  Future<_AiResponse> _callLiteModel({
    required AiProvider provider,
    String baseUrl = '',
    required String prompt,
    required String apiKey,
    required String liteModel,
  }) async {
    switch (provider) {
      case AiProvider.gemini:
        final payload = {
          'contents': [
            {'parts': [{'text': prompt}]},
          ],
          'generationConfig': {
            'maxOutputTokens': 1024,
            'temperature': 0.2,
          },
        };
        return _callGeminiApi(
            model: liteModel, apiKey: apiKey, payload: payload);
      case AiProvider.openai:
        return _callOpenAiApi(
          model: liteModel,
          apiKey: apiKey,
          baseUrl: baseUrl,
          systemPrompt: null,
          userPrompt: prompt,
          maxTokens: 1024,
          temperature: 0.2,
        );
    }
  }

  // ── Gemini API helpers ───────────────────────────────────────────────

  Stream<String> _geminiStream({
    required String model,
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
  }) async* {
    final payload = _geminiPayload(systemPrompt, userPrompt);

    final url = Uri.parse(
      '$_geminiBaseUrl/$model:streamGenerateContent?alt=sse&key=$apiKey',
    );

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(payload);

    final httpClient = http.Client();
    try {
      final httpResponse = await httpClient.send(request);

      if (httpResponse.statusCode != 200) {
        final errorBody = await httpResponse.stream.bytesToString();
        throw Exception(
          'API error ${httpResponse.statusCode}: ${_parseApiError(errorBody)}',
        );
      }

      await for (final line
          in httpResponse.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data: ')) continue;

        final data = trimmed.substring(6).trim();
        if (data == '[DONE]' || data == '[done]') break;
        if (data.isEmpty) continue;

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final candidates = json['candidates'] as List<dynamic>?;
          if (candidates == null || candidates.isEmpty) continue;

          final content = candidates[0]['content'] as Map<String, dynamic>?;
          if (content == null) continue;

          final parts = content['parts'] as List<dynamic>?;
          if (parts == null || parts.isEmpty) continue;

          final text = parts[0]['text'] as String?;
          if (text != null && text.isNotEmpty) {
            yield text;
          }
        } catch (e) {
          debugPrint('[AI_GEMINI] Skipping malformed SSE chunk: $e');
        }
      }
    } finally {
      httpClient.close();
    }
  }

  Map<String, dynamic> _geminiPayload(
    String systemPrompt,
    String userPrompt, {
    int maxTokens = 4096,
  }) {
    return {
      'system_instruction': {
        'parts': [{'text': systemPrompt}],
      },
      'contents': [
        {'parts': [{'text': userPrompt}]},
      ],
      'generationConfig': {
        'maxOutputTokens': maxTokens,
        'temperature': 0.3,
        'topP': 0.95,
      },
    };
  }

  Future<_AiResponse> _callGeminiApi({
    required String model,
    required String apiKey,
    required Map<String, dynamic> payload,
  }) async {
    final url =
        Uri.parse('$_geminiBaseUrl/$model:generateContent?key=$apiKey');

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final httpResponse = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        if (httpResponse.statusCode == 200) {
          final data =
              jsonDecode(httpResponse.body) as Map<String, dynamic>;
          final candidates = data['candidates'] as List<dynamic>? ?? [];
          if (candidates.isNotEmpty) {
            final parts =
                candidates[0]['content']['parts'] as List<dynamic>;
            final text = parts
                .map((p) => p['text'] as String? ?? '')
                .where((t) => t.isNotEmpty)
                .join('\n');
            return _AiResponse(text: text);
          }
          return const _AiResponse(text: '');
        } else if (httpResponse.statusCode == 429) {
          if (attempt < _maxRetries) {
            final wait =
                Duration(seconds: (pow(2, attempt + 1) * 2).toInt());
            await Future.delayed(wait);
            continue;
          }
          throw Exception('Rate limit exceeded. Try again later.');
        } else {
          if (attempt < _maxRetries) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          throw Exception(
            'API error ${httpResponse.statusCode}: ${_parseApiError(httpResponse.body)}',
          );
        }
      } on http.ClientException {
        if (attempt < _maxRetries) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        rethrow;
      }
    }

    throw Exception('Gemini API call failed after $_maxRetries retries');
  }

  // ── OpenAI-compatible helpers ────────────────────────────────────────

  Stream<String> _openaiStream({
    required String model,
    required String apiKey,
    required String baseUrl,
    required String systemPrompt,
    required String userPrompt,
  }) async* {
    final messages = <Map<String, dynamic>>[
      if (systemPrompt.isNotEmpty)
        {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ];

    final payload = {
      'model': model,
      'messages': messages,
      'stream': true,
      'max_tokens': 4096,
      'temperature': 0.3,
    };

    final effectiveBase =
        baseUrl.isNotEmpty ? baseUrl : 'https://api.openai.com/v1';
    final url = Uri.parse('$effectiveBase/chat/completions');

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..body = jsonEncode(payload);

    final httpClient = http.Client();
    try {
      final httpResponse = await httpClient.send(request);

      if (httpResponse.statusCode != 200) {
        final errorBody = await httpResponse.stream.bytesToString();
        throw Exception(
          'API error ${httpResponse.statusCode}: ${_parseApiError(errorBody)}',
        );
      }

      await for (final line
          in httpResponse.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data: ')) continue;

        final data = trimmed.substring(6).trim();
        if (data == '[DONE]' || data == '[done]') break;
        if (data.isEmpty) continue;

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final choices = json['choices'] as List<dynamic>?;
          if (choices == null || choices.isEmpty) continue;

          final delta = choices[0]['delta'] as Map<String, dynamic>?;
          if (delta == null) continue;

          final content = delta['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield content;
          }
        } catch (e) {
          // Skip malformed chunks
        }
      }
    } finally {
      httpClient.close();
    }
  }

  Future<_AiResponse> _callOpenAiApi({
    required String model,
    required String apiKey,
    required String baseUrl,
    String? systemPrompt,
    required String userPrompt,
    int maxTokens = 4096,
    double temperature = 0.3,
  }) async {
    final messages = <Map<String, dynamic>>[
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ];

    final payload = {
      'model': model,
      'messages': messages,
      'max_tokens': maxTokens,
      'temperature': temperature,
    };

    final effectiveBase =
        baseUrl.isNotEmpty ? baseUrl : 'https://api.openai.com/v1';
    final url = Uri.parse('$effectiveBase/chat/completions');

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final httpResponse = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode(payload),
        );

        if (httpResponse.statusCode == 200) {
          final data =
              jsonDecode(httpResponse.body) as Map<String, dynamic>;
          final choices = data['choices'] as List<dynamic>? ?? [];
          if (choices.isNotEmpty) {
            final message =
                choices[0]['message'] as Map<String, dynamic>? ?? {};
            final content = message['content'] as String? ?? '';
            return _AiResponse(text: content);
          }
          return const _AiResponse(text: '');
        } else if (httpResponse.statusCode == 429) {
          if (attempt < _maxRetries) {
            final wait =
                Duration(seconds: (pow(2, attempt + 1) * 2).toInt());
            await Future.delayed(wait);
            continue;
          }
          throw Exception('Rate limit exceeded. Try again later.');
        } else {
          if (attempt < _maxRetries) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          throw Exception(
            'API error ${httpResponse.statusCode}: ${_parseApiError(httpResponse.body)}',
          );
        }
      } on http.ClientException {
        if (attempt < _maxRetries) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        rethrow;
      }
    }

    throw Exception('OpenAI API call failed after $_maxRetries retries');
  }

  // ── Error parsing ────────────────────────────────────────────────────

  String _parseApiError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>?;
      if (error != null) {
        return error['message'] as String? ??
            error['status'] as String? ??
            body;
      }
      return body;
    } catch (_) {
      return body;
    }
  }
}

/// Riverpod provider for GeminiApiService.
final geminiApiServiceProvider = Provider<GeminiApiService>((ref) {
  return GeminiApiService();
});
