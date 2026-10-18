/// A link placed inside a line of text is drawn at the size of the line, at
/// any text scale. The line scales an embedded widget already, so the widget's
/// own text must not scale again.
library;

import 'dart:io';

import 'package:epitaka/core/providers/settings_provider.dart'
    show ThemePreference;
import 'package:epitaka/core/theme/app_theme.dart';
import 'package:epitaka/features/dpd/models/frequency_data.dart';
import 'package:epitaka/features/dpd/widgets/frequency_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'dpd_fixture.dart';

final _theme = AppTheme.forPreference(
  ThemePreference.light,
  platformBrightness: Brightness.light,
);

void main() {
  late Directory dir;
  late FrequencyData data;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('embedded_link_test');
    final db = sqlite3.open(buildDpdFixture(dir).path);
    data = parseFrequencyData(
      db
              .select('SELECT freq_data FROM dpd_headwords WHERE id = 34626')
              .first
              .values
              .first
          as String,
    )!;
    db.dispose();
  });

  tearDownAll(() => dir.deleteSync(recursive: true));

  for (final scale in [1.0, 1.5]) {
    testWidgets(
      'the frequency explanation link shares the size and font of its line at $scale',
      (tester) async {
        tester.view.physicalSize = const Size(2400, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: _theme,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: FrequencySection(
                    data: data,
                    headwordId: 34626,
                    lemma1: 'dhamma 1.01',
                  ),
                ),
              ),
            ),
          ),
        );
        // The link is a span of the line, so the line scales it once and it
        // shares the line's font and size: not drawn too big, not off the line.
        final line = tester.widget<RichText>(
          find.byWidgetPredicate(
            (w) =>
                w is RichText && w.text.toPlainText().contains('this webpage'),
          ),
        );
        TextSpan? link;
        line.text.visitChildren((span) {
          if (span is TextSpan && span.text == 'this webpage') link = span;
          return true;
        });
        expect(link, isNotNull);
        final root = line.text;
        expect(line.textScaler.scale(10), closeTo(10 * scale, 1e-6));
        final tapped = link!;
        expect(tapped.style?.fontSize, root.style?.fontSize);
        expect(tapped.style?.fontFamily, root.style?.fontFamily);
        expect(tapped.recognizer, isNotNull);
      },
    );
  }
}
