import 'dart:convert';

// ── DeconstructorResult ──────────────────────────────────────────────────────

class DeconstructorResult {
  final String headword;
  final List<String> deconstructions;

  const DeconstructorResult({
    required this.headword,
    required this.deconstructions,
  });

  static DeconstructorResult? fromJson(String headword, String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      return DeconstructorResult(
        headword: headword,
        deconstructions: decoded.map((e) => e as String).toList(),
      );
    } catch (_) {
      return null;
    }
  }
}

// ── GrammarDictResult ────────────────────────────────────────────────────────

class GrammarDictEntry {
  final String headword;
  final String pos;

  /// Always exactly 3 elements, padded with empty strings.
  final List<String> components;

  const GrammarDictEntry({
    required this.headword,
    required this.pos,
    required this.components,
  });
}

class GrammarDictResult {
  final String headword;
  final List<GrammarDictEntry> entries;

  const GrammarDictResult({required this.headword, required this.entries});

  static GrammarDictResult? fromJson(String headword, String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      final entries = decoded.map((item) {
        final row = item as List<dynamic>;
        final hw = row[0] as String;
        final pos = row[1] as String;
        final grammarStr = row[2] as String;
        final components = _splitGrammarString(grammarStr);
        return GrammarDictEntry(headword: hw, pos: pos, components: components);
      }).toList();
      return GrammarDictResult(headword: headword, entries: entries);
    } catch (_) {
      return null;
    }
  }

  static List<String> _splitGrammarString(String grammarStr) {
    List<String> parts;
    if (grammarStr.startsWith('reflx')) {
      final words = grammarStr.split(' ');
      if (words.length >= 2) {
        parts = ['${words[0]} ${words[1]}', ...words.sublist(2)];
      } else {
        parts = [grammarStr];
      }
    } else if (grammarStr.startsWith('in comps')) {
      parts = [grammarStr];
    } else {
      parts = grammarStr.split(' ');
    }
    while (parts.length < 3) {
      parts.add('');
    }
    return parts;
  }
}

// ── AbbreviationResult ───────────────────────────────────────────────────────

class AbbreviationResult {
  final String headword;
  final String meaning;
  final String? pali;
  final String? example;
  final String? explanation;

  const AbbreviationResult({
    required this.headword,
    required this.meaning,
    this.pali,
    this.example,
    this.explanation,
  });

  static AbbreviationResult? fromJson(String headword, String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final meaning = decoded['meaning'] as String? ?? '';
      // The DB uses 'pāli' with a macron; fall back to 'pali' for flexibility
      final pali =
          (decoded['pāli'] as String?)?.nullIfEmpty ??
          (decoded['pali'] as String?)?.nullIfEmpty;
      final example = (decoded['example'] as String?)?.nullIfEmpty;
      final explanation = (decoded['explanation'] as String?)?.nullIfEmpty;
      return AbbreviationResult(
        headword: headword,
        meaning: meaning,
        pali: pali,
        example: example,
        explanation: explanation,
      );
    } catch (_) {
      return null;
    }
  }
}

class AbbreviationOtherRow {
  final String source;
  final String meaning;
  final String? notes;

  const AbbreviationOtherRow({
    required this.source,
    required this.meaning,
    this.notes,
  });
}

class AbbreviationOtherResult {
  final String headword;
  final List<AbbreviationOtherRow> rows;

  const AbbreviationOtherResult({required this.headword, required this.rows});

  static AbbreviationOtherResult? fromJson(
    String headword,
    String? jsonString,
  ) {
    if (jsonString == null || jsonString.isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      final rows = decoded
          .whereType<Map<String, dynamic>>()
          .map((row) {
            final source = (row['source'] as String?)?.trim() ?? '';
            final meaning = (row['meaning'] as String?)?.trim() ?? '';
            final notes = (row['notes'] as String?)?.trim().nullIfEmpty;
            if (source.isEmpty || meaning.isEmpty) return null;
            return AbbreviationOtherRow(
              source: source,
              meaning: meaning,
              notes: notes,
            );
          })
          .nonNulls
          .toList();
      if (rows.isEmpty) return null;
      return AbbreviationOtherResult(headword: headword, rows: rows);
    } catch (_) {
      return null;
    }
  }
}

// ── HelpResult ───────────────────────────────────────────────────────────────

class HelpResult {
  final String headword;
  final String helpText;

  const HelpResult({required this.headword, required this.helpText});

  static HelpResult? fromJson(String headword, String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return null;
    try {
      // Double-encoded: json.dumps("some string") → '"some string"'
      final decoded = jsonDecode(jsonString) as String;
      return HelpResult(headword: headword, helpText: decoded);
    } catch (_) {
      return null;
    }
  }
}

// ── EpdResult ────────────────────────────────────────────────────────────────

class EpdEntry {
  final String headword;
  final String posInfo;
  final String meaning;

  const EpdEntry({
    required this.headword,
    required this.posInfo,
    required this.meaning,
  });
}

class EpdResult {
  final String headword;
  final List<EpdEntry> entries;

  const EpdResult({required this.headword, required this.entries});

  static EpdResult? fromJson(String headword, String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      final entries = decoded.map((item) {
        final row = item as List<dynamic>;
        return EpdEntry(
          headword: row[0] as String,
          posInfo: row[1] as String,
          meaning: row[2] as String,
        );
      }).toList();
      return EpdResult(headword: headword, entries: entries);
    } catch (_) {
      return null;
    }
  }
}

// ── VariantResult ────────────────────────────────────────────────────────────

class VariantResult {
  final String headword;

  /// corpus → book → list of [context, variant] pairs
  final Map<String, Map<String, List<List<String>>>> variants;

  const VariantResult({required this.headword, required this.variants});

  static VariantResult? fromJson(String headword, String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final variants = decoded.map((corpus, booksRaw) {
        final books = (booksRaw as Map<String, dynamic>).map((
          book,
          entriesRaw,
        ) {
          final entries = (entriesRaw as List<dynamic>).map((entry) {
            final pair = entry as List<dynamic>;
            return [pair[0] as String, pair[1] as String];
          }).toList();
          return MapEntry(book, entries);
        });
        return MapEntry(corpus, books);
      });
      return VariantResult(headword: headword, variants: variants);
    } catch (_) {
      return null;
    }
  }
}

// ── SpellingResult ────────────────────────────────────────────────────────────

class SpellingResult {
  final String headword;
  final List<String> spellings;

  const SpellingResult({required this.headword, required this.spellings});

  static SpellingResult? fromJson(String headword, String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      return SpellingResult(
        headword: headword,
        spellings: decoded.map((e) => e as String).toList(),
      );
    } catch (_) {
      return null;
    }
  }
}

// ── SeeResult ────────────────────────────────────────────────────────────────

class SeeResult {
  final String headword;
  final List<String> seeHeadwords;

  const SeeResult({required this.headword, required this.seeHeadwords});

  static SeeResult? fromJson(String headword, String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      return SeeResult(
        headword: headword,
        seeHeadwords: decoded.map((e) => e as String).toList(),
      );
    } catch (_) {
      return null;
    }
  }
}

// ── Extension ────────────────────────────────────────────────────────────────

extension _StringNullIfEmpty on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
