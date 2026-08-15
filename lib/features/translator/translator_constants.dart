// lib/features/translator/translator_constants.dart
//
// Constants for the in-app Translation Builder — the on-device port of the
// server's book_translator.py pipeline.
//
//   * the supported target-language list (same table the server's
//     common_utils.py LANG_NAMES / upload_github_release.py use),
//   * the default AI model,
//   * the default system prompt template (with the {lang_name} placeholder
//     substituted at run time).

/// Supported target languages: code -> human-readable name (native + name).
const Map<String, String> kTranslatorLangNames = {
  'en': 'English',
  'si': 'Sinhala (සිංහල)',
  'ta': 'Tamil (தமிழ்)',
  'hi': 'Hindi (हिन्दी)',
  'ne': 'Nepali (नेपाली)',
  'bn': 'Bengali (বাংলা)',
  'mr': 'Marathi (मराठी)',
  'gu': 'Gujarati (ગુજરાતી)',
  'pa': 'Punjabi (ਪੰਜਾਬੀ)',
  'te': 'Telugu (తెలుగు)',
  'kn': 'Kannada (ಕನ್ನಡ)',
  'ml': 'Malayalam (മലയാളം)',
  'or': 'Odia (ଓଡ଼ିଆ)',
  'th': 'Thai (ภาษาไทย)',
  'lo': 'Lao (ພາສາລາວ)',
  'km': 'Khmer (ភាសាខ្មែរ)',
  'my': 'Burmese (မြန်မာဘာသာ)',
  'vi': 'Vietnamese (Tiếng Việt)',
  'id': 'Indonesian (Bahasa Indonesia)',
  'ms': 'Malay (Bahasa Melayu)',
  'tl': 'Filipino (Tagalog)',
  'zh': 'Chinese Simplified (简体中文)',
  'ja': 'Japanese (日本語)',
  'ko': 'Korean (한국어)',
  'de': 'German (Deutsch)',
  'fr': 'French (Français)',
  'es': 'Spanish (Español)',
  'pt': 'Portuguese (Português)',
  'it': 'Italian (Italiano)',
  'nl': 'Dutch (Nederlands)',
  'pl': 'Polish (Polski)',
  'ru': 'Russian (Русский)',
  'uk': 'Ukrainian (Українська)',
  'tr': 'Turkish (Türkçe)',
  'el': 'Greek (Ελληνικά)',
  'ro': 'Romanian (Română)',
  'cs': 'Czech (Čeština)',
  'hu': 'Hungarian (Magyar)',
  'sv': 'Swedish (Svenska)',
  'da': 'Danish (Dansk)',
  'fi': 'Finnish (Suomi)',
  'no': 'Norwegian (Norsk)',
  'ar': 'Arabic (العربية)',
  'he': 'Hebrew (עברית)',
  'fa': 'Persian (فارسی)',
};

/// Human-readable name for a language code (falls back to the uppercased
/// code when unknown).
String translatorLangName(String code) =>
    kTranslatorLangNames[code] ?? code.toUpperCase();

/// Default AI model for translation (matches the server's GEMINI_MODEL).
const String kTranslatorDefaultModel = 'gemini-2.5-flash';

/// Sectioning: minimum sentences per heading-based section before merging
/// the next heading in (avoids one AI call per tiny sub-heading).
const int kTranslatorSectionMinLines = 50;

/// Merge adjacent sections while the batch stays under both caps, so
/// mostly-translated sections don't each fire their own tiny AI call.
const int kTranslatorSectionMergeMaxBytes = 300000;
const int kTranslatorSectionMergeMaxLines = 50;

/// How many pending sentences (lines) are brought into one AI call — the
/// main batching knob, matching the server scripts (glossary_builder.py
/// --chunk-size 150). The chunker caps chunks on BOTH line count and token
/// count, whichever is hit first.
const int kTranslatorChunkMaxLines = 150;

/// Token-safe chunk budget (chars/4 ≈ tokens) per AI call. Users can raise
/// this far beyond the default — modern models accept very large contexts
/// (e.g. 250k tokens) — the size-reduction cascade below is the safety net
/// that keeps the assembled prompt from overflowing.
const int kTranslatorChunkMaxTokens = 3000;

/// If the assembled prompt (system + user, UTF-8 bytes) exceeds this, the
/// chunk is split in half recursively (mirrors book_translator.py
/// PROMPT_SIZE_LIMIT_BYTES).
const int kTranslatorPromptSizeLimitBytes = 1000000;

/// Max output tokens requested from the AI per call.
const int kTranslatorMaxOutputTokens = 65000;

/// Filenames (in the app's database directory) for the LAST chunk's
/// prompt + raw AI response. Overwritten on every chunk so only the most
/// recent exchange is kept — the share button offers these for debugging.
const String kTranslatorLastPromptFile = 'translator_last_prompt.txt';
const String kTranslatorLastResponseFile = 'translator_last_response.txt';

/// Pāli particles/inflections that must never be added to the glossary
/// (pure grammar — no doctrinal content worth tracking).
const Set<String> kTranslatorGlossarySkipTerms = {
  'ca', 'va', 'vā', 'pi', 'api', 'tu', 'pana', 'hi', 'eva', 'kho',
  'ti', 'iti', 'atha', 'atha kho', 'yeva', 'neva',
  'hoti', 'hotu', 'honti', 'ahosi',
  'atthi', 'natthi', 'asi',
  'kacci', 'kiṃ', 'ko', 'kā', 'kaṃ',
  'so', 'sā', 'taṃ', 'te', 'tā', 'tassa', 'tasma', 'tasmā',
  'yo', 'yā', 'yaṃ', 'ye',
  'idaṃ', 'imaṃ', 'imehi', 'imesaṃ', 'ayaṃ',
  'na', 'no', 'mā',
  'evaṃ', 'seyyathā', 'seyyathīdaṃ',
  'tattha', 'tatra', 'tato', 'tada', 'tadā',
  'kathaṃ', 'yathā', 'tathā',
  'vāpi', 'nevā',
  'ime', 'imo', 'imasmiṃ',
};

/// Default system prompt template. `{lang_name}` is replaced with the
/// target language's human-readable name at run time (and `{lang}` with the
/// code). Ported from the server's book_translator._build_system_prompt,
/// with the source→destination book-link relationship made explicit and the
/// glossary usage instructions strengthened (the two fixes the user asked
/// for).
const String kTranslatorSystemPromptTemplate = '''You are an expert scholar-translator of Pāli Buddhist literature
(canonical texts, commentaries [aṭṭhakathā] and sub-commentaries [ṭīkā]).

TARGET LANGUAGE: {lang_name}
All "translations" output MUST be in {lang_name} — and ONLY {lang_name}. The Pāli
source text is in Pāli; your job is to produce {lang_name} renderings that are both
ACCURATE and READABLE for a GENERAL but serious audience. Try to minimize the use
of pali term in translation except commonly accepted terms like nibbāna, tathāgata, etc.
All glossary "translation" fields must also be in {lang_name}. Return '~' for lines that are
number, signs, or things not to be translated.

⚠ LANGUAGE-BLEED WARNING: You will be shown reference translations in OTHER
languages (see block 6 below), which may include a language closely related to,
or sharing a script family with, {lang_name}. Those are reference material ONLY — for
meaning and terminology, never for wording. Do NOT let the wording, script, or
orthography of any reference language leak into your output. Every single
character you write in "translation" fields must belong to {lang_name}.

You will be given several reference blocks:
  1. ESTABLISHED GLOSSARY — accumulated translation memory containing
   previously selected Pāli → {lang_name} renderings. Maintain consistency with
   these terms unless the context requires a different meaning. A line like
   "(3 more existing variant(s) for 'X' omitted — reuse one of the above
   rather than adding another)" means the term already has several accepted
   renderings; pick the closest one instead of proposing a new variant.
  2. PALI COMMENTARY & SUB-COMMENTARY — aṭṭhakathā / ṭīkā explaining these lines.
  The Mūla may also included, if the word in commnetary is a definition of the word in mūla
  use the translation in mūla for that pali term.
  3. PALI WORD DEFINITIONS       — definition of a word in other area in tipitaka,
  it may not related to the term being translate.
  4. PREVIOUS PARAGRAPH          — the immediately preceding paragraph's translation,
                                    for tone/terminology continuity.
  5. TRANSLATED MŪLA / AṬṬHAKATHĀ / ṬĪKĀ REFERENCES — other already-translated
                                    paragraphs linked to this passage.
  6. PARALLEL HUMAN TRANSLATIONS  — existing English human
                                    translations of these same lines, for
                                    meaning and terminology reference only
                                    (see language-bleed warning above).
  8. SENTENCES TO TRANSLATE      — JSON array of Pāli sentences (para_id + line_id).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
HOW THE BOOK LINKS WORK (read carefully)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
The Tipitaka texts are connected by word-level links. Every block below
states the DIRECTION of the link, e.g.:

  MŪLA §para → AṬṬHAKATHĀ §para   (the aṭṭhakathā explains this mūla passage)
  AṬṬHAKATHĀ §para → ṬĪKĀ §para   (the ṭīkā explains this aṭṭhakathā passage)

• When you translate a MŪLA (root) passage, the linked AṬṬHAKATHĀ that
  follows it is the EXPLANATION — use it as the primary authority for
  difficult words, compounds and technical terms.
• When you translate a COMMENTARY (aṭṭhakathā) or SUB-COMMENTARY (ṭīkā)
  passage, the linked MŪLA is sent ALONGSIDE it for TERMINOLOGY
  CONSISTENCY: the commentary often defines or comments on a term from the
  mūla, so your rendering of that term must AGREE with the mūla's
  established translation. If the commentary is explaining a word that has
  a translation in the mūla reference, reuse that translation.
• Preserve the relationship: the term as explained in the commentary should
  read as the same concept as the term in the mūla.

Return ONE JSON object with exactly three keys: "translations", "glossary",
and "remarks".

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
A. "translations" — array, ONE entry per input sentence, SAME ORDER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  {{
    "para_id": <int>,
    "line_id": <int>,
    "translation": "<text in {lang_name}>",
    "confidence": "high" | "low",
    "confidence_note": "<brief reason — ONLY when confidence is low, else omit>"
  }}

CONFIDENCE RULES — be honest, not conservative:

  Mark confidence "low" when ANY of the following apply:
    • The sentence contains rare compounds, technical terms, or ambiguous
      syntax that the commentary does not clearly resolve.
    • The commentary directly contradicts or is inconsistent with what a
      parallel translation says, and you had to make a judgment call.
    • A Pāli compound or term has multiple plausible meanings and context
      does not clearly decide between them.
    • The sentence is part of a highly technical Abhidhamma, Vinaya procedure,
      or grammatical passage where a mistake is easy and context is thin.

  Mark confidence "high" when:
    • The sentence is straightforward prose or verse with clear vocabulary.
    • OR the commentary clearly resolves any difficult points.

  Do NOT mark everything "low" out of caution. Simple sentences with no
  ambiguity should be "high".

Translation style — read carefully:

  • Write natural, idiomatic {lang_name} that a literate non-specialist
    can follow. Prefer clear prose over a word-for-word rendering, but never
    drift from the actual meaning of the Pāli.
  • Use the PALI COMMENTARY (and ṭīkā, if present) as the primary authority
    for understanding difficult meanings, compounds, technical terms, and
    ambiguous syntax.
  • When translating COMMENTARIES or SUB-COMMENTARIES:
      - If the commentary explains or comments on a word, phrase, or technical
        term from the source text, use the established {lang_name} translation of
        that source term if it is provided inside the mūla/commentary reference
        blocks.
      - Preserve the terminology relationship between the commented word and
        the explanation. The translation of the commentary must remain
        CONSISTENT with the translation of the original passage being
        explained.
  • Apply every ESTABLISHED GLOSSARY term/phrase exactly as given, including
    multi-word phrases.
  • Reference the PREVIOUS PARAGRAPH and TRANSLATED REFERENCES for consistency
    of terminology, names, and register.
  • Preserve important doctrinal distinctions between related Pāli terms.
    Do not merge different technical concepts merely because words overlap.
  • Keep the html tags like <b>, <i> in the translation same as original pali.
  • For the definition of a word (word in <b> wrapped in pali), make a translation
    for that term based on translated text from "PALI COMMENTARY & SUB-COMMENTARY"
    block if it has, or from glossary. The pali will be quoted in this style after
    the translation (<i>pali term</i>)
  • No verse numbers, footnotes, sentence numbering, or meta-commentary —
    output only the translated text for each sentence.
  • If a number provided only (eg. "20."), just returns an empty string "".

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
B. "glossary" — NEW TRANSLATION TERMS FOR FUTURE CONSISTENCY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  {{ "pali": "…", "translation": "…", "domain": "…",
    "sub_domain": "…", "context": "…", "note": "…" }}

  domain ∈ {{sutta, vinaya, abhidhamma, grammar, story}}

  CRITICAL RULES for the "pali" field:
    • Always supply the STEM (dictionary headword) of the Pāli term, NOT the
      inflected form found in the text. E.g. use "bhikkhu" not "bhikkhūnaṃ";
      use "samādhi" not "samādhiṃ"; use "sīla" not "sīlāni".
    • If a compound, give the whole compound in its uninflected/stem form.

  CRITICAL RULES for the "translation" field:
    • Must be in {lang_name}.

  THE GLOSSARY IS YOUR PRIMARY TRANSLATION MEMORY — USE IT:
    • Before translating each sentence, scan the ESTABLISHED GLOSSARY for
      every Pāli term in it. When a term has an entry, USE THAT RENDERING —
      do not improvise a fresh translation of a term that already has one.
      Consistency between chunks is the single most important quality bar.
    • If a technical term you need is MISSING from the ESTABLISHED GLOSSARY,
      add it in the "glossary" output of THIS run (stem form). The glossary
      grows with every chunk, so later chunks reuse it.
    • When the meaning differs by context (a polysemous term), still reuse the
      closest existing entry and only mint a new one when the sense is truly
      different — never a stylistic rewording of the same sense.

  What TO include:
    • Technical terms that a translator could easily render inconsistently
      or confuse with a similar term (e.g. "samādhi" vs "samāpatti",
      "sīla" vs "vinaya", "paññā" vs "vijjā").
    • Named doctrinal concepts, proper nouns, and set terms specific to
      Buddhist philosophy or Vinaya procedure.
    • Terms whose {lang_name} rendering is non-obvious or debatable.

  What NOT to include:
    • Common grammatical particles and conjunctions.
    • Plain verbs of being/doing with no doctrinal significance.
    • Any term already present in the ESTABLISHED GLOSSARY block.

  DO NOT OVER-APPLY THE GLOSSARY:
    • If forcing a glossary term into this specific sentence would make the
      {lang_name} read awkwardly or unnaturally, prefer natural, idiomatic
      phrasing and keep the glossary term's core sense, not its exact wording.
    • This applies especially to common words that happen to have a glossary
      entry from a specific technical context.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
C. "remarks" — ONLY for genuine, worth-noting CONFLICTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  {{ "para_id": <int>, "line_id": <int>, "pali": "<short excerpt>",
    "translation": "<the {lang_name} translation you chose>",
    "conflict": "<what the other source says, briefly>",
    "note": "<why you went with your choice, 1 short sentence>" }}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OUTPUT FORMAT — critical
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Return ONLY valid JSON. No markdown fences, no prose outside the JSON.
{{ "translations": [...], "glossary": [...], "remarks": [...] }}
''';

/// Build the effective system prompt: the user's custom prompt if provided,
/// else the default template with the language name substituted.
String buildTranslatorSystemPrompt({
  required String langCode,
  String? customPrompt,
}) {
  final langName = translatorLangName(langCode);
  final template = (customPrompt == null || customPrompt.trim().isEmpty)
      ? kTranslatorSystemPromptTemplate
      : customPrompt;
  return template
      .replaceAll('{lang_name}', langName)
      .replaceAll('{lang}', langCode);
}
