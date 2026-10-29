/// Single source of truth for ePitaka tools shared by Vīmaṃsā/Gavesana
/// (Gemini function calling) and the MCP server.
///
/// HOW TO ADD A NEW TOOL:
/// 1. Implement `Future<ToolResult> myTool(Map<String, dynamic> args)` on
///    [AiQaToolService] (lib/features/ai_qa/services/ai_qa_tool_service.dart).
/// 2. Add one `_tool(...)` entry to [kEpitakaTools] below (name, description,
///    inputSchema in MCP/JSON-Schema style with lowercase types).
/// 3. Add one `case` in [dispatchTool] that forwards to the service method.
/// Done — both Vīmaṃsā (`kAiToolDeclarations`) and MCP (`tools/list`) pick
/// it up automatically. No other file needs editing.
library;

import '../ai_qa/services/ai_qa_tool_service.dart';

/// One shared tool definition.
class EpitakaTool {
  final String name;
  final String description;

  /// MCP-style JSON Schema (lowercase types: object/array/string/integer).
  final Map<String, dynamic> inputSchema;

  /// Forwards to the [AiQaToolService] method. Kept beside the schema so a
  /// new tool cannot be registered for one surface but not the other.
  final Future<ToolResult> Function(
    AiQaToolService service,
    Map<String, dynamic> args,
  )
  run;

  final bool readOnly;

  const EpitakaTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.run,
    this.readOnly = true,
  });

  /// MCP `tools/list` entry.
  Map<String, dynamic> toMcpTool() => {
    'name': name,
    'description': description,
    'inputSchema': inputSchema,
  };

  /// Gemini `functionDeclarations` entry (UPPERCASE types).
  Map<String, dynamic> toGeminiDecl() => {
    'name': name,
    'description': description,
    'parameters': _toGeminiSchema(inputSchema),
  };
}

Map<String, dynamic> _obj(Map<String, dynamic> props, List<String> req) => {
  'type': 'object',
  'properties': props,
  'required': req,
};

Map<String, dynamic> _str(String desc) => {
  'type': 'string',
  'description': desc,
};

Map<String, dynamic> _int(String desc) => {
  'type': 'integer',
  'description': desc,
};

Map<String, dynamic> _arr(String desc, Map<String, dynamic> items) => {
  'type': 'array',
  'description': desc,
  'items': items,
};

EpitakaTool _tool({
  required String name,
  required String description,
  required Map<String, dynamic> schema,
  required Future<ToolResult> Function(
    AiQaToolService service,
    Map<String, dynamic> args,
  )
  run,
}) => EpitakaTool(
  name: name,
  description: description,
  inputSchema: schema,
  run: run,
);

/// Every tool ePitaka exposes. Order is stable for `tools/list`.
final List<EpitakaTool> kEpitakaTools = [
  _tool(
    name: 'search_tipitaka',
    description:
        'Search the Tipitaka database for relevant passages using full-text search. '
        'Use this when you need to find passages related to a specific topic, term, '
        'or concept in the Pāli Canon.',
    schema: _obj(
      {
        'query': _str(
          'Search query — a phrase or keywords to search for in the Pāli text.',
        ),
        'limit': _int(
          'Max results (1–50, default 50). Pass a small limit like 10 for '
          'fast responses over MCP.',
        ),
      },
      ['query'],
    ),
    run: (s, a) => s.searchTipitaka(a),
  ),
  _tool(
    name: 'search_tipitaka_batch',
    description:
        'Search the Tipitaka using MULTIPLE different search terms in one call. '
        'Use this to search for a concept using several synonyms or related terms '
        'simultaneously. All queries are executed in parallel for speed.',
    schema: _obj(
      {
        'queries': _arr(
          'Array of search queries to run in parallel. Include different phrasings, synonyms, and related terms to maximize coverage.',
          {'type': 'string'},
        ),
        'limit': _int(
          'Max merged results (1–50, default 50). Small limits answer faster.',
        ),
      },
      ['queries'],
    ),
    run: (s, a) => s.searchTipitakaBatch(a),
  ),
  _tool(
    name: 'search_by_category',
    description:
        'Search the Tipitaka within specific book categories or nikayas. '
        'Use this when you know which part of the canon the answer is likely in. '
        'Categories: "vinaya", "sutta", "abhidhamma". '
        'Nikaya prefixes: "dn", "mn", "sn", "an", "khp", "dhp", "ud", "it", "snp", '
        '"vv", "pv", "thag", "thig", "ja", "bi", "patis", "nm", "ne", "pk". '
        'Combine with queries to find specific passages within those books.',
    schema: _obj(
      {
        'queries': _arr(
          'Array of search queries. Include 2-3 specific terms (Pāli keywords, English phrases) to find within the target books.',
          {'type': 'string'},
        ),
        'categories': _arr(
          'Book categories to search within. Choose from: "vinaya", "sutta", or "abhidhamma". Can be combined with nikayas. Leave empty to search all categories.',
          {'type': 'string'},
        ),
        'nikayas': _arr(
          'Nikāya book prefixes to narrow the search further. E.g. ["dn"] for Dīgha Nikāya, ["an"] for Aṅguttara Nikāya, ["dhp"] for Dhammapada. Can be combined with categories.',
          {'type': 'string'},
        ),
        'limit': _int(
          'Max merged results (1–50, default 50). Small limits answer faster.',
        ),
      },
      ['queries', 'categories'],
    ),
    run: (s, a) => s.searchByCategory(a),
  ),
  _tool(
    name: 'search_sections',
    description:
        'Search section/sutta TITLES (with short summaries) across the whole canon. '
        'Use this FIRST for concept questions to discover WHICH suttas discuss '
        'a topic, then open them with get_paragraph_content or drill in with get_section.',
    schema: _obj(
      {
        'query': _str(
          'Term or phrase to match against section/sutta titles or summaries (Pāli or English).',
        ),
        'limit': _int('Max sections (1–50, default 20).'),
      },
      ['query'],
    ),
    run: (s, a) => s.searchSections(a),
  ),
  _tool(
    name: 'get_section',
    description:
        'Get ONE section (vagga/sutta/chapter) with its summary, its direct '
        'child sections, and its parent section. Use this to BROWSE down the '
        'canon hierarchy (vagga → sutta) after search_sections, instead of '
        "dumping a whole book's headings.",
    schema: _obj(
      {
        'book_id': _str('Book ID (e.g. "D-i", "S-iii", "M-iii", "Dhp").'),
        'para_start': _int(
          "The section's starting paragraph (para_start from a search_sections result).",
        ),
      },
      ['book_id', 'para_start'],
    ),
    run: (s, a) => s.getSection(a),
  ),
  _tool(
    name: 'get_dictionary',
    description:
        'Get the definition, inflections and canon occurrences for a single '
        'Pāli term. Canon occurrences show the actual sentences where the term '
        'appears in the Tipitaka (with translation and context). Use this '
        'BEFORE searching the canon when the question is about the meaning of '
        'a Pāli term. When you need SEVERAL terms, use get_dictionary_batch '
        'instead — one call per term costs an extra round-trip.',
    schema: _obj(
      {'term': _str('Pāli term to look up (e.g. "saṅkhāra").')},
      ['term'],
    ),
    run: (s, a) => s.getDictionary(a),
  ),
  _tool(
    name: 'get_dictionary_batch',
    description:
        'Look up definitions and canon occurrences for MULTIPLE Pāli terms in '
        'ONE call. Use this instead of calling get_dictionary repeatedly when '
        'you need to explain several terms (e.g. the key words of a sutta) — '
        'all lookups run in parallel for speed and save round-trips.',
    schema: _obj(
      {
        'terms': _arr(
          'Array of Pāli terms to look up, e.g. ["sīla", "samādhi", "paññā", "vimutti"].',
          {'type': 'string'},
        ),
      },
      ['terms'],
    ),
    run: (s, a) => s.getDictionaryBatch(a),
  ),
  _tool(
    name: 'get_headings',
    description:
        'Get the table of contents / section headings for a specific book. '
        'Use this to understand the structure of a book, find specific sections, '
        'or navigate to a particular topic within a book.',
    schema: _obj(
      {
        'book_id': _str(
          'Book ID (e.g. "dn1", "mn141", "sn12.2", "an3.1", "dhp").',
        ),
      },
      ['book_id'],
    ),
    run: (s, a) => s.getHeadings(a),
  ),
  _tool(
    name: 'get_books',
    description:
        'Get a list of all available books in the Tipitaka database. '
        'Use this when you need to know which books are available, their categories, '
        'or to find the correct book_id for a specific text. '
        'Pass limit/offset to paginate (a full list is ~60KB); paginated '
        'calls return {books, total, limit, offset, has_more}.',
    schema: _obj({
      'limit': _int('Max books per page (1–200). Omit for the full list.'),
      'offset': _int('Skip this many books (for paging with limit).'),
      'category': _str(
        'Filter by category: "vinaya", "sutta", or "abhidhamma".',
      ),
      'nikaya': _str(
        'Filter by nikāya prefix, e.g. "dn", "mn", "sn", "an", "dhp".',
      ),
    }, []),
    run: (s, a) => s.getBooks(a),
  ),
  _tool(
    name: 'get_paragraph_content',
    description:
        'Get the full Pāli content of a range of paragraphs from a specific book. '
        'Use this to read the actual text of a passage after you have identified '
        'the relevant book and paragraph range (e.g. from search results or headings).',
    schema: _obj(
      {
        'book_id': _str('Book ID (e.g. "dn1", "mn141").'),
        'para_start': _int('Starting paragraph number (inclusive).'),
        'para_end': _int(
          'Ending paragraph number (inclusive). Can be the same as para_start for a single paragraph.',
        ),
      },
      ['book_id', 'para_start', 'para_end'],
    ),
    run: (s, a) => s.getParagraphContent(a),
  ),
  _tool(
    name: 'get_paragraph_content_batch',
    description:
        'Get Pāli content from MULTIPLE book/paragraph ranges in ONE call. '
        'Use this to read several passages at once after you have identified '
        'the relevant locations (e.g. from search results or headings). '
        'All ranges are fetched in parallel for speed.',
    schema: _obj(
      {
        'ranges': _arr(
          'Array of paragraph ranges to fetch. Each range is an object with book_id, para_start, para_end.',
          {
            'type': 'object',
            'properties': {
              'book_id': _str('Book ID (e.g. "dn1", "mn141").'),
              'para_start': _int('Starting paragraph number (inclusive).'),
              'para_end': _int('Ending paragraph number (inclusive).'),
            },
            'required': ['book_id', 'para_start', 'para_end'],
          },
        ),
      },
      ['ranges'],
    ),
    run: (s, a) => s.getParagraphContentBatch(a),
  ),
  _tool(
    name: 'get_commentaries',
    description:
        'Get related commentary (Aṭṭhakathā) and sub-commentary (Ṭīkā) passages '
        'for a given Mūla (root text) paragraph. Use this when a user asks about '
        'commentarial explanations of a specific passage in the Tipitaka.',
    schema: _obj(
      {
        'mula_book_id': _str(
          'Book ID of the Mūla (root) text (e.g. "dn1", "mn141").',
        ),
        'mula_para_id': _int(
          'Paragraph number in the Mūla text to find commentaries for.',
        ),
      },
      ['mula_book_id', 'mula_para_id'],
    ),
    run: (s, a) => s.getCommentaries(a),
  ),
];

/// Dispatch one tool call to its [AiQaToolService] method by name.
/// Used by BOTH the Vīmaṃsā tool loop and the MCP server.
Future<ToolResult> dispatchTool(
  AiQaToolService service,
  String name,
  Map<String, dynamic> args,
) {
  for (final tool in kEpitakaTools) {
    if (tool.name == name) return tool.run(service, args);
  }
  return Future.value(
    ToolResult(success: false, data: '{}', errorMessage: 'Unknown tool: $name'),
  );
}

/// Gemini `functionDeclarations` derived from the same registry Vīmaṃsā's
/// tool loop already uses. Keeps the `final_answer` pseudo-tool appended
/// (chat-only, never exposed over MCP).
List<Map<String, dynamic>> geminiToolDeclarations() => [
  for (final tool in kEpitakaTools) tool.toGeminiDecl(),
  {
    'name': 'final_answer',
    'description': _finalAnswerDescription,
    'parameters': _toGeminiSchema(_finalAnswerParameters()),
  },
];

/// JSON-Schema style declarations with lowercase types, for the surfaces
/// that take normal JSON Schema: Anthropic `tools` and OpenAI-compatible
/// `tools`. These endpoints validate the schema strictly (Anthropic requires
/// `input_schema.type` to be exactly `'object'`), so they must use this list
/// — never [geminiToolDeclarations()], whose types are upper-cased for the
/// Gemini API and would be rejected with a 400.
///
/// Same content as the Gemini list, `final_answer` included (chat-only,
/// never exposed over MCP).
List<Map<String, dynamic>> jsonSchemaToolDeclarations() => [
  for (final tool in kEpitakaTools)
    {
      'name': tool.name,
      'description': tool.description,
      'parameters': tool.inputSchema,
    },
  {
    'name': 'final_answer',
    'description': _finalAnswerDescription,
    'parameters': _finalAnswerParameters(),
  },
];

/// The chat-only `final_answer` pseudo-tool's description (lowercase JSON
/// Schema; the Gemini list derives its upper-cased copy from this).
const String _finalAnswerDescription =
    'Call this when you have collected all the information needed to answer the user\'s question. '
    'The results will be passed to a more capable model to write the final answer. '
    'Use the args to summarize what you found.';

Map<String, dynamic> _finalAnswerParameters() => {
  'type': 'object',
  'properties': {
    'summary': {
      'type': 'string',
      'description':
          'Brief summary of what you found and what sources you collected.',
    },
  },
  'required': ['summary'],
};

/// Recursively upper-case JSON-Schema types for Gemini (object→OBJECT…).
Map<String, dynamic> _toGeminiSchema(Map<String, dynamic> schema) {
  final out = <String, dynamic>{};
  schema.forEach((key, value) {
    if (key == 'type' && value is String) {
      out[key] = value.toUpperCase();
    } else if (key == 'properties' && value is Map) {
      out[key] = {
        for (final e in value.entries)
          '${e.key}': _toGeminiSchema(
            Map<String, dynamic>.from(e.value as Map),
          ),
      };
    } else if (key == 'items' && value is Map) {
      out[key] = _toGeminiSchema(Map<String, dynamic>.from(value));
    } else {
      out[key] = value;
    }
  });
  return out;
}
