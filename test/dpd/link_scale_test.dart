/// A link drawn inside a line of text (an embedded widget) follows the app's
/// text scale once, not twice. The paragraph already scales its embedded
/// widgets, so a second scale from the link's own `Text` doubles it.
library;

import 'package:epitaka/core/providers/settings_provider.dart'
    show ThemePreference;
import 'package:epitaka/core/theme/app_theme.dart';
import 'package:epitaka/features/dpd/models/lookup_results.dart';
import 'package:epitaka/features/dpd/widgets/entry_content.dart';
import 'package:epitaka/features/dpd/widgets/secondary/secondary_result_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<double> linkWidth(
    WidgetTester tester,
    double scale,
    Widget Function() card,
    String linkText,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.forPreference(
          ThemePreference.light,
          platformBrightness: Brightness.light,
        ),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: SingleChildScrollView(child: card())),
        ),
      ),
    );
    return tester.getRect(find.text(linkText)).width;
  }

  testWidgets('deconstructor footer links are plain text spans', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.forPreference(
          ThemePreference.light,
          platformBrightness: Brightness.light,
        ),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: DeconstructorCard(
                result: DeconstructorResult.fromJson('abba', '["na + ba"]')!,
              ),
            ),
          ),
        ),
      ),
    );
    final footer = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere(
          (r) => r.text.toPlainText().contains('These word breakups'),
        );
    var embedded = 0;
    footer.text.visitChildren((span) {
      if (span is WidgetSpan) embedded++;
      return true;
    });
    // An embedded widget is scaled by the paragraph a second time, and sits
    // off the text baseline.
    expect(embedded, 0);
  });

  testWidgets('a link inside a note scales once', (tester) async {
    Widget card() => Builder(
      builder: (context) {
        final base = Theme.of(context).textTheme.bodyMedium;
        return Text.rich(
          TextSpan(
            style: base,
            children: parseSimpleMarkup(
              'see <a href="https://example.org">the docs here</a> now',
              linkStyle: base,
              onLinkTap: (_) {},
            ),
          ),
        );
      },
    );
    final one = await linkWidth(tester, 1.0, card, 'the docs here');
    final scaled = await linkWidth(tester, 1.5, card, 'the docs here');
    expect(scaled / one, closeTo(1.5, 0.1));
  });
}
