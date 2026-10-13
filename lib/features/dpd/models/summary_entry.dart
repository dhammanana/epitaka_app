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
}

/// One line of the Saṅkhitta level. The DPD app's `targetId` is left out:
/// there it scrolls to the full entry, and here the line is the whole entry.
class SummaryEntry {
  final SummaryEntryType type;
  final String label;
  final String typeLabel;
  final String meaning;
  final bool meaningHasBold;

  const SummaryEntry({
    required this.type,
    required this.label,
    required this.typeLabel,
    required this.meaning,
    this.meaningHasBold = false,
  });
}
