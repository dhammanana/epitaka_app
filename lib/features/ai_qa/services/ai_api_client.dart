/// Shared AI API client, tool declarations and the tool-calling loop engine
/// used by both the Vīmaṃsā (AI Q&A) chat and the Gavesana AI search.
///
/// Everything that talks to the AI provider (Gemini / OpenAI-compatible) and
/// everything that drives the function-calling loop lives here so the two
/// features reuse exactly the same logic instead of duplicating it.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../shared/models/ai_provider.dart';
import '../../shared/models/ai_api_error.dart' as api_err;
import '../models/ai_qa_models.dart';
import 'ai_qa_tool_service.dart';
import '../../mcp/epitaka_tool_registry.dart';

/// Gemini default base URL.
const String kGeminiBaseUrl =
    'https://generativelanguage.googleapis.com/v1beta/models';

/// Number of retries for non-streaming API calls.
const int kAiMaxRetries = 2;

/// Thrown when an in-flight AI call is cancelled (e.g. the user pressed
/// Stop in the Translation Builder). Callers should treat this as a clean
/// cancellation, not an error, and stop the whole job.
class AiCallCancelledException implements Exception {
  const AiCallCancelledException();

  @override
  String toString() => 'AI call cancelled';
}

/// Max output tokens requested for the Translation Builder's text call
/// (matches the server's book_translator.py 65k output budget).
const int kTranslatorMaxOutputTokens = 65000;

/// Shared function declarations (tools) for AI tool calling.
///
/// Derived from [kEpitakaTools] (`features/mcp/epitaka_tool_registry.dart`),
/// the single source of truth shared by Vīmaṃsā/Gavesana and the MCP
/// server — add new tools there and both surfaces pick them up.
final List<Map<String, dynamic>> kAiToolDeclarations = geminiToolDeclarations();

/// Default system prompt for the Vīmaṃsā tool model (chat + Q&A).
const String kAiDefaultToolSystemPrompt =
    '''You are an expert research assistant for the Pāli Canon (Tipitaka).

## Available tools
1. **search_sections(query)** — Search section/sutta TITLES across the whole canon (not full text). Use this FIRST for concept questions to discover WHICH suttas discuss a topic, then open them with get_paragraph_content or get_section.
2. **get_section(book_id, para_start)** — Get ONE section's summary + its child sections + parent. Use to BROWSE down the hierarchy (vagga → sutta).
3. **get_dictionary(term)** — Definition + canon occurrences (real sentences where the term appears, with translation) for a Pāli term. Use for concept questions BEFORE searching the canon.
4. **get_dictionary_batch(terms: [...])** — Look up MULTIPLE Pāli terms in ONE call (parallel). ALWAYS use this when you need several terms — do NOT call get_dictionary once per term.
5. **search_tipitaka(query)** — Full-text search across the Tipitaka.
5. **search_tipitaka_batch(queries: [...])** — Search with MULTIPLE different terms in ONE call (parallel).
7. **search_by_category(queries, categories, [nikayas])** — Search WITHIN specific book categories ("vinaya"/"sutta"/"abhidhamma") or nikāyas ("dn"/"mn"/"sn"/"an"/"dhp"/"ja"/etc). Results are filtered to only those books.
8. **get_headings(book_id)** — Get table of contents for a book.
9. **get_books()** — List all available books with their categories.
10. **get_paragraph_content(book_id, para_start, para_end)** — Read Pāli text.
11. **get_paragraph_content_batch(ranges: [...])** — Read MULTIPLE ranges in parallel.
12. **get_commentaries(mula_book_id, mula_para_id)** — Find Aṭṭhakathā/Ṭīkā.

## The Map (section index)
- search_sections(query) finds SUTTA/SECTION titles across the whole canon — use it to discover where a topic lives BEFORE full-text search.
- get_section(book_id, para_start) shows a section's summary + its sub-sections — use it to browse down a hierarchy (vagga → sutta).
- Summaries are NAVIGATION HINTS only. Never quote from a summary in your answer; always open the real text with get_paragraph_content first.

## CRITICAL: Strategic search process
You have up to 8 tool iterations. Use them WISELY. Follow this process:

### PHASE 0: Disambiguate the concept (thinking, no tools yet)
If the question is about a broad or polysemous term:
1. List the DISTINCT SENSES of the term. (e.g. saṅkhāra → (a) khandha, (b) paṭiccasamuppāda link, (c) conditioned things / anicca teaching, (d) abhidhamma technical use.)
2. For EACH sense, note the most likely location:
   - khandha → SN 22 (Saṃyutta, Khandhavagga)
   - paṭiccasamuppāda → SN 12.2, MN 9
   - conditioned things → Dhp 277–279
   - abhidhamma → Vibhaṅga (Vbh), Dhammasaṅgaṇī (Dhs)
3. FIRST call search_sections for the term (finds sutta TITLES).
4. Then run ONE search_by_category per sense, targeted at those nikāyas.
5. Prefer passages that DEFINE the term over passages that merely use it.

### PHASE 1: Analyze the question (thinking, no tools yet)
Before searching, analyze:
- What is the UNIQUE core of this question? What makes it specific?
- Which part of the canon would contain the answer? (Vinaya for rules, Suttas for teachings, Jātakas for stories, etc.)
- What Pāli compounds or technical terms might capture the SPECIFIC concept?

### PHASE 2: Strategic search (use search_by_category FIRST)
- If you know WHERE the answer lives, use **search_by_category** to search only relevant books.
  Example: rules about monks → categories: ["vinaya"]
  Example: teachings on giving → nikayas: ["an"] (Aṅguttara has many dāna teachings)
  Example: stories → nikayas: ["ja"] (Jātaka)
- ALWAYS include SPECIFIC queries that target the unique aspect, not just generic keywords.
  BAD: ["dāna", "giving"] (returns 1000+ results, all generic)
  GOOD: ["dukkara dāna", "most difficult gift", "kicchena dāna", "supreme offering monk"]
- Terms may be Pāli OR English: Pāli terms match the Pāli text; English terms match the English translation. Include both when relevant.
- Use 3-4 queries at different specificity levels:
  1. Very specific (Pāli compound from the question's core concept)
  2. Phrase search (English description of the unique situation)
  3. Synonyms (related concepts)
  4. Broad fallback (if specific yields nothing)

### PHASE 3: Evaluate result quality
After each search batch, evaluate:
- How many results? 0-3 = too few (search again with broader terms)
- Are they actually about the user's question, or just tangentially related?
- If 30+ results and many are generic → search was too broad. Narrow down with search_by_category or more specific terms.
- If results are from wrong books → use search_by_category to correct.

### PHASE 4: Iterate until confident
- If results are insufficient → refine and search AGAIN (you have iterations)
- After finding relevant passages, read them with get_paragraph_content to confirm they answer the question.
- Use get_headings to understand the structure of a promising book before diving in.
- Only call final_answer when you have found passages that DIRECTLY address the user's question.

## CRITICAL: Pāli search stem generation
When searching for a Pāli term, ALWAYS strip the final vowel to create a stem that matches all declension forms.
- Example: "buddha" → search "buddh" (matches buddhena, buddho, buddhā, buddhassa, etc.)
- Example: "dhamma" → search "dhamm" (matches dhammaṃ, dhammā, dhammassa, etc.)
- Example: "sacca" → search "sacc" (matches saccaṃ, saccā, saccessa, etc.)
- Example: "mettā" → search "mett" (matches mettā, mettāya, mettavā, etc.)
- Exception: terms ending in consonants or -i/-u already (e.g. "pāli", "cakkhu") keep the final vowel — only strip -a/-ā endings.
- For English search terms, do NOT strip — use the full word as-is.
- This applies to ALL search tools: search_tipitaka, search_tipitaka_batch, search_by_category, and search_sections.

## CRITICAL: Referencing suttas and books
- NEVER use book_id codes (e.g. "An35.2", "SN22.1", "MN1") in search queries — these short-form identifiers are NOT searchable in the RAG index.
- To search for a specific sutta, use the FULL SUTTA NAME (without the final vowel for Pāli): e.g. for Sabbāsava Sutta, search "sabbāsav" not "An35.2" or "Sabbasav".
- To find a specific book, use get_books() to list all available books and find the correct book_id, then use get_headings(book_id) to browse its table of contents and locate the desired section by para_start.
- When the user asks about a specific sutta by Pāli name, combine the sutta name stem with a topical term for a targeted search.

## Guidelines
- When searching, use search_tipitaka_batch or search_by_category (not single search).
- When explaining several Pāli terms, batch them with get_dictionary_batch(terms) in ONE call — never call get_dictionary once per term (each call costs an API round-trip).
- Pāli terms: try compounds (e.g. "sammāsambuddha" not just "buddha").
- If search_by_category returns nothing, fall back to search_tipitaka_batch across all books.
- For commentaries, use get_commentaries with the specific passage.
- Include precise citations [book_id:para_id:line_id] for every quoted passage.''';

/// Default system prompt for the Gavesana AI search tool model.
///
/// The model plans and runs the searches (up to 10 tool calls); the passages
/// it collects are rendered as normal search results.
const String kAiSearchSystemPrompt =
    '''You are a search planner for the Pāli Canon (Tipitaka).

The user wants to FIND passages in the Tipitaka relevant to their request. Your job is to search the local database using the available tools and collect the most relevant passages — you do NOT need to write an answer or explain anything.

## Available tools
1. **search_sections(query)** — Search section/sutta TITLES across the whole canon. Use FIRST to discover which suttas discuss a topic.
2. **get_section(book_id, para_start)** — Browse one section's summary + children.
3. **get_dictionary(term)** — Definition + canon occurrences (real sentences where the term appears) for a Pāli term.
4. **get_dictionary_batch(terms: [...])** — Look up MULTIPLE Pāli terms in ONE call (parallel). ALWAYS use this for several terms — do NOT call get_dictionary once per term.
5. **search_tipitaka(query)** — Full-text search across the Tipitaka.
6. **search_tipitaka_batch(queries: [...])** — Search with MULTIPLE terms in ONE call (parallel).
7. **search_by_category(queries, categories, [nikayas])** — Search within specific books ("vinaya"/"sutta"/"abhidhamma", or nikāyas like "dn"/"mn"/"sn"/"an"/"dhp"/"ja").
8. **get_headings(book_id)** — Table of contents for a book.
9. **get_paragraph_content(book_id, para_start, para_end)** — Read Pāli text.
10. **get_paragraph_content_batch(ranges: [...])** — Read multiple ranges in parallel.

## CRITICAL: Pāli search stem generation
When searching for a Pāli term, ALWAYS strip the final vowel to create a stem that matches all declension forms.
- Example: "buddha" → search "buddh" (matches buddhena, buddho, buddhā, buddhassa, etc.)
- Example: "dhamma" → search "dhamm" (matches dhammaṃ, dhammā, dhammassa, etc.)
- Example: "sacca" → search "sacc" (matches saccaṃ, saccā, saccessa, etc.)
- Example: "mettā" → search "mett" (matches mettā, mettāya, mettavā, etc.)
- Exception: terms ending in consonants or -i/-u already (e.g. "pāli", "cakkhu") keep the final vowel — only strip -a/-ā endings.
- For English search terms, do NOT strip — use the full word as-is.
- This applies to ALL search tools: search_tipitaka, search_tipitaka_batch, search_by_category, and search_sections.

## CRITICAL: Referencing suttas and books
- NEVER use book_id codes (e.g. "An35.2", "SN22.1", "MN1") in search queries — these short-form identifiers are NOT searchable in the RAG index.
- To search for a specific sutta, use the FULL SUTTA NAME (without the final vowel for Pāli): e.g. for Sabbāsava Sutta, search "sabbāsav" not "An35.2" or "Sabbasav".
- To find a specific book, use get_books() to list all available books and find the correct book_id, then use get_headings(book_id) to browse its table of contents and locate the desired section by para_start.
- When the user asks about a specific sutta by Pāli name, combine the sutta name stem with a topical term for a targeted search.

## Strategy
- Analyze the request: what is unique/specific about it, and where in the canon would the answer live?
- When you need definitions of several Pāli terms, batch them with get_dictionary_batch(terms) in ONE call — never call get_dictionary once per term.
- Use search_sections first for concept questions to discover which suttas discuss the topic.
- Use search_tipitaka_batch or search_by_category with 3-4 SPECIFIC Pāli and English terms (compounds, synonyms, phrase-level descriptions). Avoid single generic keywords.
- Terms may be Pāli OR English: Pāli terms match the Pāli text, English terms match the English translation. Include both when relevant — a concept often appears only in the translation.
- If a search returns too few results, broaden; if too many generic ones, narrow with search_by_category.
- Read promising passages with get_paragraph_content to confirm they are relevant.
- You have up to 10 tool calls. Use them wisely; stop once you have gathered enough passages.
- When you have collected enough relevant passages, call **final_answer** with a brief summary of what you found. The passages you gathered will be shown to the user as search results.''';

/// Result of one non-streaming tool-model call.
class AiToolCallResult {
  final List<Map<String, dynamic>> callSpecs; // {name, args}
  final bool hasFinalAnswer;
  final bool hasTextResponse;
  final String? textResponse;

  const AiToolCallResult({
    required this.callSpecs,
    required this.hasFinalAnswer,
    required this.hasTextResponse,
    this.textResponse,
  });
}

/// Shared client for talking to the AI providers (Gemini / OpenAI-compatible).
class AiApiClient {
  /// Call the tool model with function declarations (non-streaming).
  ///
  /// Returns the raw Gemini-style response map:
  /// `{'candidates': [{'content': {'parts': [...]}}]}` — OpenAI responses are
  /// adapted to this shape by [_callOpenAiApiRaw].
  static Future<Map<String, dynamic>> callToolModel({
    required AiProvider provider,
    String baseUrl = '',
    required String systemPrompt,
    required List<Map<String, dynamic>> conversation,
    required List<Map<String, dynamic>> toolDeclarations,
    required String apiKey,
    required String toolModel,
    String logTag = 'AI',
    Future<void>? cancelSignal,
  }) async {
    final payload = buildToolPayload(
      provider: provider,
      systemPrompt: systemPrompt,
      conversation: conversation,
      toolDeclarations: toolDeclarations,
    );

    final payloadSize = utf8.encode(jsonEncode(payload)).length;
    debugPrint(
      '[$logTag] callToolModel: $toolModel | '
      'contents=${conversation.length} | '
      'payload=~${(payloadSize / 1024).toStringAsFixed(1)}KB',
    );

    switch (provider) {
      case AiProvider.gemini:
        final response = await _callGeminiApi(
          model: toolModel,
          apiKey: apiKey,
          payload: payload,
          logTag: logTag,
          cancelSignal: cancelSignal,
        );
        return jsonDecode(response) as Map<String, dynamic>;
      case AiProvider.claude:
        final response = await _callClaudeApiRaw(
          model: toolModel,
          apiKey: apiKey,
          baseUrl: baseUrl.isNotEmpty ? baseUrl : provider.defaultBaseUrl,
          payload: {...payload, 'model': toolModel},
          logTag: logTag,
          cancelSignal: cancelSignal,
        );
        return jsonDecode(response) as Map<String, dynamic>;
      case AiProvider.openai:
      case AiProvider.openrouter:
      case AiProvider.deepseek:
        // OpenRouter and DeepSeek speak the OpenAI chat-completions
        // protocol, so all three share the same code path (only the
        // base URL differs).
        final response = await _callOpenAiApiRaw(
          model: toolModel,
          apiKey: apiKey,
          baseUrl: baseUrl.isNotEmpty ? baseUrl : provider.defaultBaseUrl,
          payload: {...payload, 'model': toolModel},
          logTag: logTag,
          cancelSignal: cancelSignal,
        );
        return jsonDecode(response) as Map<String, dynamic>;
    }
  }

  /// Plain text-generation call (no tools) used by the on-device Translation
  /// Builder. Mirrors the server's `call_gemini` in book_translator.py: send
  /// a system prompt + one user prompt, get back the raw text content.
  ///
  /// Returns the model's text reply (may contain JSON — callers use
  /// [parseTranslatorJsonResponse] on it). Throws on unrecoverable errors
  /// after retrying transient failures (429 / 5xx / connection drops), the
  /// same policy as the tool-model calls.
  ///
  /// [cancelSignal] (optional) aborts the in-flight call the moment it
  /// completes — the pending HTTP request races it and throws
  /// [AiCallCancelledException] instead of waiting for the response. This is
  /// how the Translation Builder's Stop button interrupts a long chunk.
  /// [timeout] bounds each HTTP attempt so a hung request can't block a run
  /// forever; transient timeouts are retried like other failures.
  static Future<String> callTextModel({
    required AiProvider provider,
    String baseUrl = '',
    required String systemPrompt,
    required String userPrompt,
    required String apiKey,
    required String model,
    int maxOutputTokens = kTranslatorMaxOutputTokens,
    String logTag = 'TRANSLATOR',
    Future<void>? cancelSignal,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    switch (provider) {
      case AiProvider.gemini:
        final payload = {
          'system_instruction': {
            'parts': [
              {'text': systemPrompt},
            ],
          },
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': userPrompt},
              ],
            },
          ],
          'generationConfig': {
            'maxOutputTokens': maxOutputTokens,
            'temperature': 0.3,
          },
        };
        final response = await _callGeminiApi(
          model: model,
          apiKey: apiKey,
          payload: payload,
          logTag: logTag,
          cancelSignal: cancelSignal,
          timeout: timeout,
        );
        final data = jsonDecode(response) as Map<String, dynamic>;
        return _extractGeminiText(data);
      case AiProvider.claude:
        final claudePayload = {
          'model': model,
          'max_tokens': maxOutputTokens,
          'system': systemPrompt,
          'messages': [
            {'role': 'user', 'content': userPrompt},
          ],
        };
        final claudeResponse = await _callClaudeApiRaw(
          model: model,
          apiKey: apiKey,
          baseUrl: baseUrl.isNotEmpty ? baseUrl : provider.defaultBaseUrl,
          payload: claudePayload,
          logTag: logTag,
          cancelSignal: cancelSignal,
          timeout: timeout,
        );
        final claudeData = jsonDecode(claudeResponse) as Map<String, dynamic>;
        return _extractGeminiText(claudeData);
      case AiProvider.openai:
      case AiProvider.openrouter:
      case AiProvider.deepseek:
        final payload = {
          'model': model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'max_tokens': maxOutputTokens,
          'temperature': 0.3,
        };
        final response = await _callOpenAiApiRaw(
          model: model,
          apiKey: apiKey,
          baseUrl: baseUrl.isNotEmpty ? baseUrl : provider.defaultBaseUrl,
          payload: payload,
          logTag: logTag,
          cancelSignal: cancelSignal,
          timeout: timeout,
        );
        // _callOpenAiApiRaw adapts the OpenAI response into the Gemini
        // shape (candidates[].content.parts[].text) for the tool pipeline;
        // for a plain text call we just read the text back out of that.
        final data = jsonDecode(response) as Map<String, dynamic>;
        return _extractGeminiText(data);
    }
  }

  /// Race [operation] against [cancelSignal]: whichever completes first
  /// wins. A completed cancel signal throws [AiCallCancelledException].
  /// Public so the tool loop can race local DB tool execution too.
  static Future<T> raceAiCancel<T>(
    Future<T> operation,
    Future<void>? cancelSignal,
  ) {
    return _raceCancel(operation, cancelSignal);
  }

  static Future<T> _raceCancel<T>(
    Future<T> operation,
    Future<void>? cancelSignal,
  ) {
    if (cancelSignal == null) return operation;
    return Future.any<T>([
      operation,
      cancelSignal.then((_) => throw const AiCallCancelledException()),
    ]);
  }

  /// Extract the concatenated text from a Gemini `generateContent` response.
  static String _extractGeminiText(Map<String, dynamic> data) {
    final candidates = data['candidates'] as List<dynamic>? ?? [];
    if (candidates.isEmpty) return '';
    final content = candidates[0]['content'] as Map<String, dynamic>?;
    if (content == null) return '';
    final parts = content['parts'] as List<dynamic>? ?? [];
    final buf = StringBuffer();
    for (final p in parts) {
      if (p is Map && p['text'] is String) {
        buf.write(p['text'] as String);
      }
    }
    return buf.toString();
  }

  /// Defensive parse of the AI's JSON reply into a dict whose values are
  /// lists, defaulting missing keys to []. Port of the server's
  /// `ai_client.parse_ai_json_response`:
  ///   1. strip ``` markdown fences;
  ///   2. try a straight jsonDecode of the outermost {...} span;
  ///   3. on failure (truncated output), scan for each `"key": [` marker
  ///      and re-parse individual `{...}` objects inside the array — this
  ///      salvages every complete item even when the array is cut off.
  static Map<String, dynamic> parseTranslatorJsonResponse(
    String raw,
    List<String> keys,
  ) {
    var cleaned = raw.trim();
    cleaned = cleaned.replaceFirst(
      RegExp(r'^\s*```[a-zA-Z]*\s*\n?', multiLine: true),
      '',
    );
    cleaned = cleaned.replaceFirst(
      RegExp(r'\n?\s*```\s*$', multiLine: true),
      '',
    );
    cleaned = cleaned.trim();

    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start != -1 && end > start) {
      try {
        final obj =
            jsonDecode(cleaned.substring(start, end + 1))
                as Map<String, dynamic>;
        for (final key in keys) {
          obj.putIfAbsent(key, () => <dynamic>[]);
        }
        return obj;
      } on FormatException {
        // Fall through to the per-key scan below.
      }
    }

    final obj = <String, dynamic>{for (final key in keys) key: <dynamic>[]};
    for (final key in keys) {
      final m = RegExp('"$key"\\s*:\\s*\\[').firstMatch(cleaned);
      if (m == null) continue;
      final arrayStart = m.end - 1;
      var depth = 0;
      int? objStart;
      final items = <dynamic>[];
      for (var i = arrayStart; i < cleaned.length; i++) {
        final ch = cleaned[i];
        if (ch == '{') {
          if (depth == 0) objStart = i;
          depth++;
        } else if (ch == '}') {
          depth--;
          if (depth == 0 && objStart != null) {
            try {
              items.add(jsonDecode(cleaned.substring(objStart, i + 1)));
            } on FormatException {
              // Skip broken item.
            }
            objStart = null;
          }
        } else if (ch == ']' && depth == 0) {
          break;
        }
      }
      obj[key] = items;
    }
    return obj;
  }

  /// Build the request payload for the tool model, adapting to the provider.
  static Map<String, dynamic> buildToolPayload({
    required AiProvider provider,
    required String systemPrompt,
    required List<Map<String, dynamic>> conversation,
    required List<Map<String, dynamic>> toolDeclarations,
  }) {
    switch (provider) {
      case AiProvider.gemini:
        return {
          'system_instruction': {
            'parts': [
              {'text': systemPrompt},
            ],
          },
          'contents': conversation,
          'tools': [
            {'functionDeclarations': toolDeclarations},
          ],
          'generationConfig': {'maxOutputTokens': 2048, 'temperature': 0.3},
        };
      case AiProvider.claude:
        // Convert Gemini-style conversation to Anthropic messages format.
        // Tool results are flattened to text (same simplification as the
        // OpenAI path) so the tool loop stays provider-agnostic.
        final claudeMessages = <Map<String, dynamic>>[];
        for (final msg in conversation) {
          final role = msg['role'] as String? ?? 'user';
          final parts = msg['parts'] as List<dynamic>? ?? [];
          final text = parts
              .map((p) {
                if (p is Map && p['text'] is String) return p['text'] as String;
                if (p is Map && p['functionResponse'] is Map) {
                  final fr = p['functionResponse'] as Map;
                  final resp = fr['response'];
                  var content = '';
                  if (resp is Map && resp['content'] is String) {
                    content = resp['content'] as String;
                  }
                  return '[Tool result: ${fr['name']}]\n$content';
                }
                return '';
              })
              .join('\n')
              .trim();
          if (text.isNotEmpty) {
            claudeMessages.add({
              'role': role == 'model' ? 'assistant' : 'user',
              'content': text,
            });
          }
        }
        // Convert Gemini function declarations to Anthropic tools format.
        final claudeTools = toolDeclarations
            .where((d) => (d['name'] as String? ?? '') != 'final_answer')
            .map((d) {
              return {
                'name': d['name'],
                'description': d['description'],
                'input_schema': d['parameters'] ?? {'type': 'object'},
              };
            })
            .toList();

        return {
          'model': '',
          'max_tokens': 2048,
          'system': systemPrompt,
          'messages': claudeMessages,
          'tools': claudeTools,
        };
      case AiProvider.openai:
      case AiProvider.openrouter:
      case AiProvider.deepseek:
        // Convert Gemini-style conversation to OpenAI messages format
        final messages = <Map<String, dynamic>>[];
        messages.add({'role': 'system', 'content': systemPrompt});
        for (final msg in conversation) {
          final role = msg['role'] as String? ?? 'user';
          final parts = msg['parts'] as List<dynamic>? ?? [];
          final text = parts
              .map((p) {
                if (p is Map && p['text'] is String) return p['text'] as String;
                if (p is Map && p['functionResponse'] is Map) {
                  final fr = p['functionResponse'] as Map;
                  return '[Tool result: ${fr['name']}]';
                }
                return '';
              })
              .join('\n');
          if (text.isNotEmpty) {
            messages.add({
              'role': role == 'model' ? 'assistant' : role,
              'content': text,
            });
          }
        }
        // Convert Gemini function declarations to OpenAI tools format
        final openaiTools = toolDeclarations.map((d) {
          return {
            'type': 'function',
            'function': {
              'name': d['name'],
              'description': d['description'],
              'parameters': d['parameters'],
            },
          };
        }).toList();

        return {
          'model': '',
          'messages': messages,
          'tools': openaiTools,
          'tool_choice': 'auto',
          'max_tokens': 2048,
          'temperature': 0.3,
        };
    }
  }

  /// Gemini-style non-streaming API call.
  static Future<String> _callGeminiApi({
    required String model,
    required String apiKey,
    required Map<String, dynamic> payload,
    String logTag = 'AI',
    Future<void>? cancelSignal,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final url = Uri.parse('$kGeminiBaseUrl/$model:generateContent?key=$apiKey');

    for (int attempt = 0; attempt <= kAiMaxRetries; attempt++) {
      try {
        final apiStopwatch = Stopwatch()..start();
        final httpResponse = await _raceCancel(
          http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          ),
          cancelSignal,
        ).timeout(timeout);
        final apiDuration = apiStopwatch.elapsedMilliseconds;

        if (httpResponse.statusCode == 200) {
          debugPrint(
            '[$logTag] API $model: 200 OK (${apiDuration}ms, '
            '${(httpResponse.body.length / 1024).toStringAsFixed(1)}KB)',
          );
          return httpResponse.body;
        } else if (httpResponse.statusCode == 429) {
          if (attempt < kAiMaxRetries) {
            final wait = Duration(seconds: (pow(2, attempt + 1) * 2).toInt());
            await _raceCancel(Future.delayed(wait), cancelSignal);
            continue;
          }
          throw Exception('Rate limit exceeded. Try again later.');
        } else {
          if (attempt < kAiMaxRetries) {
            await _raceCancel(
              Future.delayed(const Duration(seconds: 2)),
              cancelSignal,
            );
            continue;
          }
          final apiMessage = parseApiError(httpResponse.body);
          throw Exception('API error ${httpResponse.statusCode}: $apiMessage');
        }
      } on AiCallCancelledException {
        rethrow; // Never retry after a user cancel.
      } on http.ClientException {
        if (attempt < kAiMaxRetries) {
          await _raceCancel(
            Future.delayed(const Duration(seconds: 2)),
            cancelSignal,
          );
          continue;
        }
        rethrow;
      } on TimeoutException {
        // A slow (not hung) request shouldn't kill the run — retry, and
        // only give up once every attempt has timed out.
        if (attempt < kAiMaxRetries) {
          await _raceCancel(
            Future.delayed(const Duration(seconds: 2)),
            cancelSignal,
          );
          continue;
        }
        throw Exception('API request timed out after $timeout');
      }
    }

    throw Exception('API call failed after $kAiMaxRetries retries');
  }

  /// OpenAI-compatible non-streaming API call (raw response for tool pipeline).
  ///
  /// The OpenAI response is adapted to the Gemini shape the tool loop expects
  /// (`candidates[0].content.parts` with `functionCall` entries).
  static Future<String> _callOpenAiApiRaw({
    required String model,
    required String apiKey,
    required String baseUrl,
    required Map<String, dynamic> payload,
    String logTag = 'AI',
    Future<void>? cancelSignal,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final url = _chatCompletionsUri(baseUrl);

    for (int attempt = 0; attempt <= kAiMaxRetries; attempt++) {
      try {
        final apiStopwatch = Stopwatch()..start();
        final httpResponse = await _raceCancel(
          http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(payload),
          ),
          cancelSignal,
        ).timeout(timeout);
        final apiDuration = apiStopwatch.elapsedMilliseconds;

        if (httpResponse.statusCode == 200) {
          debugPrint(
            '[$logTag] API $model: 200 OK (${apiDuration}ms, '
            '${(httpResponse.body.length / 1024).toStringAsFixed(1)}KB)',
          );
          // Parse the OpenAI response and wrap it in a format compatible
          // with the tool pipeline (which expects Gemini-like structure).
          final data = jsonDecode(httpResponse.body) as Map<String, dynamic>;
          final choices = data['choices'] as List<dynamic>? ?? [];
          if (choices.isNotEmpty) {
            final message =
                choices[0]['message'] as Map<String, dynamic>? ?? {};
            final content = message['content'] as String? ?? '';
            final toolCalls = message['tool_calls'] as List<dynamic>?;

            // Build a response that the tool pipeline can parse
            final parts = <Map<String, dynamic>>[];
            if (content.isNotEmpty) {
              parts.add({'text': content});
            }
            if (toolCalls != null) {
              for (final tc in toolCalls) {
                final tcMap = tc as Map<String, dynamic>;
                parts.add({
                  'functionCall': {
                    'name': tcMap['function']['name'],
                    'args': jsonDecode(
                      tcMap['function']['arguments'] as String,
                    ),
                  },
                });
              }
            }

            final adaptedResponse = {
              'candidates': [
                {
                  'content': {'parts': parts, 'role': 'model'},
                  'finishReason': message['finish_reason'] ?? 'STOP',
                },
              ],
            };
            return jsonEncode(adaptedResponse);
          }
          return httpResponse.body;
        } else if (httpResponse.statusCode == 429) {
          if (attempt < kAiMaxRetries) {
            final wait = Duration(seconds: (pow(2, attempt + 1) * 2).toInt());
            await _raceCancel(Future.delayed(wait), cancelSignal);
            continue;
          }
          throw Exception('Rate limit exceeded. Try again later.');
        } else {
          if (attempt < kAiMaxRetries) {
            await _raceCancel(
              Future.delayed(const Duration(seconds: 2)),
              cancelSignal,
            );
            continue;
          }
          final apiMessage = parseApiError(httpResponse.body);
          throw Exception('API error ${httpResponse.statusCode}: $apiMessage');
        }
      } on AiCallCancelledException {
        rethrow; // Never retry after a user cancel.
      } on http.ClientException {
        if (attempt < kAiMaxRetries) {
          await _raceCancel(
            Future.delayed(const Duration(seconds: 2)),
            cancelSignal,
          );
          continue;
        }
        rethrow;
      } on TimeoutException {
        if (attempt < kAiMaxRetries) {
          await _raceCancel(
            Future.delayed(const Duration(seconds: 2)),
            cancelSignal,
          );
          continue;
        }
        throw Exception('API request timed out after $timeout');
      }
    }

    throw Exception('API call failed after $kAiMaxRetries retries');
  }

  /// Anthropic Messages API non-streaming call (raw response for the tool
  /// pipeline). The response is adapted to the Gemini shape the tool loop
  /// expects (`candidates[0].content.parts` with `text` / `functionCall`).
  static Future<String> _callClaudeApiRaw({
    required String model,
    required String apiKey,
    required String baseUrl,
    required Map<String, dynamic> payload,
    String logTag = 'AI',
    Future<void>? cancelSignal,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final url = _claudeMessagesUri(baseUrl);
    final body = {...payload, 'model': model};

    for (int attempt = 0; attempt <= kAiMaxRetries; attempt++) {
      try {
        final apiStopwatch = Stopwatch()..start();
        final httpResponse = await _raceCancel(
          http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode(body),
          ),
          cancelSignal,
        ).timeout(timeout);
        final apiDuration = apiStopwatch.elapsedMilliseconds;

        if (httpResponse.statusCode == 200) {
          debugPrint(
            '[$logTag] API $model: 200 OK (${apiDuration}ms, '
            '${(httpResponse.body.length / 1024).toStringAsFixed(1)}KB)',
          );
          final data = jsonDecode(httpResponse.body) as Map<String, dynamic>;
          final content = data['content'] as List<dynamic>? ?? [];
          final parts = <Map<String, dynamic>>[];
          for (final block in content) {
            final b = block as Map<String, dynamic>? ?? {};
            final type = b['type'] as String? ?? '';
            if (type == 'text') {
              final text = b['text'] as String? ?? '';
              if (text.isNotEmpty) parts.add({'text': text});
            } else if (type == 'tool_use') {
              parts.add({
                'functionCall': {
                  'name': b['name'],
                  'args': (b['input'] as Map<String, dynamic>?) ?? {},
                },
              });
            }
          }
          final adaptedResponse = {
            'candidates': [
              {
                'content': {'parts': parts, 'role': 'model'},
                'finishReason': data['stop_reason'] ?? 'STOP',
              },
            ],
          };
          return jsonEncode(adaptedResponse);
        } else if (httpResponse.statusCode == 429) {
          if (attempt < kAiMaxRetries) {
            final wait = Duration(seconds: (pow(2, attempt + 1) * 2).toInt());
            await _raceCancel(Future.delayed(wait), cancelSignal);
            continue;
          }
          throw Exception('Rate limit exceeded. Try again later.');
        } else {
          if (attempt < kAiMaxRetries) {
            await _raceCancel(
              Future.delayed(const Duration(seconds: 2)),
              cancelSignal,
            );
            continue;
          }
          final apiMessage = parseApiError(httpResponse.body);
          throw Exception('API error ${httpResponse.statusCode}: $apiMessage');
        }
      } on AiCallCancelledException {
        rethrow;
      } on http.ClientException {
        if (attempt < kAiMaxRetries) {
          await _raceCancel(
            Future.delayed(const Duration(seconds: 2)),
            cancelSignal,
          );
          continue;
        }
        rethrow;
      } on TimeoutException {
        if (attempt < kAiMaxRetries) {
          await _raceCancel(
            Future.delayed(const Duration(seconds: 2)),
            cancelSignal,
          );
          continue;
        }
        throw Exception('API request timed out after $timeout');
      }
    }

    throw Exception('API call failed after $kAiMaxRetries retries');
  }

  /// Normalise a user-pasted base URL: strip trailing slashes and any
  /// endpoint suffix (`/chat/completions`, `/messages`, …) so callers can
  /// safely append the endpoint they need. Copied from anx-reader's
  /// `_deriveBaseUrl` idea.
  static String _normalizeBaseUrl(String baseUrl, String fallback) {
    var value = baseUrl.trim();
    if (value.isEmpty) value = fallback;
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    const removable = {
      '/chat/completions',
      '/chat/completion',
      '/completions',
      '/messages',
      '/responses',
    };
    for (final suffix in removable) {
      if (value.toLowerCase().endsWith(suffix)) {
        value = value.substring(0, value.length - suffix.length);
        break;
      }
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  /// Resolve a provider base URL to its chat-completions endpoint.
  /// Accept both `https://host/v1` and a URL already ending in
  /// `/chat/completions`; this avoids producing `/chat/completions/chat/completions`
  /// when users paste a full endpoint.
  static Uri _chatCompletionsUri(String baseUrl) {
    final value = _normalizeBaseUrl(baseUrl, 'https://api.openai.com/v1');
    return Uri.parse('$value/chat/completions');
  }

  /// Resolve a base URL to the Anthropic `/messages` endpoint.
  static Uri _claudeMessagesUri(String baseUrl) {
    final value = _normalizeBaseUrl(baseUrl, 'https://api.anthropic.com/v1');
    return Uri.parse('$value/messages');
  }

  /// Public helper for streaming callers (answer phase) to resolve the
  /// Anthropic endpoint without duplicating normalisation logic.
  static Uri claudeMessagesUri(String baseUrl) => _claudeMessagesUri(baseUrl);

  /// Extract a human-readable error message from an API error body.
  /// Handles OpenAI (`{error: {message}}`) and Anthropic
  /// (`{type: 'error', error: {message}}` / `{message: ...}`) shapes.
  static String parseApiError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        return error['message'] as String? ??
            error['status'] as String? ??
            error['type'] as String? ??
            body;
      }
      if (error is String && error.isNotEmpty) return error;
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
      return body;
    } on FormatException {
      return body;
    }
  }

  static api_err.AiApiErrorInfo describeError(
    Object error, {
    AiProvider? provider,
  }) => api_err.describeAiError(error, provider: provider);

  /// Translate raw errors into a friendly, actionable message for the user.
  static String friendlyErrorMessage(Object error, {AiProvider? provider}) {
    return describeError(error, provider: provider).displayMessage;
  }
}

/// Build a short human-readable summary of a tool call for UI logs.
String buildToolLogSummary(
  String name,
  Map<String, dynamic> args,
  ToolResult result,
) {
  if (!result.success) {
    return '❌ ${result.errorMessage ?? "Unknown error"}';
  }

  int resultCount = 0;
  try {
    final parsed = jsonDecode(result.data);
    if (parsed is List) {
      resultCount = parsed.length;
    } else if (parsed is Map && parsed['headings'] is List) {
      resultCount = (parsed['headings'] as List).length;
    } else if (parsed is Map && parsed['books'] is List) {
      resultCount = (parsed['books'] as List).length;
    } else if (parsed is Map && parsed['results'] is List) {
      resultCount = (parsed['results'] as List).length;
    } else if (parsed is Map && parsed['paragraphs'] is List) {
      resultCount = (parsed['paragraphs'] as List).length;
    } else if (parsed is Map && parsed['children'] is List) {
      resultCount = (parsed['children'] as List).length;
    }
  } catch (_) {}

  switch (name) {
    case 'search_tipitaka':
      final query = args['query'] as String? ?? '';
      final queryShort = query.length > 40
          ? '${query.substring(0, 40)}…'
          : query;
      if (resultCount > 0) {
        return '🔍 "$queryShort" → $resultCount results';
      }
      return '🔍 "$queryShort" (${result.data.length} chars)';
    case 'search_tipitaka_batch':
      final queries =
          (args['queries'] as List<dynamic>?)
              ?.map((q) => q.toString())
              .toList() ??
          [];
      final queriesStr = queries
          .map((q) => q.length > 20 ? '${q.substring(0, 20)}…' : q)
          .join(', ');
      return '🔍 Batch[$resultCount results] ($queriesStr)';
    case 'search_by_category':
      final cats =
          (args['categories'] as List<dynamic>?)
              ?.map((c) => c.toString())
              .toList() ??
          [];
      final niks =
          (args['nikayas'] as List<dynamic>?)
              ?.map((n) => n.toString())
              .toList() ??
          [];
      final scope = [...cats, ...niks];
      final scopeStr = scope.isEmpty ? 'all' : scope.join(', ');
      return '🔍 $scopeStr[$resultCount results]';
    case 'search_sections':
      final query = args['query'] as String? ?? '';
      return '🗂️ "$query" → $resultCount sections';
    case 'get_section':
      final bookId = args['book_id'] as String? ?? '';
      final paraStart = args['para_start'] ?? 0;
      return '🗺️ $bookId §$paraStart → $resultCount children';
    case 'get_dictionary':
      final term = args['term'] as String? ?? '';
      return '📖 "$term" → $resultCount entries';
    case 'get_dictionary_batch':
      final terms =
          (args['terms'] as List<dynamic>?)
              ?.map((t) => t.toString())
              .toList() ??
          [];
      final termsStr = terms
          .map((t) => t.length > 18 ? '${t.substring(0, 18)}…' : t)
          .join(', ');
      return '📖 Batch[$resultCount] ($termsStr)';
    case 'get_headings':
      final bookId = args['book_id'] as String? ?? '';
      return '📋 $bookId — $resultCount headings';
    case 'get_books':
      return '📚 $resultCount books';
    case 'get_paragraph_content':
      final bookId = args['book_id'] as String? ?? '';
      final start = args['para_start'] ?? 0;
      final end = args['para_end'] ?? 0;
      return '📖 $bookId §$start–$end (${result.data.length} chars)';
    case 'get_paragraph_content_batch':
      return '📖 Batch $resultCount ranges (${result.data.length} chars)';
    case 'get_commentaries':
      final bookId = args['mula_book_id'] as String? ?? '';
      final paraId = args['mula_para_id'] ?? 0;
      return '📝 Commentary on $bookId §$paraId: $resultCount found';
    default:
      return '$name completed (${result.data.length} chars)';
  }
}

/// Result of a complete tool loop run.
class AiToolLoopResult {
  final List<ToolCallLog> toolLogs;
  final List<Map<String, dynamic>> allToolResults;
  final List<Map<String, dynamic>> conversation;
  final List<Map<String, dynamic>> debugToolSteps;
  final int iterationsUsed;

  const AiToolLoopResult({
    required this.toolLogs,
    required this.allToolResults,
    required this.conversation,
    required this.debugToolSteps,
    required this.iterationsUsed,
  });
}

/// Execute one tool by name via [AiQaToolService] (shared dispatch).
Future<ToolResult> executeAiTool(
  Ref ref,
  String name,
  Map<String, dynamic> args,
) async {
  final service = ref.read(aiQaToolServiceProvider);
  return dispatchTool(service, name, args);
}

/// Run the tool-calling loop: repeatedly call the tool model, execute any
/// requested tools in parallel, feed the results back, and repeat until the
/// model calls `final_answer`, stops requesting tools, or [maxIterations] is
/// reached.
///
/// [initialConversation] must already contain the user's message(s).
/// [executeTool] runs a single tool against the local databases.
/// [onToolUpdate] (optional) is called with the accumulated log whenever the
/// tool calls change, so callers can render live progress.
Future<AiToolLoopResult> runAiToolLoop({
  required AiQaSettings settings,
  required String systemPrompt,
  required List<Map<String, dynamic>> initialConversation,
  required Future<ToolResult> Function(String name, Map<String, dynamic> args)
  executeTool,
  void Function(List<ToolCallLog> logs)? onToolUpdate,
  int maxIterations = 8,
  String logTag = 'AI',
  Future<void>? cancelSignal,
}) async {
  final conversation = [...initialConversation];
  final allToolResults = <Map<String, dynamic>>[];
  final toolLogs = <ToolCallLog>[];
  final debugToolSteps = <Map<String, dynamic>>[];

  bool toolsDone = false;
  int iterations = 0;

  while (!toolsDone && iterations < maxIterations) {
    iterations++;

    final toolResponse = await AiApiClient.callToolModel(
      provider: settings.provider,
      baseUrl: settings.baseUrl,
      systemPrompt: systemPrompt,
      conversation: conversation,
      toolDeclarations: kAiToolDeclarations,
      apiKey: settings.apiKey,
      toolModel: settings.toolModel,
      logTag: logTag,
      cancelSignal: cancelSignal,
    );

    final parsed = toolResponse['candidates'] as List<dynamic>?;
    if (parsed == null || parsed.isEmpty) {
      throw Exception('Empty response from tool model');
    }

    final candidate = parsed[0] as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>?;
    if (content == null) break;

    final parts = content['parts'] as List<dynamic>? ?? [];
    bool hasFunctionCall = false;
    final functionResponses = <Map<String, dynamic>>[];

    // Preserve the ENTIRE model response
    conversation.add(Map<String, dynamic>.from(content));

    // ── PHASE 1: Collect all function calls ──
    final callSpecs = <({String name, Map<String, dynamic> args})>[];
    bool hasFinalAnswer = false;
    bool hasTextResponse = false;

    for (final part in parts) {
      final p = part as Map<String, dynamic>;
      if (p.containsKey('functionCall')) {
        hasFunctionCall = true;
        final fc = Map<String, dynamic>.from(
          p['functionCall'] as Map<String, dynamic>,
        );
        final name = fc['name'] as String? ?? '';
        final args = fc['args'] as Map<String, dynamic>? ?? {};

        if (name == 'final_answer') {
          hasFinalAnswer = true;
        } else {
          callSpecs.add((name: name, args: args));
        }
      } else if (p.containsKey('text')) {
        final textResponse = p['text'] as String? ?? '';
        if (textResponse.isNotEmpty) {
          hasTextResponse = true;
        }
      }
    }

    // ── PHASE 2: Execute all collected tools in PARALLEL ──────
    if (callSpecs.isNotEmpty) {
      for (final spec in callSpecs) {
        toolLogs.add(
          ToolCallLog(
            toolName: spec.name,
            arguments: spec.args,
            resultSummary: spec.name.contains('search')
                ? '🔍 ${spec.args['query'] ?? spec.args['queries'] ?? "..."}'
                : 'Calling ${spec.name}...',
          ),
        );
      }
      onToolUpdate?.call([...toolLogs]);

      final results = await AiApiClient.raceAiCancel(
        Future.wait(
          callSpecs.map((spec) async {
            try {
              return await executeTool(spec.name, spec.args);
            } catch (e) {
              return ToolResult(
                success: false,
                data: '{}',
                errorMessage: 'Tool execution error: $e',
              );
            }
          }),
        ),
        cancelSignal,
      );

      for (int i = 0; i < callSpecs.length; i++) {
        final spec = callSpecs[i];
        final result = results[i];

        final summary = buildToolLogSummary(spec.name, spec.args, result);
        toolLogs[i] = ToolCallLog(
          toolName: spec.name,
          arguments: spec.args,
          resultSummary: summary,
        );

        final resultData = result.success
            ? result.data
            : 'Error: ${result.errorMessage}';
        final maxChars = settings.maxToolResultChars;
        final truncatedData = maxChars > 0 && resultData.length > maxChars
            ? '${resultData.substring(0, maxChars)}\n... (truncated to $maxChars chars)'
            : resultData;

        allToolResults.add({
          'tool': spec.name,
          'args': spec.args,
          'result': resultData,
          'success': result.success,
        });

        debugToolSteps.add({
          'tool': spec.name,
          'args': spec.args,
          'result_summary': summary,
          'result_size': resultData.length,
        });

        functionResponses.add({
          'functionResponse': {
            'name': spec.name,
            'response': {'content': truncatedData},
          },
        });
      }

      onToolUpdate?.call([...toolLogs]);
    }

    if (hasFinalAnswer) {
      toolsDone = true;
      functionResponses.add({
        'functionResponse': {
          'name': 'final_answer',
          'response': {
            'content':
                'Proceeding to generate final answer with collected data.',
          },
        },
      });
    }
    if (hasTextResponse) {
      toolsDone = true;
    }

    if (functionResponses.isNotEmpty) {
      conversation.add({'role': 'user', 'parts': functionResponses});
    }

    if (!hasFunctionCall) {
      toolsDone = true;
    }

    if (iterations >= maxIterations) {
      debugPrint('[$logTag] Max tool iterations reached');
      toolsDone = true;
    }
  }

  return AiToolLoopResult(
    toolLogs: toolLogs,
    allToolResults: allToolResults,
    conversation: conversation,
    debugToolSteps: debugToolSteps,
    iterationsUsed: iterations,
  );
}
