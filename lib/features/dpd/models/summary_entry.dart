enum SummaryEntryType {
  headword,
  root,
  see,
  grammar,
  spelling,
  variant,
  abbreviation,
  abbreviationOther,
  epd,
  help,
  deconstructor,
  dict,
}

/// One line of the summary. [targetId] names what the line scrolls to (see
/// `PageAnchors`); empty when there is nothing to scroll to, as at Saṅkhitta,
/// where the line is the whole entry.
class SummaryEntry {
  final SummaryEntryType type;
  final String label;
  final String typeLabel;
  final String meaning;
  final String targetId;
  final bool meaningHasBold;

  SummaryEntry withTarget(String id) => SummaryEntry(
    type: type,
    label: label,
    typeLabel: typeLabel,
    meaning: meaning,
    targetId: id,
    meaningHasBold: meaningHasBold,
  );

  const SummaryEntry({
    required this.type,
    required this.label,
    required this.typeLabel,
    required this.meaning,
    this.targetId = '',
    this.meaningHasBold = false,
  });
}
