import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database/dpd_database.dart';
import '../database/sutta_info_extensions.dart';
import '../theme/dpd_colors.dart';
import '../theme/dpd_palette.dart';
import 'entry_content.dart';
import 'feedback_type.dart';
import '../utils/text_filters.dart';

class SuttaInfoSection extends StatelessWidget {
  const SuttaInfoSection({
    super.key,
    required this.suttaInfo,
    required this.headwordId,
    required this.lemma1,
  });

  final SuttaInfoData suttaInfo;
  final int headwordId;
  final String lemma1;

  bool _notEmpty(String? s) => s != null && s.isNotEmpty;

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final s = suttaInfo;
    final isVagga = s.isVagga;
    final isSamyutta = s.isSamyutta;
    final isNipata = s.isNipata;

    final sections = <Widget>[
      // CST — gated on cst_code
      if (_notEmpty(s.cstCode)) ...[
        _heading(context, 'Chaṭṭha Saṅgāyana Tipiṭaka (CST)'),
        _table(context, [
          _textRow(context, 'CST Code', s.cstCode),
          _textRow(context, 'Nikāya', s.cstNikaya),
          _textRow(context, 'Book', s.cstBook),
          _textRow(context, 'Section', s.cstSection),
          if (!isSamyutta) _textRow(context, 'Vagga', s.cstVagga),
          if (!isVagga && !isSamyutta) _textRow(context, 'Sutta', s.cstSutta),
          _textRow(context, 'Paragraph', s.cstParanum),
          _textRow(context, 'File', s.cstFile),
          _linkRow(context, 'GitHub', s.cstGithubLink),
        ]),
      ],

      // Apps using CST — gated on cst_code
      if (_notEmpty(s.cstCode)) ...[
        _heading(context, 'Apps & Websites using CST'),
        _table(context, [
          _linkRow(context, 'Digital Pali Reader', s.dprLink),
          _linkRow(context, 'Tipiṭaka Pāḷi Reader', s.tprLink),
          _linkRow(context, 'TipitakaPali.org', s.tppOrg),
        ]),
      ],

      // CST Page Numbers — gated on cst_m_page
      if (_notEmpty(s.cstMPage)) ...[
        _heading(context, 'CST Page Numbers in Printed Editions'),
        _table(context, [
          _textRow(context, 'Myanmar', s.cstMPage),
          _textRow(context, 'Thai', s.cstTPage),
          _textRow(context, 'VRI', s.cstVPage),
          _textRow(context, 'PTS', s.cstPPage),
        ]),
      ],

      // Sutta Central — gated on sc_code or sc_vagga (vagga rows may have only sc_vagga)
      if (_notEmpty(s.scCode) || _notEmpty(s.scBook) || _notEmpty(s.scVagga)) ...[
        _heading(context, 'Sutta Central'),
        _table(context, [
          _textRow(context, 'SC Code', s.scCode),
          _textRow(context, 'Book', s.scBook),
          if (!isSamyutta) _textRow(context, 'Vagga', s.scVagga),
          if (!isVagga && !isSamyutta) _textRow(context, 'Sutta', s.scSutta),
          if (!isVagga && !isSamyutta) _italicRow(context, 'Title', s.scEngSutta),
          if (!isVagga && !isSamyutta) _italicRow(context, 'Blurb', s.scBlurb),
          if (isVagga && s.scVaggaLink != null)
            _multiLinkRow(context, 'Links', [
              ('SC Vagga Card', s.scVaggaLink),
              ('Pāḷi Text', s.scPaliLink),
              ('English Translation', s.scEngLink),
            ])
          else if (isSamyutta && s.scVaggaLink != null)
            _multiLinkRow(context, 'Links', [
              (context.nigg('SC Saṃyutta Card'), s.scVaggaLink),
            ])
          else if (isNipata && s.scVaggaLink != null)
            _multiLinkRow(context, 'Links', [
              ('SC Nipāta Card', s.scVaggaLink),
            ])
          else
            _multiLinkRow(context, 'Links', [
              ('SC Card', s.scCardLink),
              ('Pāḷi Text', s.scPaliLink),
              ('English Translation', s.scEngLink),
            ]),
          _textRow(context, 'File', s.scFilePath),
          _linkRow(context, 'GitHub', s.scGithub),
        ]),
      ],

      // Websites using SC — gated on sc_code
      if (_notEmpty(s.scCode)) ...[
        _heading(context, 'Websites using Sutta Central'),
        _table(context, [
          _linkRow(context, "The Buddha's Words", s.tbw),
          _linkRow(context, 'TBW Legacy', s.tbwLegacy),
          _linkRow(context, 'Dhamma.gift', s.dhammaGift),
          _linkRow(context, 'SC Express', s.scExpressLink),
          _linkRow(context, 'SC Voice', s.scVoiceLink),
          _linkRow(context, 's.4nt.org', s.s4ntLink),
        ]),
      ],

      // BJT — gated on bjt_sutta_code or bjt fields presence
      if (_notEmpty(s.bjtSuttaCode) ||
          _notEmpty(s.bjtPitaka) ||
          _notEmpty(s.bjtNikaya) ||
          _notEmpty(s.bjtMajorSection) ||
          _notEmpty(s.bjtBook) ||
          _notEmpty(s.bjtMinorSection) ||
          _notEmpty(s.bjtVagga)) ...[
        _heading(context, 'Buddha Jayanti Tipiṭaka (BJT)'),
        _table(context, [
          _textRow(context, 'Sutta Code', s.bjtSuttaCode),
          _textRow(context, 'Piṭaka', s.bjtPitaka),
          _textRow(context, 'Nikāya', s.bjtNikaya),
          _textRow(context, 'Major Section', s.bjtMajorSection),
          _textRow(context, 'Book', s.bjtBook),
          _textRow(context, 'Minor Section', s.bjtMinorSection),
          if (!isSamyutta) _textRow(context, 'Vagga', s.bjtVagga),
          if (!isVagga && !isSamyutta) _textRow(context, 'Sutta', s.bjtSutta),
          _textRow(context, 'Book ID', s.bjtBookId),
          _textRow(context, 'Page Number', s.bjtPageNum),
          _textRow(context, 'Filename', s.bjtFilename),
          _linkRow(context, 'GitHub', s.bjtGithubLink),
        ]),
      ],

      // Websites using BJT — gated on bjt_web_code
      if (_notEmpty(s.bjtWebCode)) ...[
        _heading(context, 'Websites using BJT'),
        _table(context, [
          _linkRow(context, 'tipiṭaka.lk (Sinhala)', s.bjtTipitakaLkLink),
          _linkRow(
            context,
            'open.tipiṭaka.lk (Roman)',
            s.bjtOpenTipitakaLkLink,
          ),
          _linkRow(
            context,
            'open.tipiṭaka.lk (Devanagari)',
            s.bjtOpenTipitakaLkDevanagariLink,
          ),
        ]),
      ],

      // DV Sutta Catalogue + Parallels — hidden for vagga and saṃyutta rows
      if (!isVagga && !isSamyutta) ...[
        if (s.dvExists) ...[
          _heading(context, 'Dhamma Vinaya Tools: Sutta Catalogue'),
          _table(context, [
            _textRow(context, 'PTS', s.dvPts),
            _textRow(context, 'General Theme', s.dvMainTheme),
            _textRow(context, 'Particular Topic', s.dvSubtopic),
            _textRow(context, 'Summary', s.dvSummary),
            _textRow(context, 'Key Excerpt 1', s.dvKeyExcerpt1),
            _textRow(context, 'Key Excerpt 2', s.dvKeyExcerpt2),
            _textRow(context, 'Similes', s.dvSimiles),
            _textRow(context, 'Stage of Training', s.dvStage),
            _textRow(context, 'Training In', s.dvTraining),
            _textRow(context, 'Type of Teaching', s.dvAspect),
            _textRow(context, 'Teacher', s.dvTeacher),
            _textRow(context, 'Audience', s.dvAudience),
            _textRow(context, 'Method of Teaching', s.dvMethod),
            _textRow(context, 'Sutta Length', s.dvLength),
            _textRow(context, 'Prominence', s.dvProminence),
            _textRow(context, 'Suggested Reading', s.dvSuggestedSuttas),
            _linkRow(
              context,
              'GitHub',
              'https://github.com/dhammavinaya-tools/dhamma-vinaya-catalogue',
            ),
          ]),
        ],

        if (s.dvParallelsExists) ...[
          _heading(context, 'Parallels'),
          _table(context, [
            _textRow(context, 'Nikāyas', s.dvNikayasParallels),
            _textRow(context, 'Āgamas', s.dvAgamasParallels),
            _textRow(context, 'Taisho', s.dvTaishoParallels),
            _textRow(context, 'Sanskrit', s.dvSanskritParallels),
            _textRow(context, 'Vinaya', s.dvVinayaParallels),
            _textRow(context, 'Others', s.dvOthersParallels),
            _textRow(context, 'Partial (Nikāya/Āgama)', s.dvPartialParallelsNa),
            _textRow(context, 'Partial (All)', s.dvPartialParallelsAll),
          ]),
        ],
      ],
    ];

    return DpdSectionContainer(
      child: Padding(
        padding: DpdColors.sectionPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [...sections, _buildFooter()],
        ),
      ),
    );
  }

  // ── Section builders ────────────────────────────────────────────────────

  Widget _heading(BuildContext context, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(5, 8, 5, 4),
      margin: const EdgeInsets.only(top: 4),
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _table(BuildContext context, List<TableRow?> rows) {
    final filtered = rows.whereType<TableRow>().toList();
    if (filtered.isEmpty) return const SizedBox.shrink();
    return Table(
      columnWidths: const {0: FixedColumnWidth(220), 1: FlexColumnWidth()},
      children: filtered,
    );
  }

  // ── Row builders ─────────────────────────────────────────────────────────

  TableRow? _textRow(BuildContext context, String label, String? value) =>
      buildKvTextRow(context, label, value);

  TableRow? _italicRow(BuildContext context, String label, String? value) =>
      buildKvTextRow(
        context,
        label,
        value,
        valueStyle: const TextStyle(fontStyle: FontStyle.italic),
      );

  TableRow? _linkRow(BuildContext context, String label, String? url) =>
      buildKvLinkRow(context, label, url, onOpen: _openUrl);

  TableRow? _multiLinkRow(
    BuildContext context,
    String label,
    List<(String, String?)> links,
  ) {
    final validLinks = links.where((l) => _notEmpty(l.$2)).toList();
    if (validLinks.isEmpty) return null;
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 5.0, bottom: 2.0),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: context.palette.primaryText,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 2.0),
          child: Wrap(
            spacing: 4,
            children: [
              for (var i = 0; i < validLinks.length; i++) ...[
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: SelectionContainer.disabled(
                    child: GestureDetector(
                      onTap: () => _openUrl(validLinks[i].$2!),
                      child: Text(
                        validLinks[i].$1,
                        style: TextStyle(
                          color: context.palette.primaryText,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: context.palette.primaryText,
                        ),
                      ),
                    ),
                  ),
                ),
                if (i < validLinks.length - 1) const Text(','),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return DpdFooter(
      messagePrefix: 'Did you spot a mistake?',
      linkText: 'Correct it here.',
      feedbackType: FeedbackType.suttaInfo,
      word: lemma1,
      headwordId: headwordId,
    );
  }
}
