import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database/dpd_database.dart';
import '../database/dpd_headword_extensions.dart';
import '../providers/dpd_settings_provider.dart';
import '../services/audio_service.dart';
import '../theme/dpd_colors.dart';
import '../theme/dpd_palette.dart';
import '../utils/feedback_urls.dart';
import '../utils/text_size.dart';
import '../utils/text_filters.dart';
import 'feedback_type.dart';

/// Padding for the label cell in a key-value table row.
const kDpdTableLabelPadding = EdgeInsets.only(right: 5.0, bottom: 2.0);

/// Padding for the value cell in a key-value table row.
const kDpdTableValuePadding = EdgeInsets.only(bottom: 2.0);

/// Builds a [TableRow] with a bold primary-coloured label and arbitrary [content].
TableRow buildKvRow(BuildContext context, String label, Widget content, {TextStyle? labelStyle}) {
  return TableRow(
    children: [
      Padding(
        padding: kDpdTableLabelPadding,
        child: Text(
          label,
          style:
              labelStyle ??
              TextStyle(
                fontWeight: FontWeight.bold,
                color: context.palette.primaryText,
              ),
        ),
      ),
      Padding(padding: kDpdTableValuePadding, child: content),
    ],
  );
}

/// Builds a nullable text [TableRow]; returns null when [text] is empty or null.
TableRow? buildKvTextRow(
  BuildContext context,
  String label,
  String? text, {
  String Function(String)? filter,
  TextStyle? valueStyle,
  TextStyle? labelStyle,
}) {
  if (text == null || text.isEmpty) return null;
  final display = context.nigg(filter != null ? filter(text) : text);
  return buildKvRow(
    context,
    label,
    Text(display, style: valueStyle),
    labelStyle: labelStyle,
  );
}

/// Parses simple markup (`<b>`, `<i>`, `<a href>`, `<br>`) into [InlineSpan]s.
///
/// Handles non-nested tags as found in DPD database fields (phonetic, commentary,
/// notes). Links are rendered as styled tap targets when [onLinkTap] is provided.
List<InlineSpan> parseSimpleMarkup(
  String html, {
  TextStyle? boldStyle,
  TextStyle? italicStyle,
  TextStyle? linkStyle,
  void Function(String url)? onLinkTap,
}) {
  final spans = <InlineSpan>[];
  final normalized = html
      .replaceAll(RegExp(r'<br\s*/?>'), '\n')
      .replaceAll('\n\n', '\n');
  final pattern = RegExp(
    r'<b>(.*?)</b>|<i>(.*?)</i>|<a\s+href="([^"]*)"[^>]*>(.*?)</a>|([^<]+)',
    dotAll: true,
  );
  for (final m in pattern.allMatches(normalized)) {
    if (m.group(1) != null) {
      spans.add(TextSpan(text: m.group(1), style: boldStyle));
    } else if (m.group(2) != null) {
      spans.add(TextSpan(text: m.group(2), style: italicStyle));
    } else if (m.group(3) != null) {
      final url = m.group(3)!;
      final text = m.group(4)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: SelectionContainer.disabled(
              child: GestureDetector(
                onTap: onLinkTap != null ? () => onLinkTap(url) : null,
                // Already scaled by the paragraph that embeds it.
                child: Text(
                  text,
                  style: linkStyle,
                  textScaler: TextScaler.noScaling,
                ),
              ),
            ),
          ),
        ),
      );
    } else if (m.group(5) != null) {
      spans.add(TextSpan(text: m.group(5)));
    }
  }
  return spans;
}

/// Builds a nullable rich-text [TableRow] parsing simple markup (`<b>`, `<i>`, `<a href>`).
/// Returns null when [html] is empty or null.
TableRow? buildKvRichRow(
  BuildContext context,
  String label,
  String? html, {
  String Function(String)? filter,
  TextStyle? labelStyle,
  void Function(String url)? onLinkTap,
}) {
  if (html == null || html.isEmpty) return null;
  final data = context.nigg(filter != null ? filter(html) : html);
  return buildKvRow(
    context,
    label,
    Builder(
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final base = theme.textTheme.bodyMedium;
        final palette = ctx.palette;
        final spans = parseSimpleMarkup(
          data,
          boldStyle: base?.copyWith(fontWeight: FontWeight.bold),
          italicStyle: base?.copyWith(fontStyle: FontStyle.italic),
          linkStyle: TextStyle(
            color: palette.primaryText,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: palette.primaryText,
          ),
          onLinkTap: onLinkTap,
        );
        return Text.rich(TextSpan(style: base, children: spans));
      },
    ),
    labelStyle: labelStyle,
  );
}

/// Builds a nullable link [TableRow]; returns null when [url] is empty or null.
///
/// Tapping calls [onOpen] with the resolved URL.
TableRow? buildKvLinkRow(
  BuildContext context,
  String label,
  String? url, {
  required void Function(String) onOpen,
  TextStyle? labelStyle,
}) {
  if (url == null || url.isEmpty) return null;
  final palette = context.palette;
  return buildKvRow(
    context,
    label,
    SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SelectionContainer.disabled(
          child: GestureDetector(
            onTap: () => onOpen(url),
            child: Text(
              url,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: palette.primaryText,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: palette.primaryText,
              ),
            ),
          ),
        ),
      ),
    ),
    labelStyle: labelStyle,
  );
}

class DpdFooter extends StatelessWidget {
  const DpdFooter({
    super.key,
    this.messagePrefix = 'Did you spot a mistake?',
    this.linkText = 'Correct it here',
    this.feedbackType,
    this.word,
    this.headwordId,
    this.customUrlBuilder,
    this.customOnTap,
  }) : assert(
         customUrlBuilder != null ||
             customOnTap != null ||
             (feedbackType != null && word != null),
         'Must provide customUrlBuilder, customOnTap, or feedbackType and word',
       );

  final String messagePrefix;
  final String linkText;
  final FeedbackType? feedbackType;
  final String? word;
  final int? headwordId;
  final String Function()? customUrlBuilder;
  final void Function(BuildContext context)? customOnTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12.0),
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.palette.primary, width: 1)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SelectionContainer.disabled(
            child: GestureDetector(
              onTap: () {
                if (customOnTap != null) {
                  customOnTap!(context);
                  return;
                }
                if (customUrlBuilder != null) {
                  launchUrl(
                    Uri.parse(customUrlBuilder!()),
                    mode: LaunchMode.platformDefault,
                  );
                  return;
                }
                launchUrl(
                  Uri.parse(
                    buildMistakeUrl(
                      word: word,
                      headwordId: headwordId,
                      feedbackType: feedbackType?.value,
                    ),
                  ),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: context.dpdSize(12.8),
                    color: context.palette.gray,
                  ),
                  children: [
                    TextSpan(text: '$messagePrefix '),
                    TextSpan(
                      text: linkText,
                      style: TextStyle(
                        color: context.palette.primaryText,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EntryExampleBlock extends StatelessWidget {
  const EntryExampleBlock({super.key, required this.headword});

  final DpdHeadwordWithRoot headword;

  @override
  Widget build(BuildContext context) {
    final h = headword;
    return DpdSectionContainer(
      child: Padding(
        padding: DpdColors.sectionPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SingleExampleBlock(
              example: h.example1!,
              sutta: h.sutta1,
              source: h.source1,
            ),
            if (h.needsExamplesButton)
              _SingleExampleBlock(
                example: h.example2!,
                sutta: h.sutta2,
                source: h.source2,
              ),
            EntryExampleFooter(headwordId: h.id, lemma1: h.lemma1),
          ],
        ),
      ),
    );
  }
}

/// Parses a string containing `<b>...</b>` tags into a list of [InlineSpan]s.
/// Newline characters are preserved as-is (not converted to `<br>`).
List<InlineSpan> _parseBoldSpans(String text, {TextStyle? boldStyle}) {
  final spans = <InlineSpan>[];
  text.splitMapJoin(
    RegExp(r'<b>(.*?)</b>'),
    onMatch: (m) {
      spans.add(TextSpan(text: m.group(1), style: boldStyle));
      return '';
    },
    onNonMatch: (s) {
      if (s.isNotEmpty) spans.add(TextSpan(text: s));
      return '';
    },
  );
  return spans;
}

class _SingleExampleBlock extends ConsumerWidget {
  const _SingleExampleBlock({required this.example, this.sutta, this.source});

  final String example;
  final String? sutta;
  final String? source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showSandhi = ref.watch(
      dpdSettingsProvider.select((s) => s.showSandhi),
    );
    String n(String t) =>
        context.nigg(filterSandhi(t, show: showSandhi));
    final theme = Theme.of(context);
    final boldStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.bold,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: theme.textTheme.bodyMedium,
            children: _parseBoldSpans(n(example), boldStyle: boldStyle),
          ),
        ),
        if (sutta != null || source != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              [source, sutta].whereType<String>().map(n).join(' '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.palette.primaryText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

class EntrySummaryBox extends StatelessWidget {
  const EntrySummaryBox({super.key, required this.headword});

  final DpdHeadwordWithRoot headword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = headword.headword;
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.5);
    final boldStyle = baseStyle?.copyWith(fontWeight: FontWeight.w700);
    final grayStyle = baseStyle?.copyWith(color: context.palette.gray);

    String f(String? text) => context.nigg(text ?? '');

    final hasMeaning1 = h.meaning1 != null && h.meaning1!.isNotEmpty;
    final summary = h.constructionSummary;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary, width: 2),
        borderRadius: DpdColors.borderRadius,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      child: Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            if (h.pos != null && h.pos!.isNotEmpty)
              TextSpan(text: '${f(h.pos)}. '),
            if (h.plusCase != null && h.plusCase!.isNotEmpty)
              TextSpan(text: '(${f(h.plusCase)}) '),
            if (hasMeaning1) ...[
              TextSpan(text: f(h.meaning1), style: boldStyle),
              if (h.meaningLit != null && h.meaningLit!.isNotEmpty)
                TextSpan(text: '; lit. ${f(h.meaningLit)}'),
            ] else if (h.meaning2 != null && h.meaning2!.isNotEmpty) ...[
              if (h.meaning2!.contains('; lit.'))
                TextSpan(text: f(h.meaning2))
              else if (h.meaningLit != null && h.meaningLit!.isNotEmpty)
                TextSpan(text: '${f(h.meaning2)}; lit. ${f(h.meaningLit)}')
              else
                TextSpan(text: f(h.meaning2)),
            ],
            if (summary.isNotEmpty) TextSpan(text: ' [${f(summary)}]'),
            TextSpan(text: ' ${h.degreeOfCompletion}', style: grayStyle),
          ],
        ),
      ),
    );
  }
}

/// A bordered container for entry section content, matching .dpd.content CSS.
class DpdSectionContainer extends StatelessWidget {
  const DpdSectionContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary, width: 2),
        borderRadius: DpdColors.borderRadius,
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: child,
    );
  }
}

/// Webapp-style section toggle button matching .dpd-button CSS class.
/// Inactive: cyan fill, dark text. Active: primary-alt fill, light text.
class DpdSectionButton extends StatelessWidget {
  const DpdSectionButton({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isActive
        ? theme.colorScheme.secondary
        : theme.colorScheme.primary;
    final fg = isActive
        ? theme.colorScheme.onSecondary
        : theme.colorScheme.onPrimary;
    final shadow = isActive ? context.palette.shadowHover : context.palette.shadowDefault;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SelectionContainer.disabled(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.fromLTRB(1, 1, 1, 2),
            padding: const EdgeInsets.fromLTRB(5, 2, 5, 2),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: bg, width: 1),
              borderRadius: DpdColors.borderRadius,
              boxShadow: shadow,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: context.dpdSize(14.0 * 0.8),
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Main play button — same visual style as DpdSectionButton but with a play icon.
/// Shows active color while playing, grays out if audio fetch fails.
class DpdPlayButton extends StatefulWidget {
  const DpdPlayButton({
    super.key,
    required this.lemma,
    required this.gender,
    this.compact = false,
  });

  final String lemma;
  final String gender;
  final bool compact;

  @override
  State<DpdPlayButton> createState() => _DpdPlayButtonState();
}

class _DpdPlayButtonState extends State<DpdPlayButton> {
  bool _playing = false;
  bool _errored = false;

  Future<void> _play() async {
    if (_errored) return;
    setState(() => _playing = true);
    final ok = await AudioService.instance.play(widget.lemma, widget.gender);
    if (!mounted) return;
    setState(() {
      _playing = false;
      if (!ok) _errored = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color bg;
    final Color fg;
    final List<BoxShadow> shadow;
    if (_errored) {
      bg = theme.colorScheme.onSurface.withValues(alpha: 0.12);
      fg = theme.colorScheme.onSurface.withValues(alpha: 0.38);
      shadow = [];
    } else if (_playing) {
      bg = theme.colorScheme.secondary;
      fg = theme.colorScheme.onSecondary;
      shadow = context.palette.shadowHover;
    } else {
      bg = theme.colorScheme.primary;
      fg = theme.colorScheme.onPrimary;
      shadow = context.palette.shadowDefault;
    }
    final compact = widget.compact;
    return MouseRegion(
      cursor: _errored ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _errored ? null : _play,
        child: Container(
          margin: compact ? null : const EdgeInsets.fromLTRB(1, 1, 1, 2),
          padding: compact
              ? const EdgeInsets.all(3)
              : const EdgeInsets.fromLTRB(5, 2, 5, 2),
          decoration: BoxDecoration(
            color: bg,
            border: compact ? null : Border.all(color: bg, width: 1),
            borderRadius: DpdColors.borderRadius,
            boxShadow: compact ? null : shadow,
          ),
          child: compact
              ? Icon(Icons.play_arrow, color: fg, size: context.dpdSize(12))
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: 0,
                      child: Text(
                        ' ',
                        style: TextStyle(
                          fontSize: context.dpdSize(14.0 * 0.8),
                          height: 1.5,
                        ),
                      ),
                    ),
                    Icon(Icons.play_arrow, color: fg, size: context.dpdSize(18)),
                  ],
                ),
        ),
      ),
    );
  }
}

class EntryExampleFooter extends StatelessWidget {
  const EntryExampleFooter({
    super.key,
    required this.headwordId,
    required this.lemma1,
  });

  final int headwordId;
  final String lemma1;

  @override
  Widget build(BuildContext context) {
    return DpdFooter(
      messagePrefix: 'Can you think of a better example?',
      linkText: 'Add it here.',
      feedbackType: FeedbackType.examples,
      word: lemma1,
      headwordId: headwordId,
    );
  }
}
