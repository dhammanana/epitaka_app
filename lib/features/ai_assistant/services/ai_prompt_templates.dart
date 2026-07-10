/// System and user prompts for the AI Assistant's two chat modes.
///
/// Inspired by the aichat (Python) app's 5-stage RAG pipeline, adapted for
/// use with a local Tipitaka SQLite database and the Gemini API.
///
/// Two modes:
/// 1. **Literal Review** — deep topic research with the model autonomously
///    querying the local DB (via tool calls or pre-searched context) and
///    returning a synthesised answer with [Source N] citations.
/// 2. **Answer Question** — grounded Q&A using retrieved passages.
library;

class AiPromptTemplates {
  AiPromptTemplates._();

  // ── Utility: Build context block from search results ──────────────────

  /// Format a list of search results into a context block for the model.
  /// Each result is wrapped in [Source N] tags with book_id, para_id, line_id.
  static String buildContextBlock(List<Map<String, dynamic>> results) {
    final parts = <String>[];
    final sep = '\n${'─' * 50}\n';

    for (int i = 0; i < results.length; i++) {
      final r = results[i];
      final bookId = r['book_id'] as String? ?? '';
      final paraId = r['para_id'] as int? ?? 0;
      final lineId = r['line_id'] as int? ?? 1;
      final bookName = r['book_name'] as String? ?? '';
      final text = r['text'] as String? ?? r['pali'] as String? ?? '';
      final translation = r['translation'] as String? ?? '';

      final lines = <String>[];
      lines.add('[Source ${i + 1}]');
      lines.add('Book: $bookName  (book_id=$bookId)');
      lines.add('para_id=$paraId | line_id=$lineId');

      if (text.isNotEmpty) {
        lines.add('');
        lines.add('Pāli:');
        lines.add(text);
      }
      if (translation.isNotEmpty) {
        lines.add('');
        lines.add('English:');
        lines.add(translation);
      }

      parts.add(lines.join('\n'));
    }

    return parts.join(sep);
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  MODE 1: LITERAL REVIEW
  // ═══════════════════════════════════════════════════════════════════════

  /// System prompt for Literal Review mode.
  ///
  /// The model receives a topic + a set of verified source passages from the
  /// Tipitaka. Its job is to synthesise a deep, well-structured research note
  /// that:
  ///   - Uses only the provided sources (no speculation)
  ///   - Cites every claim with [Source N] inline
  ///   - Includes Pali quotes with English glosses
  ///   - Organises themes, identifies patterns, notes open questions
  ///   - Links each citation to (book_id, para_id, line_id)
  static const String literalReviewSystem = '''You are a scholar of the Pāli Canon and Theravāda Buddhism, tasked with writing a **literal review** — a deep, source-grounded research synthesis.

You will receive:
  A) A research TOPIC
  B) VERIFIED SOURCE PASSAGES from the Tipiṭaka (Pāli + English translation)

Your task: write a thorough literal review that covers the topic.

## STRUCTURE
1. **Introduction** (1–2 sentences framing the topic's significance)
2. **Key Passages** — grouped by theme or sutta, each with:
   - The Pāli quote (exact, not paraphrased)
   - English gloss in parentheses after unfamiliar Pāli terms
   - Analysis: what this passage contributes to the topic
   - Inline citation: [Source N]
3. **Synthesis** — how the passages together illuminate the topic
4. **Open Questions / Ambiguities** — what the Canon does not clearly settle

## STRICT RULES
1. Every factual claim MUST be backed by an inline [Source N] citation.
2. Quote the Pāli EXACTLY as given — never paraphrase Pāli words.
3. After each Pāli quote, provide the English meaning in parentheses.
4. Always note: book_id, para_id, line_id with every citation.
5. If the provided passages are insufficient to answer, say so honestly.
6. Organise by theme, not by source number — group related passages.
7. Explain technical Pāli terms (kamma, khandha, āyatana, etc.) on first use.
8. Use a scholarly but readable tone — formal yet clear.
9. Wrap [Source N] references in square brackets — these will be rendered as interactive links in the UI.

## OUTPUT FORMAT
Use Markdown for structure (## headings, **bold** for key terms, *italic* for Pāli words, > for blockquoted Pāli).''';

  // ═══════════════════════════════════════════════════════════════════════
  //  MODE 2: ANSWER QUESTION
  // ═══════════════════════════════════════════════════════════════════════

  /// System prompt for Answer Question mode.
  ///
  /// Similar grounded approach, but the output is a direct answer to a
  /// question rather than a deep review.
  static const String answerQuestionSystem = '''You are a knowledgeable scholar of the Pāli Canon and Theravāda Buddhism.

You will receive:
  A) A USER QUESTION
  B) VERIFIED SOURCE PASSAGES from the Tipiṭaka (Pāli + English translation)

Your task: answer the question using ONLY the provided passages.

## RULES
1. Every factual claim MUST be backed by an inline [Source N] citation.
2. Quote Pāli EXACTLY as given — never paraphrase Pāli words.
3. After each Pāli quote, provide the English meaning in parentheses.
4. Always note: book_id, para_id, line_id with every citation.
5. If the passages are insufficient, say so honestly rather than speculating.
6. Structure: (a) Direct answer  (b) Supporting passages  (c) Explanation.
7. Explain Pāli technical terms briefly on first use.
8. Wrap [Source N] references in square brackets.

## OUTPUT FORMAT
Use Markdown for structure (## headings, **bold**, *italic*, > blockquotes).''';

  // ═══════════════════════════════════════════════════════════════════════
  //  USER PROMPT BUILDER (shared)
  // ═══════════════════════════════════════════════════════════════════════

  /// Build the user turn that wraps question + context for the model.
  static String buildUserPrompt({
    required String question,
    required String contextBlock,
    String? extraInstructions,
  }) {
    final buf = StringBuffer();

    buf.writeln('═══════════════════════════════════════════');
    buf.writeln('VERIFIED SOURCE PASSAGES FROM THE PALI CANON:');
    buf.writeln('═══════════════════════════════════════════');
    buf.writeln(contextBlock);

    buf.writeln();
    buf.writeln('═══════════════════════════════════════════');
    buf.writeln('TOPIC / QUESTION:');
    buf.writeln('═══════════════════════════════════════════');
    buf.writeln(question);

    if (extraInstructions != null && extraInstructions.isNotEmpty) {
      buf.writeln();
      buf.writeln(extraInstructions);
    }

    return buf.toString();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  RERANK / FILTER PROMPT (lite model)
  // ═══════════════════════════════════════════════════════════════════════

  /// Prompt for the lite model to re-rank and filter search results.
  ///
  /// Returns a JSON array of {i, score} pairs.
  static String buildRerankPrompt({
    required String question,
    required List<Map<String, dynamic>> candidates,
  }) {
    final lines = <String>[];
    for (int i = 0; i < candidates.length; i++) {
      final c = candidates[i];
      final bookId = c['book_id'] ?? '';
      final paraId = c['para_id'] ?? 0;
      final text = c['text'] as String? ?? '';
      final preview = text.length > 200 ? '${text.substring(0, 200)}...' : text;
      lines.add('[$i] (book=$bookId, para=$paraId) $preview');
    }

    return '''You are a Pāli Canon scholar evaluating search results.

QUESTION: $question

Rate each passage below for RELEVANCE to the question on a scale 0-10:
  10 = directly answers the question
   7 = strongly related, partial answer
   4 = tangentially related
   0 = not relevant

Return ONLY a JSON array of objects, one per passage, in the same order:
  [{"i": 0, "score": 8}, {"i": 1, "score": 3}, ...]

No markdown, no explanation.

PASSAGES:
${lines.join('\n\n')}''';
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  KEYWORD EXPANSION PROMPT (lite model)
  // ═══════════════════════════════════════════════════════════════════════

  /// Prompt for the lite model to expand a query into alternative phrasings.
  static const String expandQueryPrompt = '''
You are a Pāli Canon scholar. Generate {n} alternative search phrasings for the topic: "{query}"
Include Pāli technical terms where highly relevant.
Return ONLY a valid JSON array of strings, no markdown, no explanation.
''';

  // ═══════════════════════════════════════════════════════════════════════
  //  CITATION PARSING
  // ═══════════════════════════════════════════════════════════════════════

  /// Regex to extract [Source N] citations and their associated metadata
  /// from the model's answer text.
  ///
  /// Matches patterns like:
  ///   [Source 1]
  ///   [Source 2]
  ///   [Source 10]
  static final RegExp sourceRefRegex = RegExp(
    r'\[Source\s+(\d+)\]',
    caseSensitive: false,
  );
}
