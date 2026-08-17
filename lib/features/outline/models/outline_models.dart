/// One section of a book's outline (a numbered level-10 item, or a
/// level 2–6 heading for books without numbered sections).
class OutlineItem {
  final int paraId;

  /// Inclusive last paragraph of this section (exclusive boundary minus 1),
  /// used to load the section's excerpt for the quickview.
  final int sectionEnd;

  final String title;
  final int level;

  const OutlineItem({
    required this.paraId,
    required this.sectionEnd,
    required this.title,
    required this.level,
  });
}

/// A sutta (level-4) grouping inside a vagga, holding its sections.
class OutlineSutta {
  final String title;
  final List<OutlineItem> items;

  const OutlineSutta({required this.title, required this.items});
}

/// A vagga (level-2) grouping of the outline.
class OutlineGroup {
  final String title;
  final List<OutlineSutta> suttas;

  const OutlineGroup({required this.title, required this.suttas});

  int get itemCount =>
      suttas.fold(0, (sum, s) => sum + s.items.length);
}
