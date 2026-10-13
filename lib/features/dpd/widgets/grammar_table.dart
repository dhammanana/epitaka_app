import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database/dpd_database.dart';
import '../database/dpd_headword_extensions.dart';
import '../theme/dpd_colors.dart';
import '../utils/text_filters.dart';
import 'entry_content.dart';
import 'feedback_type.dart';

class GrammarTable extends StatelessWidget {
  final DpdHeadwordWithRoot headword;

  const GrammarTable({super.key, required this.headword});

  @override
  Widget build(BuildContext context) {
    String n(String t) => context.nigg(t);

    final rows = [
      _buildLemmaRow(context, headword, n),
      _buildLemmaTradRow(context, headword, n),
      _buildLemmaIpaRow(context, headword),
      _buildGrammarRow(context, headword, n),
      _buildFamilyRootRow(context, headword, n),
      _buildRootDetailsRow(context, headword, n),
      _buildRootInCompsRow(context, headword, n),
      _buildBaseRow(context, headword, n),
      _buildConstructionRow(context, headword, n),
      _buildDerivativeRow(context, headword, n),
      _buildPhoneticRow(context, headword, n),
      _buildCompoundRow(context, headword, n),
      _buildAntonymRow(context, headword, n),
      _buildSynonymRow(context, headword, n),
      ..._buildVariantRows(context, headword, n),
      _buildCommentaryRow(context, headword, n),
      _buildNotesRow(context, headword, n),
      _buildCognateRow(context, headword, n),
      _buildLinkRow(context, headword),
      _buildNonIaRow(context, headword, n),
      _buildSanskritRow(context, headword, n),
      _buildSanskritRootDetailsRow(context, headword, n),
    ].whereType<TableRow>().toList();

    return DpdSectionContainer(
      child: Padding(
        padding: DpdColors.sectionPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Table(
              columnWidths: const {
                0: IntrinsicColumnWidth(),
                1: FlexColumnWidth(),
              },
              children: rows,
            ),
            _buildFooter(context, headword),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, DpdHeadwordWithRoot headword) {
    return DpdFooter(
      messagePrefix: 'Did you spot a mistake?',
      linkText: 'Correct it here',
      feedbackType: FeedbackType.grammar,
      word: headword.lemma1,
      headwordId: headword.id,
    );
  }

  TableRow? _buildLemmaRow(BuildContext context,
    DpdHeadwordWithRoot headword,
    String Function(String) n,
  ) {
    final lemma = headword.headword.lemmaClean;
    if (lemma.isEmpty) return null;
    return buildKvTextRow(context, 'Lemma', lemma, filter: n);
  }

  TableRow? _buildLemmaTradRow(BuildContext context,
    DpdHeadwordWithRoot headword,
    String Function(String) n,
  ) {
    final lemmaTrad = headword.headword.lemmaTradClean;
    if (lemmaTrad.isEmpty) return null;
    if (lemmaTrad == headword.headword.lemmaClean) return null;
    return buildKvTextRow(context, 'Traditional Lemma', lemmaTrad, filter: n);
  }

  TableRow? _buildLemmaIpaRow(BuildContext context, DpdHeadwordWithRoot headword) {
    final ipa = headword.headword.lemmaIpa;
    if (ipa == null || ipa.isEmpty) return null;
    return buildKvRow(context, 'IPA', Text('/$ipa/'));
  }

  TableRow? _buildGrammarRow(BuildContext context,
    DpdHeadwordWithRoot headword,
    String Function(String) n,
  ) {
    final grammar = headword.headword.grammarLine;
    if (grammar.isEmpty) return null;
    return buildKvTextRow(context, 'Grammar', grammar, filter: n);
  }

  TableRow? _buildFamilyRootRow(BuildContext context,
    DpdHeadwordWithRoot headword,
    String Function(String) n,
  ) {
    return buildKvTextRow(context, 'Root Family', headword.familyRoot, filter: n);
  }

  TableRow? _buildRootDetailsRow(BuildContext context,
    DpdHeadwordWithRoot headword,
    String Function(String) n,
  ) {
    final root = headword.root;
    if (root == null) return null;
    final rootClean = root.root.replaceAll(
      RegExp(r' \d.*$', multiLine: true, unicode: true),
      '',
    );
    final parts = [
      if (rootClean.isNotEmpty) rootClean,
      root.rootGroup.toString(),
      if (root.rootSign.isNotEmpty) root.rootSign,
      if (root.rootMeaning.isNotEmpty) '(${root.rootMeaning})',
    ];
    final details = parts.join(' ').trim();
    if (details.isEmpty) return null;
    return buildKvTextRow(context, 'Root', details, filter: n);
  }

  TableRow? _buildRootInCompsRow(BuildContext context,
    DpdHeadwordWithRoot headword,
    String Function(String) n,
  ) {
    final root = headword.root;
    if (root == null) return null;
    final inComps = root.rootInComps;
    if (inComps.isEmpty) return null;
    return buildKvTextRow(context, '√ In Sandhi', inComps, filter: n);
  }

  TableRow? _buildBaseRow(BuildContext context,
    DpdHeadwordWithRoot headword,
    String Function(String) n,
  ) {
    return buildKvTextRow(context, 'Base', headword.rootBase, filter: n);
  }

  TableRow? _buildConstructionRow(BuildContext context,
    DpdHeadwordWithRoot headword,
    String Function(String) n,
  ) {
    return buildKvRichRow(
      context,
      'Construction',
      headword.headword.construction,
      filter: n,
    );
  }

  TableRow? _buildDerivativeRow(BuildContext context,
    DpdHeadwordWithRoot headword,
    String Function(String) n,
  ) {
    final derivative = headword.derivative;
    if (derivative == null || derivative.isEmpty) return null;
    final suffix = headword.suffix;
    final text = suffix != null && suffix.isNotEmpty
        ? '$derivative ($suffix)'
        : derivative;
    return buildKvTextRow(context, 'Derivative', text, filter: n);
  }

  TableRow? _buildPhoneticRow(BuildContext context,
    DpdHeadwordWithRoot headword,
    String Function(String) n,
  ) {
    return buildKvRichRow(
      context,
      'Phonetic Change',
      headword.phonetic,
      filter: n,
      onLinkTap: _openUrl,
    );
  }

  TableRow? _buildCompoundRow(BuildContext context,
    DpdHeadwordWithRoot headword,
    String Function(String) n,
  ) {
    final type = headword.compoundType;
    final construction = headword.compoundConstruction;
    if ((type == null || type.isEmpty) &&
        (construction == null || construction.isEmpty)) {
      return null;
    }
    if (type != null && type.contains('?')) return null;
    final text = [
      if (type != null && type.isNotEmpty) type,
      if (construction != null && construction.isNotEmpty) '($construction)',
    ].join(' ').trim();
    return buildKvRichRow(context, 'Compound', text, filter: n, onLinkTap: _openUrl);
  }

  TableRow? _buildAntonymRow(BuildContext context,
    DpdHeadwordWithRoot headword,
    String Function(String) n,
  ) {
    return buildKvTextRow(context, 'Antonym', headword.antonym, filter: n);
  }

  TableRow? _buildSynonymRow(BuildContext context,
    DpdHeadwordWithRoot headword,
    String Function(String) n,
  ) {
    return buildKvTextRow(context, 'Synonym', headword.synonym, filter: n);
  }

  List<TableRow?> _buildVariantRows(BuildContext context,
    DpdHeadwordWithRoot headword,
    String Function(String) n,
  ) {
    return [
      if (headword.variant != null && headword.varPhonetic == null && headword.varText == null)
        buildKvTextRow(context, 'Variant', headword.variant, filter: n),
      if (headword.varPhonetic != null)
        buildKvTextRow(context, 'Phonetic Variant', headword.varPhonetic, filter: n),
      if (headword.varText != null)
        buildKvTextRow(context, 'Textual Variant', headword.varText, filter: n),
    ];
  }

  TableRow? _buildCommentaryRow(BuildContext context,
    DpdHeadwordWithRoot headword,
    String Function(String) n,
  ) {
    final commentary = headword.commentary;
    if (commentary == null || commentary.isEmpty || commentary == '-') {
      return null;
    }
    return buildKvRichRow(
      context,
      'Commentary',
      commentary,
      filter: n,
      onLinkTap: _openUrl,
    );
  }

  TableRow? _buildNotesRow(BuildContext context,
    DpdHeadwordWithRoot headword,
    String Function(String) n,
  ) {
    return buildKvRichRow(
      context,
      'Notes',
      headword.notes,
      filter: n,
      onLinkTap: _openUrl,
    );
  }

  TableRow? _buildCognateRow(BuildContext context,
    DpdHeadwordWithRoot headword,
    String Function(String) n,
  ) {
    return buildKvTextRow(context, 'English Cognate', headword.cognate, filter: n);
  }

  static Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  TableRow? _buildLinkRow(BuildContext context, DpdHeadwordWithRoot headword) {
    return buildKvLinkRow(context, 'Web Link', headword.link, onOpen: _openUrl);
  }

  TableRow? _buildNonIaRow(BuildContext context,
    DpdHeadwordWithRoot headword,
    String Function(String) n,
  ) {
    return buildKvTextRow(context, 'Non IA', headword.nonIa, filter: n);
  }

  TableRow? _buildSanskritRow(BuildContext context,
    DpdHeadwordWithRoot headword,
    String Function(String) n,
  ) {
    final sanskrit = headword.sanskrit;
    if (sanskrit == null || sanskrit.isEmpty) return null;
    return buildKvRow(
      context,
      'Sanskrit',
      Text(n(sanskrit), style: const TextStyle(fontStyle: FontStyle.italic)),
    );
  }

  TableRow? _buildSanskritRootDetailsRow(BuildContext context,
    DpdHeadwordWithRoot headword,
    String Function(String) n,
  ) {
    final root = headword.root;
    if (root == null) return null;
    final sr = root.sanskritRoot;
    if (sr.isEmpty || sr == '-') return null;
    final parts = [
      sr,
      if (root.sanskritRootClass.isNotEmpty) root.sanskritRootClass,
      if (root.sanskritRootMeaning.isNotEmpty) '(${root.sanskritRootMeaning})',
    ];
    final details = parts.join(' ').trim();
    if (details.isEmpty) return null;
    return buildKvRow(
      context,
      'Sanskrit Root',
      Text(n(details), style: const TextStyle(fontStyle: FontStyle.italic)),
    );
  }
}
