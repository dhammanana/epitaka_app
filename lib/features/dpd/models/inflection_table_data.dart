/// A single inflected word form: stem + ending = word.
class InflectionForm {
  const InflectionForm({
    required this.stem,
    required this.ending,
    required this.word,
    this.isOccurring = true,
  });

  final String stem;
  final String ending;
  final String word;

  /// Whether this form occurs in the Tipitaka (lookup table).
  /// Defaults to true when no lookup set is provided.
  final bool isOccurring;
}

/// One cell in the inflection table: zero or more forms, optional grammar tooltip.
class InflectionCell {
  const InflectionCell({required this.forms, this.grammarTooltip});

  final List<InflectionForm> forms;
  final String? grammarTooltip;

  bool get isEmpty => forms.isEmpty;
}

/// Fully parsed inflection table ready for rendering.
class InflectionTableData {
  const InflectionTableData({
    required this.headers,
    required this.rows,
    required this.buttonLabel,
    required this.headingLemma,
    required this.headingPattern,
    required this.headingDeclLabel,
    this.headingLike,
    required this.headingIsIrregular,
  });

  /// Column header labels (e.g. ["", "singular", "plural"]).
  final List<String> headers;

  /// Each row is a tuple of (rowLabel, cells) — one cell per column header (excluding label col).
  final List<(String, List<InflectionCell>)> rows;

  /// Button label: "Declension" or "Conjugation".
  final String buttonLabel;

  /// Lemma shown bold at start of heading (e.g. "dhamma").
  final String headingLemma;

  /// Pattern shown bold after "is" (e.g. "a masc").
  final String headingPattern;

  /// "declension" or "conjugation" — not bold.
  final String headingDeclLabel;

  /// Non-null when heading shows "(like X)" — displayed bold.
  final String? headingLike;

  /// When true, heading shows "(irregular)" instead of "(like X)".
  final bool headingIsIrregular;

  /// Reconstructed heading text for backwards compat (e.g., tests).
  String get headingText {
    if (headingIsIrregular) {
      return '$headingLemma is $headingPattern $headingDeclLabel (irregular)';
    } else if (headingLike != null) {
      return '$headingLemma is $headingPattern $headingDeclLabel (like $headingLike)';
    } else {
      return '$headingLemma is $headingPattern $headingDeclLabel';
    }
  }
}
