import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/lookup_results.dart';
import '../../theme/dpd_palette.dart';
import '../../utils/feedback_urls.dart';
import '../../utils/pali_sort.dart';
import '../../utils/text_filters.dart';
import '../entry_content.dart';
import 'secondary_card.dart';

// ── Shared helpers ────────────────────────────────────────────────────────────

const _lineHeight = 1.5;

Widget _lineBreakText(
  BuildContext context,
  List<String> lines,
  TextStyle? baseStyle,
) {
  if (lines.isEmpty) return const SizedBox.shrink();
  return Text.rich(
    TextSpan(
      style: baseStyle?.copyWith(height: _lineHeight),
      children: [
        for (int i = 0; i < lines.length; i++) ...[
          TextSpan(text: context.nigg(lines[i])),
          if (i < lines.length - 1) const TextSpan(text: '\n'),
        ],
      ],
    ),
  );
}

// ── Deconstructor Card ────────────────────────────────────────────────────────

class DeconstructorCard extends StatelessWidget {
  const DeconstructorCard({super.key, required this.result});

  final DeconstructorResult result;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    final encodedHeadword = Uri.encodeComponent(result.headword);

    return DpdSecondaryCard(
      title: 'deconstructor: ${result.headword}',
      content: _lineBreakText(context, result.deconstructions, bodyStyle),
      footer: _DeconstructorFooter(encodedHeadword: encodedHeadword),
    );
  }
}

class _DeconstructorFooter extends StatefulWidget {
  const _DeconstructorFooter({required this.encodedHeadword});

  final String encodedHeadword;

  @override
  State<_DeconstructorFooter> createState() => _DeconstructorFooterState();
}

class _DeconstructorFooterState extends State<_DeconstructorFooter> {
  static const _docsUrl =
      'https://digitalpalidictionary.github.io/features/deconstructor/';

  late final TapGestureRecognizer _docsTap = TapGestureRecognizer()
    ..onTap = () => launchUrl(
      Uri.parse(_docsUrl),
      mode: LaunchMode.platformDefault,
    );

  late final TapGestureRecognizer _suggestTap = TapGestureRecognizer()
    ..onTap = () => launchUrl(
      Uri.parse(
        buildMistakeUrl(
          word: Uri.decodeComponent(widget.encodedHeadword),
          feedbackType: 'Deconstructor',
        ),
      ),
      mode: LaunchMode.externalApplication,
    );

  @override
  void dispose() {
    _docsTap.dispose();
    _suggestTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final footerStyle = TextStyle(fontSize: 12.8, color: palette.gray);
    final linkStyle = TextStyle(
      fontSize: 12.8,
      color: palette.primaryText,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.none,
    );

    // Tappable text spans, not embedded widgets: an embedded widget is scaled
    // by the paragraph again and sits off the text baseline.
    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.primary, width: 1)),
      ),
      child: Text.rich(
        TextSpan(
          style: footerStyle,
          children: [
            const TextSpan(
              text:
                  'These word breakups are code-generated. For more information, ',
            ),
            TextSpan(
              text: 'read the docs',
              style: linkStyle,
              recognizer: _docsTap,
              mouseCursor: SystemMouseCursors.click,
            ),
            const TextSpan(text: '. Please '),
            TextSpan(
              text: 'suggest any improvements here',
              style: linkStyle,
              recognizer: _suggestTap,
              mouseCursor: SystemMouseCursors.click,
            ),
            const TextSpan(
              text:
                  '. Mistakes in deconstruction are usually caused by a word missing from the dictionary.',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grammar Dict Card ─────────────────────────────────────────────────────────

class GrammarDictCard extends StatelessWidget {
  const GrammarDictCard({super.key, required this.result});

  final GrammarDictResult result;

  @override
  Widget build(BuildContext context) {
    const docsUrl =
        'https://digitalpalidictionary.github.io/features/grammardict/';

    return DpdSecondaryCard(
      title: 'grammar: ${result.headword}',
      content: _GrammarDictTable(entries: result.entries),
      footer: DpdFooter(
        messagePrefix: 'For more information, please',
        linkText: 'read the docs',
        customUrlBuilder: () => docsUrl,
      ),
    );
  }
}

class _GrammarDictTable extends StatefulWidget {
  const _GrammarDictTable({required this.entries});

  final List<GrammarDictEntry> entries;

  @override
  State<_GrammarDictTable> createState() => _GrammarDictTableState();
}

class _GrammarDictTableState extends State<_GrammarDictTable> {
  int? _sortColumn;
  bool _ascending = true;

  void _onHeaderTap(int column) {
    setState(() {
      if (_sortColumn == column) {
        if (_ascending) {
          _ascending = false;
        } else {
          _sortColumn = null;
          _ascending = true;
        }
      } else {
        _sortColumn = column;
        _ascending = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(height: _lineHeight);
    final boldStyle = bodyStyle?.copyWith(fontWeight: FontWeight.w700);

    int maxComps = 0;
    for (final entry in widget.entries) {
      for (int i = entry.components.length - 1; i >= 0; i--) {
        if (entry.components[i].isNotEmpty) {
          if (i + 1 > maxComps) maxComps = i + 1;
          break;
        }
      }
    }

    final totalCols = 1 + maxComps + 1 + 1; // pos + comps + "of" + word
    final posCol = 0;
    final wordCol = totalCols - 1;

    final sorted = List<GrammarDictEntry>.of(widget.entries);
    if (_sortColumn != null) {
      final col = _sortColumn!;
      final usePali = col == posCol || col == wordCol;
      sorted.sort((a, b) {
        String aVal, bVal;
        if (col == posCol) {
          aVal = a.pos;
          bVal = b.pos;
        } else if (col == wordCol) {
          aVal = a.headword;
          bVal = b.headword;
        } else {
          final compIdx = col - 1;
          aVal = compIdx < a.components.length ? a.components[compIdx] : '';
          bVal = compIdx < b.components.length ? b.components[compIdx] : '';
        }
        final cmp = usePali
            ? paliSortKey(aVal).compareTo(paliSortKey(bVal))
            : aVal.compareTo(bVal);
        return _ascending ? cmp : -cmp;
      });
    }

    String arrow(int col) {
      if (_sortColumn != col) return ' ⇅';
      return _ascending ? ' ▲' : ' ▼';
    }

    Widget sortableHeader(String label, int col, {TextStyle? style}) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SelectionContainer.disabled(
          child: GestureDetector(
            onTap: () => _onHeaderTap(col),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 2, 10, 0),
              child: Text('$label${arrow(col)}', style: style),
            ),
          ),
        ),
      );
    }

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            sortableHeader('pos', posCol, style: boldStyle),
            ...List.generate(
              maxComps,
              (i) => sortableHeader('', 1 + i, style: bodyStyle),
            ),
            _cell('', style: bodyStyle),
            sortableHeader('word', wordCol, style: boldStyle),
          ],
        ),
        for (final entry in sorted)
          TableRow(
            children: [
              _cell(entry.pos, style: boldStyle),
              ...List.generate(
                maxComps,
                (i) => _cell(
                  i < entry.components.length ? entry.components[i] : '',
                  style: bodyStyle,
                ),
              ),
              _cell('of', style: bodyStyle),
              _cell(entry.headword, style: bodyStyle),
            ],
          ),
      ],
    );
  }

  Widget _cell(String text, {TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 10, 0),
      child: Text(context.nigg(text), style: style),
    );
  }
}

// ── Abbreviation Card ─────────────────────────────────────────────────────────

class AbbreviationCard extends StatelessWidget {
  const AbbreviationCard({super.key, required this.result});

  final AbbreviationResult result;

  @override
  Widget build(BuildContext context) {
    return TertiaryCard(
      title: result.headword,
      content: _HelpStyleTable(
        rows: [
          ('Abbreviation', result.headword, true),
          ('Meaning', result.meaning, false),
          if (result.pali != null && result.pali!.isNotEmpty)
            ('Pāḷi', result.pali!, false),
          if (result.example != null && result.example!.isNotEmpty)
            ('Example', result.example!, false),
          if (result.explanation != null && result.explanation!.isNotEmpty)
            ('Information', result.explanation!, false),
        ],
      ),
    );
  }
}

class AbbreviationOtherCard extends StatelessWidget {
  const AbbreviationOtherCard({super.key, required this.result});

  final AbbreviationOtherResult result;

  @override
  Widget build(BuildContext context) {
    return TertiaryCard(
      title: 'other abbreviations: ${result.headword}',
      content: _AbbreviationOtherTable(rows: result.rows),
    );
  }
}

class _AbbreviationOtherTable extends StatelessWidget {
  const _AbbreviationOtherTable({required this.rows});

  final List<AbbreviationOtherRow> rows;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(height: _lineHeight);
    final noteStyle = bodyStyle?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: rows
          .map(
            (row) => TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Text(
                    row.source,
                    style: bodyStyle?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Text.rich(
                    TextSpan(
                      style: bodyStyle,
                      children: [
                        TextSpan(text: context.nigg(row.meaning)),
                        if (row.notes != null)
                          TextSpan(
                            text: context.nigg(' ${row.notes}'),
                            style: noteStyle,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

// ── Help Card ─────────────────────────────────────────────────────────────────

class HelpCard extends StatelessWidget {
  const HelpCard({super.key, required this.result});

  final HelpResult result;

  @override
  Widget build(BuildContext context) {
    return TertiaryCard(
      title: result.headword,
      content: _HelpStyleTable(
        rows: [
          ('Help', result.headword, true),
          ('Meaning', result.helpText, false),
        ],
      ),
    );
  }
}

class _HelpStyleTable extends StatelessWidget {
  const _HelpStyleTable({required this.rows});

  /// Each entry: (label, value, bold)
  final List<(String, String, bool)> rows;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(height: _lineHeight);

    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: rows.map(((String, String, bool) row) {
        final (label, value, bold) = row;
        return TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Text(
                label,
                style: bodyStyle?.copyWith(
                  color: context.palette.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Text(
                context.nigg(value),
                style: bold
                    ? bodyStyle?.copyWith(fontWeight: FontWeight.w700)
                    : bodyStyle,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ── EPD Card ──────────────────────────────────────────────────────────────────

class EpdCard extends StatelessWidget {
  const EpdCard({super.key, required this.result});

  final EpdResult result;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(height: _lineHeight);

    return DpdSecondaryCard(
      title: 'English: ${result.headword}',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: result.entries.map((entry) {
          return Text.rich(
            TextSpan(
              style: bodyStyle,
              children: [
                TextSpan(
                  text: context.nigg(entry.headword),
                  style: TextStyle(
                    color: context.palette.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (entry.posInfo.isNotEmpty)
                  TextSpan(text: ' ${entry.posInfo}.'),
                TextSpan(text: ' ${entry.meaning}.'),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Variant Card ──────────────────────────────────────────────────────────────

class VariantCard extends StatelessWidget {
  const VariantCard({super.key, required this.result});

  final VariantResult result;

  @override
  Widget build(BuildContext context) {
    const docsUrl =
        'https://digitalpalidictionary.github.io/features/variants/';

    return DpdSecondaryCard(
      title: 'variants: ${result.headword}',
      content: _VariantTable(variants: result.variants),
      footer: DpdFooter(
        messagePrefix: 'For details on how to use this, please',
        linkText: 'read the docs',
        customUrlBuilder: () => docsUrl,
      ),
    );
  }
}

class _VariantTable extends StatefulWidget {
  const _VariantTable({required this.variants});

  final Map<String, Map<String, List<List<String>>>> variants;

  @override
  State<_VariantTable> createState() => _VariantTableState();
}

const _variantCollapsedRows = 10;

class _VariantTableState extends State<_VariantTable> {
  int _visibleRows = _variantCollapsedRows;
  final _toggleKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(height: _lineHeight);
    final headerStyle = bodyStyle?.copyWith(fontWeight: FontWeight.w700);
    final linkStyle = bodyStyle?.copyWith(
      color: context.palette.primaryText,
      fontWeight: FontWeight.w700,
    );

    final corpusList = widget.variants.keys.toList();

    // Collect all data rows with their corpus index for separator logic.
    final dataRows =
        <(int corpusIndex, String corpus, String book, List<String> entry)>[];
    for (int ci = 0; ci < corpusList.length; ci++) {
      final corpus = corpusList[ci];
      for (final book in widget.variants[corpus]!.keys) {
        for (final entry in widget.variants[corpus]![book]!) {
          dataRows.add((ci, corpus, book, entry));
        }
      }
    }

    final totalDataRows = dataRows.length;
    final needsCollapse = totalDataRows > _variantCollapsedRows;
    final visibleCount = needsCollapse
        ? _visibleRows.clamp(0, totalDataRows)
        : totalDataRows;
    final remaining = totalDataRows - visibleCount;
    final isExpanded = visibleCount > _variantCollapsedRows;

    final rows = <TableRow>[];

    // Header row
    rows.add(
      TableRow(
        children: [
          for (final h in ['source', 'filename', 'context', 'variant'])
            _cell(h, style: headerStyle),
        ],
      ),
    );

    int? prevCorpusIndex;
    for (int i = 0; i < visibleCount; i++) {
      final (ci, corpus, book, entry) = dataRows[i];

      if (prevCorpusIndex != null && ci != prevCorpusIndex) {
        rows.add(
          TableRow(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.palette.grayTransparent, width: 1),
              ),
            ),
            children: List.generate(4, (_) => const SizedBox(height: 1)),
          ),
        );
      }
      prevCorpusIndex = ci;

      rows.add(
        TableRow(
          children: [
            _cell(corpus, style: bodyStyle, noWrap: true),
            _cell(book, style: bodyStyle, noWrap: true),
            _cell(entry[0], style: bodyStyle),
            _cell(entry[1], style: bodyStyle),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Table(
          columnWidths: const {
            0: IntrinsicColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: FlexColumnWidth(),
            3: FlexColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          children: rows,
        ),
        if (needsCollapse)
          Padding(
            key: _toggleKey,
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                if (remaining > 0)
                  GestureDetector(
                    onTap: () =>
                        setState(() => _visibleRows += _variantCollapsedRows),
                    child: Text(
                      'show more ($remaining remaining)',
                      style: linkStyle,
                    ),
                  ),
                if (remaining > 0 && isExpanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('·', style: linkStyle),
                  ),
                if (isExpanded)
                  GestureDetector(
                    onTap: () {
                      setState(() => _visibleRows = _variantCollapsedRows);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final ctx = _toggleKey.currentContext;
                        if (ctx != null) {
                          Scrollable.ensureVisible(
                            ctx,
                            alignment: 1.0,
                            duration: const Duration(milliseconds: 300),
                          );
                        }
                      });
                    },
                    child: Text('show less', style: linkStyle),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(String text, {TextStyle? style, bool noWrap = false}) {
    final shown = context.nigg(text);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 10, 0),
      child: noWrap
          ? Text(shown, style: style, softWrap: false)
          : Text(shown, style: style),
    );
  }
}

// ── Spelling Card ─────────────────────────────────────────────────────────────

class SpellingCard extends StatelessWidget {
  const SpellingCard({super.key, required this.result});

  final SpellingResult result;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(height: _lineHeight);
    return DpdSecondaryCard(
      title: 'spelling: ${result.headword}',
      content: Text.rich(
        TextSpan(
          style: bodyStyle,
          children: [
            for (int i = 0; i < result.spellings.length; i++) ...[
              const TextSpan(text: 'incorrect spelling of '),
              TextSpan(
                text: context.nigg(result.spellings[i]),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (i < result.spellings.length - 1) const TextSpan(text: '\n'),
            ],
          ],
        ),
      ),
    );
  }
}

// ── See Card ──────────────────────────────────────────────────────────────────

class SeeCard extends StatelessWidget {
  const SeeCard({super.key, required this.result});

  final SeeResult result;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(height: _lineHeight);
    return DpdSecondaryCard(
      title: 'see: ${result.headword}',
      content: Text.rich(
        TextSpan(
          style: bodyStyle,
          children: [
            for (int i = 0; i < result.seeHeadwords.length; i++) ...[
              const TextSpan(text: 'see '),
              TextSpan(
                text: context.nigg(result.seeHeadwords[i]),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (i < result.seeHeadwords.length - 1)
                const TextSpan(text: '\n'),
            ],
          ],
        ),
      ),
    );
  }
}
