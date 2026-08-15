/// Shared AI API client, tool declarations and the tool-calling loop engine
/// used by both the Vimaṃsa (AI Q&A) chat and the Gavesana AI search.
///
/// Everything that talks to the AI provider (Gemini / OpenAI-compatible) and
/// everything that drives the function-calling loop lives here so the two
/// features reuse exactly the same logic instead of duplicating it.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../shared/models/ai_provider.dart';
import '../models/ai_qa_models.dart';
import 'ai_qa_tool_service.dart';

/// Gemini default base URL.
const String kGeminiBaseUrl =
    'https://generativelanguage.googleapis.com/v1beta/models';

/// Number of retries for non-streaming API calls.
const int kAiMaxRetries = 2;

/// Shared function declarations (tools) for AI tool calling.
///
/// Used by both Vimaṃsa and Gavesana so the model can decide how to search
/// the Tipitaka using the same local database tools.
final List<Map<String, dynamic>> kAiToolDeclarations = [
  {
    'name': 'search_tipitaka',
    'description':
        'Search the Tipitaka database for relevant passages using full-text search. '
        'Use this when you need to find passages related to a specific topic, term, '
        'or concept in the Pāli Canon.',
    'parameters': {
      'type': 'OBJECT',
      'properties': {
        'query': {
          'type': 'STRING',
          'description':
              'Search query — a phrase or keywords to search for in the Pāli text.',
        },
      },
      'required': ['query'],
    },
  },
  {
    'name': 'search_tipitaka_batch',
    'description':
        'Search the Tipitaka using MULTIPLE different search terms in one call. '
        'Use this to search for a concept using several synonyms or related terms '
        'simultaneously. All queries are executed in parallel for speed.',
    'parameters': {
      'type': 'OBJECT',
      'properties': {
        'queries': {
          'type': 'ARRAY',
          'description':
              'Array of search queries to run in parallel. '
              'Include different phrasings, synonyms, and related terms '
              'to maximize coverage.',
          'items': {'type': 'STRING'},
          'minItems': 2,
          'maxItems': 5,
        },
      },
      'required': ['queries'],
    },
  },
  {
    'name': 'search_by_category',
    'description':
        'Search the Tipitaka within specific book categories or nikayas. '
        'Use this when you know which part of the canon the answer is likely in. '
        'Categories: "vinaya", "sutta", "abhidhamma". '
        'Nikaya prefixes: "dn", "mn", "sn", "an", "khp", "dhp", "ud", "it", "snp", '
        '"vv", "pv", "thag", "thig", "ja", "bi", "patis", "nm", "ne", "pk". '
        'Combine with queries to find specific passages within those books.',
    'parameters': {
      'type': 'OBJECT',
      'properties': {
        'queries': {
          'type': 'ARRAY',
          'description':
              'Array of search queries. Include 2-3 specific terms '
              '(Pāli keywords, English phrases) to find within the target books.',
          'items': {'type': 'STRING'},
          'minItems': 2,
          'maxItems': 5,
        },
        'categories': {
          'type': 'ARRAY',
          'description':
              'Book categories to search within. '
              'Choose from: "vinaya", "sutta", or "abhidhamma". '
              'Can be combined with nikayas. Leave empty to search all categories.',
          'items': {'type': 'STRING'},
        },
        'nikayas': {
          'type': 'ARRAY',
          'description':
              'Nikāya book prefixes to narrow the search further. '
              'E.g. ["dn"] for Dīgha Nikāya, ["an"] for Aṅguttara Nikāya, '
              '["dhp"] for Dhammapada. Can be combined with categories.',
          'items': {'type': 'STRING'},
        },
      },
      'required': ['queries', 'categories'],
    },
  },
  {
    'name': 'search_sections',
    'description':
        'Search section/sutta TITLES (with short summaries) across the whole canon. '
        'Use this FIRST for concept questions to discover WHICH suttas discuss '
        'a topic, then open them with get_paragraph_content or drill in with get_section.',
    'parameters': {
      'type': 'OBJECT',
      'properties': {
        'query': {
          'type': 'STRING',
          'description':
              'Term or phrase to match against section/sutta titles or summaries (Pāli or English).',
        },
      },
      'required': ['query'],
    },
  },
  {
    'name': 'get_section',
    'description':
        'Get ONE section (vagga/sutta/chapter) with its summary, its direct '
        'child sections, and its parent section. Use this to BROWSE down the '
        'canon hierarchy (vagga → sutta) after search_sections, instead of '
        'dumping a whole book\'s headings.',
    'parameters': {
      'type': 'OBJECT',
      'properties': {
        'book_id': {
          'type': 'STRING',
          'description': 'Book ID (e.g. "D-i", "S-iii", "M-iii", "Dhp").',
        },
        'para_start': {
          'type': 'INTEGER',
          'description':
              'The section\'s starting paragraph (para_start from a search_sections result).',
        },
      },
      'required': ['book_id', 'para_start'],
    },
  },
  {
    'name': 'get_dictionary',
    'description':
        'Get the definition, inflections and canon occurrences for a single '
        'Pāli term. Canon occurrences show the actual sentences where the term '
        'appears in the Tipitaka (with translation and context). Use this '
        'BEFORE searching the canon when the question is about the meaning of '
        'a Pāli term. When you need SEVERAL terms, use get_dictionary_batch '
        'instead — one call per term costs an extra API round-trip.',
    'parameters': {
      'type': 'OBJECT',
      'properties': {
        'term': {
          'type': 'STRING',
          'description': 'Pāli term to look up (e.g. "saṅkhāra").',
        },
      },
      'required': ['term'],
    },
  },
  {
    'name': 'get_dictionary_batch',
    'description':
        'Look up definitions and canon occurrences for MULTIPLE Pāli terms in '
        'ONE call. Use this instead of calling get_dictionary repeatedly when '
        'you need to explain several terms (e.g. the key words of a sutta) — '
        'all lookups run in parallel for speed and save API round-trips.',
    'parameters': {
      'type': 'OBJECT',
      'properties': {
        'terms': {
          'type': 'ARRAY',
          'description':
              'Array of Pāli terms to look up, e.g. ["sīla", "samādhi", "paññā", "vimutti"].',
          'items': {'type': 'STRING'},
          'minItems': 2,
          'maxItems': 5,
        },
      },
      'required': ['terms'],
    },
  },
  {
    'name': 'get_headings',
    'description':
        'Get the table of contents / section headings for a specific book. '
        'Use this to understand the structure of a book, find specific sections, '
        'or navigate to a particular topic within a book.',
    'parameters': {
      'type': 'OBJECT',
      'properties': {
        'book_id': {
          'type': 'STRING',
          'description':
              'Book ID (e.g. "dn1", "mn141", "sn12.2", "an3.1", "dhp").',
        },
      },
      'required': ['book_id'],
    },
  },
  {
    'name': 'get_books',
    'description':
        'Get a list of all available books in the Tipitaka database. '
        'Use this when you need to know which books are available, their categories, '
        'or to find the correct book_id for a specific text.',
    'parameters': {'type': 'OBJECT', 'properties': {}},
  },
  {
    'name': 'get_paragraph_content',
    'description':
        'Get the full Pāli content of a range of paragraphs from a specific book. '
        'Use this to read the actual text of a passage after you have identified '
        'the relevant book and paragraph range (e.g. from search results or headings).',
    'parameters': {
      'type': 'OBJECT',
      'properties': {
        'book_id': {
          'type': 'STRING',
          'description': 'Book ID (e.g. "dn1", "mn141").',
        },
        'para_start': {
          'type': 'INTEGER',
          'description': 'Starting paragraph number (inclusive).',
        },
        'para_end': {
          'type': 'INTEGER',
          'description':
              'Ending paragraph number (inclusive). Can be the same as para_start for a single paragraph.',
        },
      },
      'required': ['book_id', 'para_start', 'para_end'],
    },
  },
  {
    'name': 'get_paragraph_content_batch',
    'description':
        'Get Pāli content from MULTIPLE book/paragraph ranges in ONE call. '
        'Use this to read several passages at once after you have identified '
        'the relevant locations (e.g. from search results or headings). '
        'All ranges are fetched in parallel for speed.',
    'parameters': {
      'type': 'OBJECT',
      'properties': {
        'ranges': {
          'type': 'ARRAY',
          'description':
              'Array of paragraph ranges to fetch. Each range is an object '
              'with book_id, para_start, para_end.',
          'items': {
            'type': 'OBJECT',
            'properties': {
              'book_id': {
                'type': 'STRING',
                'description': 'Book ID (e.g. "dn1", "mn141").',
              },
              'para_start': {
                'type': 'INTEGER',
                'description': 'Starting paragraph number (inclusive).',
              },
              'para_end': {
                'type': 'INTEGER',
                'description': 'Ending paragraph number (inclusive).',
              },
            },
            'required': ['book_id', 'para_start', 'para_end'],
          },
          'minItems': 2,
          'maxItems': 10,
        },
      },
      'required': ['ranges'],
    },
  },
  {
    'name': 'get_commentaries',
    'description':
        'Get related commentary (Aṭṭhakathā) and sub-commentary (Ṭīkā) passages '
        'for a given Mūla (root text) paragraph. Use this when a user asks about '
        'commentarial explanations of a specific passage in the Tipitaka.',
    'parameters': {
      'type': 'OBJECT',
      'properties': {
        'mula_book_id': {
          'type': 'STRING',
          'description':
              'Book ID of the Mūla (root) text (e.g. "dn1", "mn141").',
        },
        'mula_para_id': {
          'type': 'INTEGER',
          'description':
              'Paragraph number in the Mūla text to find commentaries for.',
        },
      },
      'required': ['mula_book_id', 'mula_para_id'],
    },
  },
  {
    'name': 'final_answer',
    'description':
        'Call this when you have collected all the information needed to answer the user\'s question. '
        'The results will be passed to a more capable model to write the final answer. '
        'Use the args to summarize what you found.',
    'parameters': {
      'type': 'OBJECT',
      'properties': {
        'summary': {
          'type': 'STRING',
          'description':
              'Brief summary of what you found and what sources you collected.',
        },
      },
      'required': ['summary'],
    },
  },
];

/// Default system prompt for the Vimaṃsa tool model (chat + Q&A).
const String kAiDefaultToolSystemPrompt = '''You are an expert research assistant for the Pāli Canon (Tipitaka).

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
const String kAiSearchSystemPrompt = '''You are a search planner for the Pāli Canon (Tipitaka).

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
        );
        return jsonDecode(response) as Map<String, dynamic>;
      case AiProvider.openai:
      case AiProvider.openrouter:
        // OpenRouter speaks the OpenAI chat-completions protocol, so both
        // providers share the same code path (only the base URL differs).
        final response = await _callOpenAiApiRaw(
          model: toolModel,
          apiKey: apiKey,
          baseUrl: baseUrl.isNotEmpty ? baseUrl : provider.defaultBaseUrl,
          payload: payload,
          logTag: logTag,
        );
        return jsonDecode(response) as Map<String, dynamic>;
    }
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
      case AiProvider.openai:
      case AiProvider.openrouter:
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
  }) async {
    final url = Uri.parse('$kGeminiBaseUrl/$model:generateContent?key=$apiKey');

    for (int attempt = 0; attempt <= kAiMaxRetries; attempt++) {
      try {
        final apiStopwatch = Stopwatch()..start();
        final httpResponse = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
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
            await Future.delayed(wait);
            continue;
          }
          throw Exception('Rate limit exceeded. Try again later.');
        } else {
          if (attempt < kAiMaxRetries) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          throw Exception(
            'API error ${httpResponse.statusCode}: ${parseApiError(httpResponse.body)}',
          );
        }
      } on http.ClientException {
        if (attempt < kAiMaxRetries) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        rethrow;
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
  }) async {
    final effectiveBase = baseUrl.isNotEmpty ? baseUrl : 'https://api.openai.com/v1';
    final url = Uri.parse('$effectiveBase/chat/completions');

    for (int attempt = 0; attempt <= kAiMaxRetries; attempt++) {
      try {
        final apiStopwatch = Stopwatch()..start();
        final httpResponse = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode(payload),
        );
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
            final message = choices[0]['message'] as Map<String, dynamic>? ?? {};
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
                    'args': jsonDecode(tcMap['function']['arguments'] as String),
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
            await Future.delayed(wait);
            continue;
          }
          throw Exception('Rate limit exceeded. Try again later.');
        } else {
          if (attempt < kAiMaxRetries) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          throw Exception(
            'API error ${httpResponse.statusCode}: ${parseApiError(httpResponse.body)}',
          );
        }
      } on http.ClientException {
        if (attempt < kAiMaxRetries) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        rethrow;
      }
    }

    throw Exception('API call failed after $kAiMaxRetries retries');
  }

  /// Extract a human-readable error message from an API error body.
  static String parseApiError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>?;
      if (error != null) {
        return error['message'] as String? ?? error['status'] as String? ?? body;
      }
      return body;
    } on FormatException {
      return body;
    }
  }

  /// Translate raw errors into a friendly, actionable message for the user.
  static String friendlyErrorMessage(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();

    final statusMatch = RegExp(r'API error (\d+)').firstMatch(raw);
    if (statusMatch != null) {
      switch (statusMatch.group(1)) {
        case '400':
          return 'The AI service rejected the request (400). The question may '
              'be too long or contain unsupported content. Try asking again.';
        case '401':
        case '403':
          return 'Your API key was rejected (${statusMatch.group(1)}). '
              'Please check the API key in Settings.';
        case '404':
          return 'Model not found (404). The selected model may have been '
              'renamed or is unavailable — update the model in Settings.';
        case '429':
          return 'Rate limit exceeded (429). Please wait a moment and try again.';
        case '500':
        case '502':
        case '503':
          return 'The AI service is temporarily unavailable '
              '(${statusMatch.group(1)}). Please try again shortly.';
        default:
          return 'The AI service returned an error '
              '(${statusMatch.group(1)}). Please try again.';
      }
    }

    if (lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('failed host lookup') ||
        lower.contains('unable to connect')) {
      return 'Could not reach the AI service. Check your internet connection '
          'and try again.';
    }
    if (lower.contains('timeout')) {
      return 'The AI service took too long to respond. Please try again.';
    }
    if (lower.contains('rate limit')) {
      return 'Rate limit exceeded. Please wait a moment and try again.';
    }

    return raw;
  }
}

/// Build a short human-readable summary of a tool call for UI logs.
String buildToolLogSummary(String name, Map<String, dynamic> args, ToolResult result) {
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
      final queryShort = query.length > 40 ? '${query.substring(0, 40)}…' : query;
      if (resultCount > 0) {
        return '🔍 "$queryShort" → $resultCount results';
      }
      return '🔍 "$queryShort" (${result.data.length} chars)';
    case 'search_tipitaka_batch':
      final queries =
          (args['queries'] as List<dynamic>?)?.map((q) => q.toString()).toList() ?? [];
      final queriesStr = queries
          .map((q) => q.length > 20 ? '${q.substring(0, 20)}…' : q)
          .join(', ');
      return '🔍 Batch[$resultCount results] ($queriesStr)';
    case 'search_by_category':
      final cats =
          (args['categories'] as List<dynamic>?)?.map((c) => c.toString()).toList() ?? [];
      final niks =
          (args['nikayas'] as List<dynamic>?)?.map((n) => n.toString()).toList() ?? [];
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
      final terms = (args['terms'] as List<dynamic>?)
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

  switch (name) {
    case 'search_tipitaka':
      return service.searchTipitaka(args);
    case 'search_tipitaka_batch':
      return service.searchTipitakaBatch(args);
    case 'search_by_category':
      return service.searchByCategory(args);
    case 'search_sections':
      return service.searchSections(args);
    case 'get_section':
      return service.getSection(args);
    case 'get_dictionary':
      return service.getDictionary(args);
    case 'get_dictionary_batch':
      return service.getDictionaryBatch(args);
    case 'get_headings':
      return service.getHeadings(args);
    case 'get_books':
      return service.getBooks(args);
    case 'get_paragraph_content':
      return service.getParagraphContent(args);
    case 'get_paragraph_content_batch':
      return service.getParagraphContentBatch(args);
    case 'get_commentaries':
      return service.getCommentaries(args);
    default:
      return ToolResult(
        success: false,
        data: '{}',
        errorMessage: 'Unknown tool: $name',
      );
  }
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

      final results = await Future.wait(
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

        final resultData = result.success ? result.data : 'Error: ${result.errorMessage}';
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
            'content': 'Proceeding to generate final answer with collected data.',
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
