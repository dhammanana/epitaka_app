/// The links in the feedback block are the size of the text around them, at
/// any text scale. A widget placed inside a line was scaled a second time.
library;

import 'package:epitaka/core/providers/settings_provider.dart' show ThemePreference;
import 'package:epitaka/core/theme/app_theme.dart';
import 'package:epitaka/features/dpd/widgets/feedback_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

double glyphHeight(WidgetTester tester, String paragraph, String at) {
  final p = tester.renderObject<RenderParagraph>(
    find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains(paragraph),
    ),
  );
  final i = p.text.toPlainText().indexOf(at);
  final box = p
      .getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1))
      .first;
  return box.bottom - box.top;
}

final _theme = AppTheme.forPreference(
  ThemePreference.light,
  platformBrightness: Brightness.light,
);

void main() {
  for (final scale in [1.0, 1.5]) {
    testWidgets('links match their line at text scale $scale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: FeedbackSection(headwordId: 15971, lemma1: 'upari 1'),
              ),
            ),
          ),
        ),
      );
      final link = glyphHeight(tester, 'Add a missing word', 'A');
      final rest = glyphHeight(tester, 'Add a missing word', 'P');
      expect(link, closeTo(rest, 1.0));
      final permalink = glyphHeight(tester, 'Permalink', 'h');
      expect(permalink, closeTo(rest, 1.0));
    });
  }

  testWidgets('the permalink line starts with a capital letter', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: FeedbackSection(headwordId: 15971, lemma1: 'upari 1'),
          ),
        ),
      ),
    );
    expect(
      find.textContaining('Permalink https://dpdict.net/15971', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('permalink', findRichText: true), findsNothing);
  });
}
