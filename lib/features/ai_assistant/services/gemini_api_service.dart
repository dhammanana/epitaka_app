/// Service for calling the Gemini API to generate grounded answers.
///
/// Supports two model tiers:
///   - **Render model** (e.g. gemini-2.0-flash) — generates the final
///     answer with source citations.
///   - **Lite model** (e.g. gemini-2.0-flash-lite) — fast, cheap model
///     for re-ranking search results and keyword expansion.
///
/// Uses the `google-generativeai` HTTP API directly via the `http` package.
/// No SDK dependency — just REST calls.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'ai_prompt_templates.dart';

/// Response from Gemini's generateContent endpoint.
class _GeminiResponse {
  final String text;

  const _GeminiResponse({required this.text});
}

/// Service that encapsulates Gemini API calls.
class GeminiApiService {
  GeminiApiService();

  /// Base URL for the Gemini API.
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Maximum retries for transient failures.
  static const int _maxRetries = 2;

  // ── Generate answer using the render model (streaming) ─────────────

  /// Generate a grounded answer from the render model via SSE streaming.
  ///
  /// Returns a [Stream] of text tokens as they arrive from the API.
  /// Each token is a partial text chunk that should be concatenated.
  ///
  /// [systemPrompt] — the system instruction (from AiPromptTemplates).
  /// [userPrompt] — the user turn with question + context block.
  /// [apiKey] — Gemini API key.
  /// [model] — model name (default: render model from settings).
  Stream<String> generateAnswerStream({
    required String systemPrompt,
    required String userPrompt,
    required String apiKey,
    required String model,
  }) async* {
    final payload = {
      'system_instruction': {
        'parts': [{'text': systemPrompt}],
      },
      'contents': [
        {'parts': [{'text': userPrompt}]},
      ],
      'generationConfig': {
        'maxOutputTokens': 4096,
        'temperature': 0.3,
        'topP': 0.95,
      },
    };

    final url = Uri.parse(
      '$_baseUrl/$model:streamGenerateContent?alt=sse&key=$apiKey',
    );

    // Use http.Client.send() to get a streaming response
    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(payload);

    final httpClient = http.Client();
    try {
      final httpResponse = await httpClient.send(request);

      if (httpResponse.statusCode != 200) {
        // Read the full body for error details
        final errorBody = await httpResponse.stream.bytesToString();
        throw Exception(
          'API error ${httpResponse.statusCode}: ${_parseApiError(errorBody)}',
        );
      }

      // Parse SSE events line-by-line
      await for (final line
          in httpResponse.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        final trimmed = line.trim();

        // SSE lines start with "data: "
        if (!trimmed.startsWith('data: ')) continue;

        final data = trimmed.substring(6).trim();

        // End-of-stream marker
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
          // Skip malformed JSON chunks — they're harmless
          debugPrint('[AI_GEMINI] Skipping malformed SSE chunk: $e');
        }
      }
    } finally {
      httpClient.close();
    }
  }

  /// Non-streaming convenience wrapper (used internally for rerank/expand).
  Future<String> generateAnswer({
    required String systemPrompt,
    required String userPrompt,
    required String apiKey,
    required String model,
  }) async {
    final payload = {
      'system_instruction': {
        'parts': [{'text': systemPrompt}],
      },
      'contents': [
        {'parts': [{'text': userPrompt}]},
      ],
      'generationConfig': {
        'maxOutputTokens': 4096,
        'temperature': 0.3,
        'topP': 0.95,
      },
    };

    final response = await _callApi(
      model: model,
      apiKey: apiKey,
      payload: payload,
    );

    return response.text;
  }

  // ── Rerank search results using the lite model ──────────────────────

  /// Use the lite model to score/rerank search results.
  ///
  /// Returns a list of (index, score) pairs sorted by score descending.
  /// On failure, returns the original order with default scores.
  Future<List<int>> rerankResults({
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
      final response = await _generateLite(
        prompt: prompt,
        apiKey: apiKey,
        liteModel: liteModel,
      );

      final text = response.text.trim();
      final json = text.startsWith('[') ? text : text.replaceFirst(RegExp(r'^```json\s*'), '').replaceFirst(RegExp(r'\s*```$'), '');
      final parsed = jsonDecode(json) as List<dynamic>;

      final scores = <int, double>{};
      for (final item in parsed) {
        if (item is Map && item.containsKey('i') && item.containsKey('score')) {
          scores[(item['i'] as num).toInt()] = (item['score'] as num).toDouble();
        }
      }

      // Filter out low-relevance results and sort by score descending
      final ranked = <int>[];
      for (int i = 0; i < candidates.length; i++) {
        final score = scores[i] ?? 0.0;
        if (score >= 3.0) {
          ranked.add(i);
        }
      }

      ranked.sort((a, b) => (scores[b] ?? 0.0).compareTo(scores[a] ?? 0.0));
      return ranked;
    } catch (e) {
      debugPrint('[AI_GEMINI] Rerank failed: $e — using original order');
      return List.generate(candidates.length, (i) => i);
    }
  }

  // ── Expand query using the lite model ───────────────────────────────

  /// Use the lite model to generate alternative search phrasings.
  Future<List<String>> expandQuery({
    required String query,
    required String apiKey,
    required String liteModel,
    int count = 3,
  }) async {
    final prompt = AiPromptTemplates.expandQueryPrompt
        .replaceFirst('{n}', count.toString())
        .replaceFirst('{query}', query);

    try {
      final response = await _generateLite(
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

  // ── Internal: call the lite model ───────────────────────────────────

  Future<_GeminiResponse> _generateLite({
    required String prompt,
    required String apiKey,
    required String liteModel,
  }) async {
    final payload = {
      'contents': [
        {'parts': [{'text': prompt}]},
      ],
      'generationConfig': {
        'maxOutputTokens': 1024,
        'temperature': 0.2,
      },
    };

    return _callApi(model: liteModel, apiKey: apiKey, payload: payload);
  }

  // ── Core HTTP call ──────────────────────────────────────────────────

  Future<_GeminiResponse> _callApi({
    required String model,
    required String apiKey,
    required Map<String, dynamic> payload,
  }) async {
    final url = Uri.parse('$_baseUrl/$model:generateContent?key=$apiKey');

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final httpResponse = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        if (httpResponse.statusCode == 200) {
          final data = jsonDecode(httpResponse.body) as Map<String, dynamic>;
          final candidates = data['candidates'] as List<dynamic>? ?? [];
          if (candidates.isNotEmpty) {
            final parts = candidates[0]['content']['parts'] as List<dynamic>;
            // For safety, disable basic checks on text content since reasoning models
            // can return non-text content (like usage metadata).
            final text = parts
                .map((p) => p['text'] as String? ?? '')
                .where((t) => t.isNotEmpty)
                .join('\n');
            return _GeminiResponse(text: text);
          }
          return _GeminiResponse(text: '');
        } else if (httpResponse.statusCode == 429) {
          // Rate limited — exponential backoff
          if (attempt < _maxRetries) {
            final wait = Duration(seconds: (pow(2, attempt + 1) * 2).toInt());
            debugPrint('[AI_GEMINI] Rate limited, retrying in ${wait.inSeconds}s');
            await Future.delayed(wait);
            continue;
          }
          throw Exception('Rate limit exceeded. Try again later.');
        } else if (httpResponse.statusCode == 400) {
          final body = httpResponse.body;
          debugPrint('[AI_GEMINI] Bad request: $body');
          throw Exception('Bad request: ${_parseApiError(body)}');
        } else {
          final body = httpResponse.body;
          debugPrint('[AI_GEMINI] API error ${httpResponse.statusCode}: $body');
          if (attempt < _maxRetries) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          throw Exception('API error ${httpResponse.statusCode}: ${_parseApiError(body)}');
        }
      } on http.ClientException catch (e) {
        debugPrint('[AI_GEMINI] Network error: $e');
        if (attempt < _maxRetries) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        rethrow;
      }
    }

    throw Exception('Gemini API call failed after $_maxRetries retries');
  }

  /// Extract a human-readable error message from an API error response.
  String _parseApiError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>?;
      if (error != null) {
        return error['message'] as String? ?? error['status'] as String? ?? body;
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
