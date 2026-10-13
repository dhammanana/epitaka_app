import 'package:flutter/material.dart';

import '../database/dpd_database.dart';
import '../utils/text_filters.dart';
import 'family_table.dart';
import 'feedback_type.dart';

// ── Header builders ──────────────────────────────────────────────────────────
// Each builder returns a Text.rich with only count and name bolded,
// matching the webapp's <b>count</b> text <b>name</b> pattern.

Widget _richHeader(
  BuildContext context,
  List<InlineSpan> spans, {
  VoidCallback? onJumpTop,
}) {
  final base = Theme.of(context).textTheme.bodyMedium;
  return Text.rich(
    TextSpan(
      style: base,
      children: [
        ...spans,
        if (onJumpTop != null)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: SelectionContainer.disabled(
                child: GestureDetector(
                  onTap: onJumpTop,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      ' ⤴ ',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

TextSpan _bold(BuildContext context, String text, TextStyle? base) => TextSpan(
  text: context.nigg(text),
  style: base?.copyWith(fontWeight: FontWeight.w700),
);

TextSpan _normal(BuildContext context, String text) =>
    TextSpan(text: context.nigg(text));

/// Root: "(bold N) word(s) belong to the root family (bold X) (meaning)"
Widget buildRootFamilyHeader(BuildContext context, FamilyRootData data) {
  final n = data.count;
  final word = n == 1 ? 'word' : 'words';
  final base = Theme.of(context).textTheme.bodyMedium;
  return _richHeader(context, [
    _bold(context, '$n', base),
    _normal(context, ' $word belong to the root family '),
    _bold(context, data.rootFamily, base),
    _normal(context, ' (${data.rootMeaning})'),
  ]);
}

/// Word: "(bold N) words which belong to the (bold X) family"
Widget buildWordFamilyHeader(BuildContext context, FamilyWordData data) {
  final base = Theme.of(context).textTheme.bodyMedium;
  return _richHeader(context, [
    _bold(context, '${data.count}', base),
    _normal(context, ' words which belong to the '),
    _bold(context, data.wordFamily, base),
    _normal(context, ' family'),
  ]);
}

/// Compound: "(bold N) compound(s) which contain(s) (bold X)"
Widget buildCompoundFamilyHeader(
  BuildContext context,
  FamilyCompoundData data, {
  VoidCallback? onJumpTop,
}) {
  final n = data.count;
  final compound = n == 1 ? 'compound' : 'compounds';
  final contains = n == 1 ? 'contains' : 'contain';
  final base = Theme.of(context).textTheme.bodyMedium;
  return _richHeader(context, [
    _bold(context, '$n', base),
    _normal(context, ' $compound which $contains '),
    _bold(context, data.compoundFamily, base),
  ], onJumpTop: onJumpTop);
}

/// Idiom: "(bold N) idiomatic expression(s) which contain(s) (bold X)"
Widget buildIdiomHeader(
  BuildContext context,
  FamilyIdiomData data, {
  VoidCallback? onJumpTop,
}) {
  final n = data.count;
  final expr = n == 1 ? 'idiomatic expression' : 'idiomatic expressions';
  final contains = n == 1 ? 'contains' : 'contain';
  final base = Theme.of(context).textTheme.bodyMedium;
  return _richHeader(context, [
    _bold(context, '$n', base),
    _normal(context, ' $expr which $contains '),
    _bold(context, data.idiom, base),
  ], onJumpTop: onJumpTop);
}

/// Set: "(bold lemma) belongs to the set of (bold X)"
Widget buildSetHeader(
  BuildContext context,
  FamilySetData data,
  String lemma, {
  VoidCallback? onJumpTop,
}) {
  final base = Theme.of(context).textTheme.bodyMedium;
  return _richHeader(context, [
    _bold(context, lemma, base),
    _normal(context, ' belongs to the set of '),
    _bold(context, data.set_, base),
  ], onJumpTop: onJumpTop);
}

// ── Footer configs ────────────────────────────────────────────────────────────

FamilyFooterConfig buildRootFamilyFooter(int headwordId, String lemma1) {
  return FamilyFooterConfig(
    messagePrefix: 'Something out of place?',
    linkText: 'Report it here',
    feedbackType: FeedbackType.rootFamily,
    word: lemma1,
    headwordId: headwordId,
  );
}

FamilyFooterConfig buildWordFamilyFooter(int headwordId, String lemma1) {
  return FamilyFooterConfig(
    messagePrefix: 'Something out of place?',
    linkText: 'Report it here',
    feedbackType: FeedbackType.wordFamily,
    word: lemma1,
    headwordId: headwordId,
  );
}

FamilyFooterConfig buildCompoundFamilyFooter(int headwordId, String lemma1) {
  return FamilyFooterConfig(
    messagePrefix: 'Spot a mistake?',
    linkText: 'Fix it here',
    feedbackType: FeedbackType.compoundFamily,
    word: lemma1,
    headwordId: headwordId,
  );
}

FamilyFooterConfig buildIdiomFooter(int headwordId, String lemma1) {
  return FamilyFooterConfig(
    messagePrefix: 'Please add more idioms',
    linkText: 'here',
    feedbackType: FeedbackType.idioms,
    word: lemma1,
    headwordId: headwordId,
  );
}

FamilyFooterConfig buildSetFooter(int headwordId, String lemma1) {
  return FamilyFooterConfig(
    messagePrefix: 'Spot a mistake?',
    linkText: 'Fix it here',
    feedbackType: FeedbackType.set,
    word: lemma1,
    headwordId: headwordId,
  );
}
