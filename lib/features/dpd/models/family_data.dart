import 'dart:convert';

class FamilyEntry {
  const FamilyEntry({
    required this.lemma,
    required this.pos,
    required this.meaning,
    required this.completion,
  });

  final String lemma;
  final String pos;
  final String meaning;
  final String completion;
}

/// Parses the `data` JSON column from a family table row.
/// Expected format: `[["lemma", "pos", "meaning", "completion"], ...]`
List<FamilyEntry> parseFamilyData(String? jsonData) {
  if (jsonData == null || jsonData.isEmpty) return [];
  try {
    final decoded = jsonDecode(jsonData) as List<dynamic>;
    return decoded.map((item) {
      final tuple = item as List<dynamic>;
      return FamilyEntry(
        lemma: tuple[0] as String,
        pos: tuple[1] as String,
        meaning: tuple[2] as String,
        completion: tuple[3] as String,
      );
    }).toList();
  } catch (_) {
    return [];
  }
}
