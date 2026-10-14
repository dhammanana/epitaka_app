import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/frequency_data.dart';
import '../theme/dpd_colors.dart';
import '../theme/dpd_palette.dart';
import 'entry_content.dart';
import 'feedback_type.dart';
import 'frequency_table.dart';
import '../utils/text_filters.dart';
import '../utils/text_size.dart';

class FrequencySection extends StatelessWidget {
  const FrequencySection({
    super.key,
    required this.data,
    required this.headwordId,
    required this.lemma1,
  });

  final FrequencyData data;
  final int headwordId;
  final String lemma1;

  @override
  Widget build(BuildContext context) {
    return DpdSectionContainer(
      child: Padding(
        padding: DpdColors.sectionPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeading(context),
            if (!data.isNoExactMatches) ...[
              const SizedBox(height: 5),
              FrequencyTable(data: data, scale: context.dpdSize(1.0)),
              const SizedBox(height: 8),
              _buildCorpusLegend(context),
              const SizedBox(height: 8),
              const _ExplanationLink(),
            ] else ...[
              const SizedBox(height: 5),
              const Text(
                'It probably only occurs in compounds. Or perhaps there is an error.',
              ),
            ],
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeading(BuildContext context) {
    final heading = data.freqHeading;
    final baseStyle = DefaultTextStyle.of(context).style;
    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.bold);

    final spans = <InlineSpan>[];
    heading.splitMapJoin(
      RegExp(r'<b>(.*?)</b>'),
      onMatch: (m) {
        spans.add(
          TextSpan(text: context.nigg(m.group(1) ?? ''), style: boldStyle),
        );
        return '';
      },
      onNonMatch: (s) {
        if (s.isNotEmpty) spans.add(TextSpan(text: context.nigg(s)));
        return '';
      },
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.palette.primary, width: 1)),
      ),
      margin: const EdgeInsets.only(bottom: 5),
      child: Text.rich(TextSpan(style: baseStyle, children: spans)),
    );
  }

  Widget _buildCorpusLegend(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    final boldStyle = style.copyWith(fontWeight: FontWeight.bold);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _legendLine(
          'CST',
          'Chaṭṭha Saṅgāyana Tipiṭaka (Myanmar)',
          style,
          boldStyle,
        ),
        _legendLine(
          'BJT',
          'Buddha Jayanti Tipiṭaka (Sri Lanka)',
          style,
          boldStyle,
        ),
        _legendLine(
          'SYA',
          'Syāmaraṭṭha 1927 Royal Edition (Thailand)',
          style,
          boldStyle,
        ),
        _legendLine(
          'MST',
          'Mahāsaṅgīti Tipiṭaka (Sutta Central)',
          style,
          boldStyle,
        ),
      ],
    );
  }

  Widget _legendLine(
    String abbrev,
    String fullName,
    TextStyle style,
    TextStyle boldStyle,
  ) {
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: abbrev, style: boldStyle),
          TextSpan(text: ': $fullName'),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return DpdFooter(
      messagePrefix: 'If something looks out of place,',
      linkText: 'log it here.',
      feedbackType: FeedbackType.frequency,
      word: lemma1,
      headwordId: headwordId,
    );
  }
}

/// The line that points to the explanation page. The link is a span of the
/// line, not a widget placed in it: a widget inside a line takes its own font
/// and sits off the baseline.
class _ExplanationLink extends StatefulWidget {
  const _ExplanationLink();

  @override
  State<_ExplanationLink> createState() => _ExplanationLinkState();
}

class _ExplanationLinkState extends State<_ExplanationLink> {
  late final TapGestureRecognizer _tap = TapGestureRecognizer()
    ..onTap = () => launchUrl(
      Uri.parse('https://digitalpalidictionary.github.io/features/frequency/'),
      mode: LaunchMode.externalApplication,
    );

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(
            text:
                'For a detailed explanation of how this word frequency chart is calculated, '
                "it's accuracies and inaccuracies, please refer to ",
          ),
          TextSpan(
            text: 'this webpage',
            recognizer: _tap,
            mouseCursor: SystemMouseCursors.click,
            style: style.copyWith(
              color: context.palette.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}
