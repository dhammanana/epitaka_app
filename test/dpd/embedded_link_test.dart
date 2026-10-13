/// A link placed inside a line of text is drawn at the size of the line, at
/// any text scale. The line scales an embedded widget already, so the widget's
/// own text must not scale again.
library;

import 'dart:io';

import 'package:epitaka/core/providers/settings_provider.dart' show ThemePreference;
import 'package:epitaka/core/theme/app_theme.dart';
import 'package:epitaka/features/dpd/models/frequency_data.dart';
import 'package:epitaka/features/dpd/widgets/frequency_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
      db.select('SELECT freq_data FROM dpd_headwords WHERE id = 34626').first.values.first
          as String,
    )!;
    db.dispose();
  });

  tearDownAll(() => dir.deleteSync(recursive: true));

  for (final scale in [1.0, 1.5]) {
    testWidgets('the frequency explanation link is not scaled twice at $scale', (
      tester,
    ) async {
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
      // The line scales the embedded widget when it paints it. The link's own
      // text must stay unscaled, or it is scaled twice.
      final link = tester.renderObject<RenderParagraph>(find.text('this webpage'));
      expect(link.textScaler.scale(10), 10);
    });
  }
}
