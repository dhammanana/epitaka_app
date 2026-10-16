import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/dpd_colors.dart';
import '../theme/dpd_palette.dart';
import '../utils/feedback_urls.dart';
import 'entry_content.dart';

class FeedbackSection extends StatelessWidget {
  const FeedbackSection({
    super.key,
    required this.headwordId,
    required this.lemma1,
  });

  final int headwordId;
  final String lemma1;


  // Ids are never reused, so this link can never rot onto another word.
  String get _permalink => 'https://dpdict.net/$headwordId';

  static const _docsUrl = 'https://digitalpalidictionary.github.io/';

  static const _getInvolvedUrl =
      'mailto:digitalpalidictionary@gmail.com?subject=I%20want%20to%20help!&body=Please%20let%20me%20know%20how%20I%20can%20get%20involved%20with%20the%20development%20of%20DPD.';

  static const _mailingListUrl = 'https://forms.gle/gJ7ouhJriYREPm1s8';

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return DpdSectionContainer(
      child: Padding(
        padding: DpdColors.sectionPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  const TextSpan(text: 'ID '),
                  TextSpan(
                    text: '$headwordId',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _FeedbackLink(
              linkText: _permalink,
              leading: 'Permalink ',
              description: '',
              onTap: () => _openUrl(_permalink),
            ),
            const SizedBox(height: 8),
            Text(
              'Digital Pāḷi Dictionary is a work in progress, made available for testing and feedback purposes.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            _FeedbackLink(
              linkText: 'Add a missing word',
              description:
                  '. Please use this online form to add missing words, especially from Vinaya, commentaries, and other later texts.',
              onTap: () => _openUrl(buildAddWordUrl()),
            ),
            const SizedBox(height: 8),
            _FeedbackLink(
              linkText: 'Correct a mistake',
              description:
                  '. Did you spot a mistake in the dictionary? Have something to add? Please report it. It generally takes less than a minute and your corrections and suggestions help to improve the quality of this dictionary for everyone who uses it.',
              onTap: () => _openUrl(
                buildMistakeUrl(word: lemma1, headwordId: headwordId),
              ),
            ),
            const SizedBox(height: 8),
            _FeedbackLink(
              linkText: 'Read the docs',
              description:
                  '. Get more detailed information about installation on your devices, upgrades, advanced settings and features.',
              onTap: () => _openUrl(_docsUrl),
            ),
            const SizedBox(height: 8),
            _FeedbackLink(
              linkText: 'Get involved',
              description:
                  '. If you\'re a Pāḷi specialist or a coder, or would like to contribute to the project in any way, please get in touch.',
              onTap: () => _openUrl(_getInvolvedUrl),
            ),
            const SizedBox(height: 8),
            _FeedbackLink(
              linkText: 'Join the mailing list',
              description:
                  '. Get notified of updates and new features as soon as they become available.',
              onTap: () => _openUrl(_mailingListUrl),
            ),
          ],
        ),
      ),
    );
  }
}

/// A line with one tappable phrase. The phrase is a span of the line, not a
/// widget placed in it: a widget inside a line is scaled by the text scale a
/// second time, which drew the links about 1.5 times too big.
class _FeedbackLink extends StatefulWidget {
  const _FeedbackLink({
    required this.linkText,
    required this.description,
    required this.onTap,
    this.leading = '',
  });

  final String linkText;
  final String description;
  final VoidCallback onTap;

  /// Plain text before the link.
  final String leading;

  @override
  State<_FeedbackLink> createState() => _FeedbackLinkState();
}

class _FeedbackLinkState extends State<_FeedbackLink> {
  late final TapGestureRecognizer _tap = TapGestureRecognizer()
    ..onTap = () => widget.onTap();

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (widget.leading.isNotEmpty) TextSpan(text: widget.leading),
          TextSpan(
            text: widget.linkText,
            recognizer: _tap,
            mouseCursor: SystemMouseCursors.click,
            style: style?.copyWith(
              color: context.palette.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (widget.description.isNotEmpty) TextSpan(text: widget.description),
        ],
      ),
    );
  }
}
